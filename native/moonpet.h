/* moonpet.h — header publik shim MoonPet (API flat untuk FFI Dart) */
#ifndef MOONPET_H
#define MOONPET_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* status: 0=idle, 1=running, 2=done, 3=error */
int32_t     mp_init(void);
void *      mp_create(const char *model_path, int32_t n_ctx, int32_t n_threads);
int32_t     mp_start(void *h, const char *prompt, int32_t max_tokens,
                     float temp, float top_p, float pen_repeat, int32_t pen_last_n,
                     uint64_t seed);
int32_t     mp_poll(void *h, char *buf, int32_t buf_max);
int32_t     mp_status(void *h);
void        mp_interrupt(void *h);
const char *mp_error(void *h);
float       mp_tokens_per_second(void *h);
int32_t     mp_n_generated(void *h);
void        mp_destroy(void *h);
int32_t     mp_backend_cleanup(void);

#ifdef __cplusplus
}
#endif
#endif /* MOONPET_H */
