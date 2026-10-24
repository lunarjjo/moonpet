/* moonpet.c — shim C datar di atas llama.cpp untuk MoonPet (Flutter FFI).
 *
 * Model thread: generasi berjalan di pthread internal; Dart melakukan polling
 * mp_status()/mp_poll() dari thread utama Dart (callback lintas-thread ke Dart
 * dilarang oleh dart:ffi — API pull ini aman dan sederhana).
 *
 * Build: bagian dari pohon cmake llama.cpp (lihat CMakeLists.txt sebelah file ini).
 * Lisensi: MIT (MoonPet) — pustaka llama.cpp MIT (ggml-org).
 */
#include "llama.h"

#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MP_RING (1u << 16) /* 64 KiB ring buffer keluaran */

typedef enum {
    MP_STATUS_IDLE = 0,
    MP_STATUS_RUNNING = 1,
    MP_STATUS_DONE = 2,
    MP_STATUS_ERROR = 3,
} mp_status_t;

typedef struct mp_ctx {
    struct llama_model *   model;
    struct llama_context * ctx;
    const struct llama_vocab * vocab;

    pthread_t       thread;
    pthread_mutex_t mutex;
    bool            thread_valid;
    bool            thread_joined;

    /* permintaan generasi (disalin saat mp_start) */
    char   * req_prompt;
    int32_t req_max_tokens;
    float   req_temp;
    float   req_top_p;
    float   req_pen_repeat;
    int32_t req_pen_last_n;
    uint64_t req_seed;

    /* status & keluaran */
    atomic_int  status;
    atomic_bool abort_flag;
    char        ring[MP_RING];
    size_t      ring_r, ring_w; /* dilindungi mutex */
    char        err[256];

    /* statistik */
    double t_start_ms;
    int32_t n_generated;
    double tokens_per_sec;
} mp_ctx;

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

static void mp_set_err(mp_ctx *m, const char *msg) {
    if (!m) return;
    snprintf(m->err, sizeof(m->err) - 1, "%s", msg);
}

static void ring_push(mp_ctx *m, const char *data, size_t len) {
    pthread_mutex_lock(&m->mutex);
    for (size_t i = 0; i < len; i++) {
        m->ring[m->ring_w] = data[i];
        m->ring_w = (m->ring_w + 1) % MP_RING;
        if (m->ring_w == m->ring_r) {
            m->ring_r = (m->ring_r + 1) % MP_RING; /* buang terlama, tak mungkin terjadi dgn 60 token */
        }
    }
    pthread_mutex_unlock(&m->mutex);
}

static void * mp_worker(void *arg) {
    mp_ctx *m = (mp_ctx *)arg;

    struct llama_sampler_chain_params sp = llama_sampler_chain_default_params();
    sp.no_perf = true;
    struct llama_sampler * smpl = llama_sampler_chain_init(sp);
    llama_sampler_chain_add(smpl, llama_sampler_init_penalties(
        (int32_t)llama_vocab_n_tokens(m->vocab),
        m->req_pen_last_n, m->req_pen_repeat, 0.0f, 0.0f));
    if (m->req_temp <= 0.01f) {
        llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(m->req_top_p, 1));
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(m->req_temp));
        llama_sampler_chain_add(smpl, llama_sampler_init_dist((uint32_t)(m->req_seed & 0xFFFFFFFFu)));
    }

    /* tokenisasi prompt (add_special=true menambahkan BOS otomatis) */
    const int32_t len = (int32_t)strlen(m->req_prompt);
    int32_t n_need = llama_tokenize(m->vocab, m->req_prompt, len, NULL, 0, true, true);
    if (n_need > 0) {
        /* kasus tak lazim: muat dalam 0 token? gunakan langsung */
    } else if (n_need < 0) {
        n_need = -n_need; /* konvensi: nilai negatif = jumlah token yang dibutuhkan */
    } else {
        mp_set_err(m, "prompt kosong");
        atomic_store(&m->status, MP_STATUS_ERROR);
        llama_sampler_free(smpl);
        return NULL;
    }
    llama_token *tokens = (llama_token *)malloc((size_t)(n_need + 8) * sizeof(llama_token));
    if (!tokens) {
        mp_set_err(m, "alokasi memori gagal");
        atomic_store(&m->status, MP_STATUS_ERROR);
        llama_sampler_free(smpl);
        return NULL;
    }
    int32_t n_prompt = llama_tokenize(m->vocab, m->req_prompt, len, tokens, n_need + 8, true, true);
    if (n_prompt < 0) {
        mp_set_err(m, "tokenisasi prompt gagal (2)");
        free(tokens);
        atomic_store(&m->status, MP_STATUS_ERROR);
        llama_sampler_free(smpl);
        return NULL;
    }

    /* dekode seluruh prompt dalam potongan ukuran batch */
    const int32_t n_batch = (int32_t)llama_n_batch(m->ctx);
    for (int32_t i = 0; i < n_prompt;) {
        if (atomic_load(&m->abort_flag)) break;
        int32_t n = n_prompt - i;
        if (n > n_batch) n = n_batch;
        struct llama_batch batch = llama_batch_get_one(tokens + i, n);
        if (llama_decode(m->ctx, batch) != 0) {
            mp_set_err(m, "llama_decode gagal pada prompt (konteks penuh?)");
            free(tokens);
            atomic_store(&m->status, MP_STATUS_ERROR);
            llama_sampler_free(smpl);
            return NULL;
        }
        i += n;
    }

    /* loop generasi token-per-token */
    m->n_generated = 0;
    m->t_start_ms = now_ms();
    if (!atomic_load(&m->abort_flag)) {
        for (;;) {
            if (atomic_load(&m->abort_flag)) break;
            if (m->n_generated >= m->req_max_tokens) break;

            const llama_token id = llama_sampler_sample(smpl, m->ctx, -1);
            if (llama_vocab_is_eog(m->vocab, id)) break;

            char piece[64];
            const int32_t n = llama_token_to_piece(m->vocab, id, piece, sizeof(piece), 0, true);
            if (n > 0) ring_push(m, piece, (size_t)n);
            llama_sampler_accept(smpl, id);

            llama_token tid = id;
            struct llama_batch batch = llama_batch_get_one(&tid, 1);
            if (llama_decode(m->ctx, batch) != 0) {
                mp_set_err(m, "llama_decode gagal saat generasi");
                break;
            }
            m->n_generated++;
        }
    }
    const double dt = (now_ms() - m->t_start_ms) / 1e3;
    m->tokens_per_sec = dt > 0 ? m->n_generated / dt : 0.0;

    free(tokens);
    llama_sampler_free(smpl);
    atomic_store(&m->status, atomic_load(&m->abort_flag) ? MP_STATUS_DONE : MP_STATUS_DONE);
    return NULL;
}

/* ================= API publik (flat, FFI-aman) ================= */

int32_t mp_init(void) {
    llama_backend_init();
    return 1;
}

void * mp_create(const char *model_path, int32_t n_ctx, int32_t n_threads) {
    if (!model_path) return NULL;
    mp_ctx *m = (mp_ctx *)calloc(1, sizeof(mp_ctx));
    if (!m) return NULL;

    struct llama_model_params mp = llama_model_default_params();
    m->model = llama_model_load_from_file(model_path, mp);
    if (!m->model) { free(m); return NULL; }

    struct llama_context_params cp = llama_context_default_params();
    cp.n_ctx           = n_ctx > 0 ? (uint32_t)n_ctx : 2048;
    cp.n_threads       = n_threads > 0 ? n_threads : 4;
    cp.n_threads_batch = cp.n_threads;
    m->ctx = llama_init_from_model(m->model, cp);
    if (!m->ctx) { llama_model_free(m->model); free(m); return NULL; }

    m->vocab = llama_model_get_vocab(m->model);
    pthread_mutex_init(&m->mutex, NULL);
    atomic_store(&m->status, MP_STATUS_IDLE);
    atomic_store(&m->abort_flag, false);
    m->err[0] = '\0';
    return m;
}

int32_t mp_start(void *h, const char *prompt, int32_t max_tokens,
                 float temp, float top_p, float pen_repeat, int32_t pen_last_n,
                 uint64_t seed) {
    mp_ctx *m = (mp_ctx *)h;
    if (!m || !prompt) return -1;
    if (atomic_load(&m->status) == MP_STATUS_RUNNING) return 0;
    if (m->thread_valid && !m->thread_joined) {
        pthread_join(m->thread, NULL);
        m->thread_joined = true;
    }

    pthread_mutex_lock(&m->mutex);
    m->ring_r = m->ring_w = 0;
    pthread_mutex_unlock(&m->mutex);
    atomic_store(&m->abort_flag, false);

    free(m->req_prompt);
    m->req_prompt = strdup(prompt);
    m->req_max_tokens = max_tokens > 0 ? max_tokens : 60;
    m->req_temp       = temp;
    m->req_top_p      = top_p > 0 ? top_p : 0.95f;
    m->req_pen_repeat = pen_repeat > 0 ? pen_repeat : 1.1f;
    m->req_pen_last_n = pen_last_n > 0 ? pen_last_n : 64;
    m->req_seed       = seed ? seed : 0x4D4F4D4Fu; /* "MOMO" */
    m->err[0] = '\0';

    atomic_store(&m->status, MP_STATUS_RUNNING);
    if (pthread_create(&m->thread, NULL, mp_worker, m) != 0) {
        mp_set_err(m, "pthread_create gagal");
        atomic_store(&m->status, MP_STATUS_ERROR);
        return -1;
    }
    m->thread_valid = true;
    m->thread_joined = false;
    return 1;
}

int32_t mp_poll(void *h, char *buf, int32_t buf_max) {
    mp_ctx *m = (mp_ctx *)h;
    if (!m || !buf || buf_max <= 0) return -1;
    pthread_mutex_lock(&m->mutex);
    int32_t n = 0;
    while (n < buf_max - 1 && m->ring_r != m->ring_w) {
        buf[n++] = m->ring[m->ring_r];
        m->ring_r = (m->ring_r + 1) % MP_RING;
    }
    pthread_mutex_unlock(&m->mutex);
    if (n > 0) buf[n] = '\0';
    return n;
}

int32_t mp_status(void *h) {
    mp_ctx *m = (mp_ctx *)h;
    if (!m) return -1;
    return atomic_load(&m->status);
}

void mp_interrupt(void *h) {
    mp_ctx *m = (mp_ctx *)h;
    if (!m) return;
    atomic_store(&m->abort_flag, true);
}

const char * mp_error(void *h) {
    mp_ctx *m = (mp_ctx *)h;
    return m ? m->err : "handle tidak valid";
}

float mp_tokens_per_second(void *h) {
    mp_ctx *m = (mp_ctx *)h;
    return m ? (float)m->tokens_per_sec : 0.0f;
}

int32_t mp_n_generated(void *h) {
    mp_ctx *m = (mp_ctx *)h;
    return m ? m->n_generated : 0;
}

void mp_destroy(void *h) {
    mp_ctx *m = (mp_ctx *)h;
    if (!m) return;
    if (atomic_load(&m->status) == MP_STATUS_RUNNING) {
        atomic_store(&m->abort_flag, true);
    }
    if (m->thread_valid && !m->thread_joined) {
        pthread_join(m->thread, NULL);
        m->thread_joined = true;
    }
    pthread_mutex_destroy(&m->mutex);
    free(m->req_prompt);
    if (m->ctx) llama_free(m->ctx);
    if (m->model) llama_model_free(m->model);
    free(m);
}

int32_t mp_backend_cleanup(void) {
    llama_backend_free();
    return 1;
}
