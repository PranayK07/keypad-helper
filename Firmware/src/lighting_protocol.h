/* Keypad Helper experimental firmware. CC-BY-SA-3.0; see LICENSE and PROVENANCE.md. */
#ifndef KPH_LIGHTING_PROTOCOL_H
#define KPH_LIGHTING_PROTOCOL_H
#include <stdint.h>
#include "memory.h"
#define KPH_REPORT_SIZE 32
#define KPH_LED_COUNT 3
#define KPH_PROTOCOL_VERSION 1
/* A full snapshot: 3 x (red, green, blue, brightness), not a display animation. */
typedef struct {
    uint8_t sequence;
    uint8_t pixels[12];
} KPHLighting;
void kph_lighting_init(KPHLighting KPH_XDATA *state);
uint8_t kph_lighting_apply(KPHLighting KPH_XDATA *state, const uint8_t KPH_XDATA *packet, uint8_t length);
void kph_lighting_report(const KPHLighting KPH_XDATA *state, uint8_t KPH_XDATA *packet);
uint8_t kph_scale(uint8_t color, uint8_t brightness);
void kph_render_pixels(const uint8_t KPH_XDATA *pixels, uint8_t suspended, uint8_t KPH_XDATA *rgb);
#endif
