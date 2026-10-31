/* Keypad Helper experimental firmware. CC-BY-SA-3.0. */
#include "input_state.h"
void kph_input_init(KPHInput KPH_XDATA *state, uint8_t encoder) {
    uint8_t i;
    state->stable = state->candidate = 0;
    for (i = 0; i < 4; ++i) state->count[i] = 0;
    state->encoder = encoder & 3;
    state->quarter_steps = 0;
}
uint8_t kph_keys_update(KPHInput KPH_XDATA *state, uint8_t pressed) {
    uint8_t i, bit;
    for (i = 0; i < 4; ++i) {
        bit = (uint8_t)(1u << i);
        if ((pressed ^ state->candidate) & bit) {
            state->candidate ^= bit;
            state->count[i] = 1;
        } else if (state->count[i] < 5) ++state->count[i];
        if (state->count[i] == 5) {
            state->stable = (state->stable & (uint8_t)~bit) | (pressed & bit);
        }
    }
    return state->stable;
}
int8_t kph_encoder_update(KPHInput KPH_XDATA *state, uint8_t encoder) {
    uint8_t transition;
    int8_t step = 0;
    encoder &= 3;
    transition = (state->encoder << 2) | encoder;
    switch (transition) {
        case 1: case 7: case 14: case 8: step = 1; break;
        case 2: case 11: case 13: case 4: step = -1; break;
        default:
            if (encoder != state->encoder) state->quarter_steps = 0;
            break;
    }
    state->encoder = encoder;
    state->quarter_steps += step;
    if (state->quarter_steps >= 4) { state->quarter_steps = 0; return 1; }
    if (state->quarter_steps <= -4) { state->quarter_steps = 0; return -1; }
    return 0;
}
void kph_keyboard_report(uint8_t held, int8_t dial, uint8_t KPH_XDATA *report) {
    uint8_t i, slot = 2;
    for (i = 0; i < 8; ++i) report[i] = 0;
    if (held & 1) report[slot++] = 0x68; /* F13 */
    if (held & 2) report[slot++] = 0x69; /* F14 */
    if (held & 4) report[slot++] = 0x6a; /* F15 */
    if (held & 8) report[slot++] = 0x6c; /* F17: encoder switch */
    if (dial < 0) report[slot] = 0x6b;   /* F16: counterclockwise */
    if (dial > 0) report[slot] = 0x6d;   /* F18: clockwise */
}
