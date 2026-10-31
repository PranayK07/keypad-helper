/* Keypad Helper experimental firmware. CC-BY-SA-3.0; see LICENSE and PROVENANCE.md. */
#include "lighting_protocol.h"

void kph_lighting_init(KPHLighting KPH_XDATA *state) {
    uint8_t i;
    state->sequence = 0;
    for (i = 0; i < 12; ++i) state->pixels[i] = 0;
}

uint8_t kph_lighting_apply(KPHLighting KPH_XDATA *state, const uint8_t KPH_XDATA *packet, uint8_t length) {
    uint8_t i;
    if (length != KPH_REPORT_SIZE) return 0;
    if (packet[0] != 'K' || packet[1] != 'P' || packet[2] != 'H' || packet[3] != 'L' ||
        packet[4] != KPH_PROTOCOL_VERSION || packet[5] != KPH_LED_COUNT ||
        packet[6] != 1 || packet[7] != 1 || packet[9] != 0) return 0;
    for (i = 22; i < KPH_REPORT_SIZE; ++i) if (packet[i] != 0) return 0;
    /* Validate the entire frame before committing any state. Called only from the USB ISR. */
    for (i = 0; i < 12; ++i) state->pixels[i] = packet[10 + i];
    state->sequence = packet[8];
    return 1;
}

void kph_lighting_report(const KPHLighting KPH_XDATA *state, uint8_t KPH_XDATA *packet) {
    uint8_t i;
    for (i = 0; i < KPH_REPORT_SIZE; ++i) packet[i] = 0;
    packet[0] = 'K'; packet[1] = 'P'; packet[2] = 'H'; packet[3] = 'L';
    packet[4] = KPH_PROTOCOL_VERSION;
    packet[5] = KPH_LED_COUNT;
    packet[6] = 1; /* independent steady RGB + brightness */
    packet[8] = state->sequence;
    for (i = 0; i < 12; ++i) packet[10 + i] = state->pixels[i];
}

uint8_t kph_scale(uint8_t color, uint8_t brightness) {
    /* Rounded 0..255 scaling: exact black at zero and exact color at full brightness. */
    return (uint8_t)(((uint16_t)color * brightness + 127u) / 255u);
}

void kph_render_pixels(const uint8_t KPH_XDATA *pixels, uint8_t suspended, uint8_t KPH_XDATA *rgb) {
    uint8_t i, j;
    for (i = 0; i < 3; ++i) for (j = 0; j < 3; ++j)
        rgb[i * 3 + j] = suspended ? 0 : kph_scale(pixels[i * 4 + j], pixels[i * 4 + 3]);
}
