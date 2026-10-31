#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "lighting_protocol.h"
#include "input_state.h"
static unsigned checks;
#define CHECK(x) do { ++checks; assert(x); } while (0)
static int contains(const uint8_t *r, uint8_t key) {
    unsigned i; for (i = 2; i < 8; ++i) if (r[i] == key) return 1; return 0;
}
int main(void) {
    KPHLighting s, before;
    KPHInput input;
    uint8_t packet[32], reply[32], bad[32], report[8], rgb[9], awake_rgb[9];
    unsigned i, j, color, brightness;
    kph_lighting_init(&s);
    for (i = 0; i < 12; ++i) CHECK(s.pixels[i] == 0);
    kph_lighting_report(&s, packet);
    CHECK(!memcmp(packet, "KPHL", 4));
    CHECK(packet[4] == 1 && packet[5] == 3 && packet[6] == 1 && packet[7] == 0);
    packet[7] = 1; packet[8] = 237;
    for (i = 0; i < 12; ++i) packet[10+i] = (uint8_t)(i*23);
    CHECK(kph_lighting_apply(&s, packet, 32));
    CHECK(s.sequence == 237 && !memcmp(s.pixels, packet+10, 12));
    kph_lighting_report(&s, reply);
    CHECK(reply[7] == 0 && reply[8] == 237 && reply[9] == 0);
    CHECK(!memcmp(reply+10, packet+10, 12));
    before = s;
    /* Every truncated/oversized frame, command/magic/version/capability mismatch,
       error byte and nonzero reserved byte must be rejected atomically. */
    for (i = 0; i <= 255; ++i) if (i != 32) {
        CHECK(!kph_lighting_apply(&s, packet, (uint8_t)i));
        CHECK(!memcmp(&s, &before, sizeof(s)));
    }
    for (i = 0; i < 32; ++i) if (i < 8 || i == 9 || i >= 22) {
        for (j = 1; j <= 255; ++j) {
            memcpy(bad, packet, 32); bad[i] ^= (uint8_t)j;
            CHECK(!kph_lighting_apply(&s, bad, 32));
            CHECK(!memcmp(&s, &before, sizeof(s)));
        }
    }
    /* Duplicate writes are idempotent, sequence wrap is accepted. */
    CHECK(kph_lighting_apply(&s, packet, 32));
    CHECK(!memcmp(&s, &before, sizeof(s)));
    packet[8] = 0; CHECK(kph_lighting_apply(&s, packet, 32)); CHECK(s.sequence == 0);
    for (color = 0; color < 256; ++color) {
        CHECK(kph_scale(color, 0) == 0);
        CHECK(kph_scale(color, 255) == color);
        for (brightness = 0; brightness < 256; ++brightness) {
            CHECK(kph_scale(color, brightness) == (color * brightness + 127) / 255);
            CHECK(kph_scale(color, brightness) <= color);
        }
    }
    /* Suspend changes physical output only; wake restores the exact RAM scene. */
    kph_render_pixels(s.pixels, 0, awake_rgb);
    kph_render_pixels(s.pixels, 1, rgb);
    for (i = 0; i < 9; ++i) CHECK(rgb[i] == 0);
    CHECK(!memcmp(s.pixels, before.pixels, 12));
    kph_render_pixels(s.pixels, 0, rgb);
    CHECK(!memcmp(rgb, awake_rgb, 9));
    for (i = 0; i < 3; ++i) for (j = 0; j < 3; ++j)
        CHECK(rgb[i*3+j] == kph_scale(s.pixels[i*4+j], s.pixels[i*4+3]));
    /* Real holds, simultaneous keys and bouncing edges. */
    kph_input_init(&input, 3);
    CHECK(kph_keys_update(&input, 1) == 0);
    CHECK(kph_keys_update(&input, 0) == 0);
    for (i = 0; i < 4; ++i) CHECK(kph_keys_update(&input, 15) == 0);
    CHECK(kph_keys_update(&input, 15) == 15);
    for (i = 0; i < 2000; ++i) CHECK(kph_keys_update(&input, 15) == 15);
    kph_keyboard_report(input.stable, -1, report);
    CHECK(report[0] == 0 && report[1] == 0);
    CHECK(contains(report, 0x68) && contains(report, 0x69) && contains(report, 0x6a));
    CHECK(contains(report, 0x6c) && contains(report, 0x6b) && !contains(report, 0x6d));
    for (i = 0; i < 4; ++i) CHECK(kph_keys_update(&input, 0) == 15);
    CHECK(kph_keys_update(&input, 0) == 0);
    kph_keyboard_report(input.stable, 0, report);
    for (i = 0; i < 8; ++i) CHECK(report[i] == 0);
    /* One full Gray-code cycle is one dial event; bounce/invalid jumps don't invent events. */
    CHECK(kph_encoder_update(&input, 2) == 0);
    CHECK(kph_encoder_update(&input, 0) == 0);
    CHECK(kph_encoder_update(&input, 1) == 0);
    CHECK(kph_encoder_update(&input, 3) == 1);
    CHECK(kph_encoder_update(&input, 1) == 0);
    CHECK(kph_encoder_update(&input, 0) == 0);
    CHECK(kph_encoder_update(&input, 2) == 0);
    CHECK(kph_encoder_update(&input, 3) == -1);
    CHECK(kph_encoder_update(&input, 0) == 0); /* invalid two-bit jump */
    CHECK(input.quarter_steps == 0);
    /* Keyboard events never mutate saved LED state. */
    kph_lighting_report(&s, reply);
    CHECK(!memcmp(reply+10, before.pixels, 12));
    printf("Firmware core: %u checks passed (no device access).\n", checks);
    return 0;
}
