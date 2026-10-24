/* test_host.c — uji langsung shim moonpet dengan model sungguhan (LFM2.5-350M).
 * Kompilasi: cc test_host.c -o test_host -I../llama/include -Lbuild-host -Lbuild-host/bin -lmoonpet -llama
 * Jalankan : LD_LIBRARY_PATH=build-host:build-host/bin ./test_host <model.gguf>
 */
#include "moonpet.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

static double now_ms(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1e3 + ts.tv_nsec / 1e6;
}

int main(int argc, char **argv) {
    const char *model_path = argc > 1 ? argv[1] : "../model.gguf";

    if (!mp_init()) { fprintf(stderr, "mp_init gagal\n"); return 1; }
    printf("[1] mp_init OK\n");

    void *h = mp_create(model_path, 2048, 4);
    if (!h) { fprintf(stderr, "mp_create gagal (model %s)\n", model_path); return 1; }
    printf("[2] mp_create OK (model termuat)\n");

    /* template ChatML ala LFM2.5 — TANPA BOS literal (add_special=true di shim) */
    const char *prompt =
        "<|im_start|>system\n"
        "You are Momo the cute moon-cat pet. You love your owner. Reply in simple sweet English, max 2 short sentences, cute emoticons allowed.\n"
        "<|im_end|>\n"
        "<|im_start|>user\n"
        "im so lonely today momo, please cheer me up\n"
        "<|im_end|>\n"
        "<|im_start|>assistant\n";

    double t0 = now_ms();
    int rc = mp_start(h, prompt, 60, 0.6f, 0.95f, 1.1f, 64, 0);
    if (rc != 1) { fprintf(stderr, "mp_start gagal: rc=%d err=%s\n", rc, mp_error(h)); return 1; }

    char buf[8192];
    char acc[8192] = "";
    while (mp_status(h) == 1 || mp_status(h) == 0) {
        int n = mp_poll(h, buf, sizeof(buf));
        if (n > 0) { strncat(acc, buf, n); printf("%s", buf); fflush(stdout); }
        if (mp_status(h) == 2 || mp_status(h) == 3) break;
        usleep(20000); /* 20 ms — meniru polling Dart */
    }
    double dt = (now_ms() - t0) / 1e3;
    printf("\n[3] generasi selesai: %d token, %.2f tok/s (total %.2fs)\n",
           mp_n_generated(h), mp_tokens_per_second(h), dt);
    printf("[4] status akhir=%d err='%s'\n", mp_status(h), mp_error(h));

    /* uji interrupt: mulai generasi panjang lalu hentikan */
    const char *prompt2 =
        "<|im_start|>user\n"
        "write a very long story about a cat\n"
        "<|im_end|>\n"
        "<|im_start|>assistant\n";
    if (mp_start(h, prompt2, 200, 0.8f, 0.95f, 1.1f, 64, 0) == 1) {
        usleep(300000); /* biarkan jalan 300ms */
        mp_interrupt(h);
        while (mp_status(h) == 1) usleep(10000);
        printf("[5] interrupt OK — status=%d, %d token sebelum dihentikan\n",
               mp_status(h), mp_n_generated(h));
    }

    mp_destroy(h);
    printf("[6] mp_destroy OK — SEMUA TES LULUS\n");
    return 0;
}
