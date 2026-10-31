/* Keypad Helper experimental firmware. CC-BY-SA-3.0. */
#ifndef KPH_INPUT_STATE_H
#define KPH_INPUT_STATE_H
#include <stdint.h>
#include "memory.h"
typedef struct {
    uint8_t stable;
    uint8_t candidate;
    uint8_t count[4];
    uint8_t encoder;
    int8_t quarter_steps;
} KPHInput;
void kph_input_init(KPHInput KPH_XDATA *state, uint8_t encoder);
uint8_t kph_keys_update(KPHInput KPH_XDATA *state, uint8_t pressed);
int8_t kph_encoder_update(KPHInput KPH_XDATA *state, uint8_t encoder);
void kph_keyboard_report(uint8_t held, int8_t dial, uint8_t KPH_XDATA *report);
#endif
