/* Experimental CH552G keypad firmware. CC-BY-SA-3.0; see PROVENANCE.md.
 * Building this file never accesses USB. This firmware has NOT been hardware verified. */
#include "src/config.h"
#include "src/system.h"
#include "src/gpio.h"
#include "src/neo.h"
#include "src/usb_handler.h"
#include "src/input_state.h"

static __xdata KPHInput input_state;
static __xdata uint8_t proposed_report[8];
static __xdata uint8_t sent_report[8];
static __xdata uint8_t led_snapshot[12];
static __xdata uint8_t led_wire[9];
extern volatile uint8_t keyboard_resend;
extern volatile uint8_t keyboard_idle;

static uint8_t encoder_read(void) {
    return (PIN_read(PIN_ENCODER_A) ? 2 : 0) | (PIN_read(PIN_ENCODER_B) ? 1 : 0);
}
static uint8_t keys_read(void) {
    return (!PIN_read(PIN_KEY1) ? 1 : 0) | (!PIN_read(PIN_KEY2) ? 2 : 0) |
           (!PIN_read(PIN_KEY3) ? 4 : 0) | (!PIN_read(PIN_DIAL_SWITCH) ? 8 : 0);
}
static void update_lights(uint8_t inactive) {
    uint8_t i;
    if (!lighting_dirty) return;
    EA = 0;
    for (i = 0; i < 12; ++i) led_snapshot[i] = lighting_state.pixels[i];
    lighting_dirty = 0;
    EA = 1;
    kph_render_pixels(led_snapshot, inactive, led_wire);
    EA = 0;
    for (i = 0; i < 3; ++i) NEO_writeColor(led_wire[i * 3], led_wire[i * 3 + 1], led_wire[i * 3 + 2]);
    EA = 1;
    NEO_latch();
}

void main(void) {
    uint8_t i, held, changed, suspended, inactive, was_inactive = 0;
    int8_t movement, queued = 0, dial_phase = 0;
    uint16_t idle_ticks = 0;
    CLK_config();
    PIN_input_PU(PIN_KEY1); PIN_input_PU(PIN_KEY2); PIN_input_PU(PIN_KEY3);
    PIN_input_PU(PIN_DIAL_SWITCH); PIN_input_PU(PIN_ENCODER_A); PIN_input_PU(PIN_ENCODER_B);
    kph_lighting_init(&lighting_state);
    kph_input_init(&input_state, encoder_read());
    NEO_init();
    /* Make darkness explicit before enumeration; never show a boot flash. */
    EA = 0;
    for (i = 0; i < 3; ++i) NEO_writeColor(0, 0, 0);
    NEO_latch();
    for (i = 0; i < 8; ++i) { keyboard_report[i] = 0; sent_report[i] = 0xff; }
    HID_init();
    while (1) {
        suspended = (USB_MIS_ST & bUMS_SUSPEND) != 0;
        inactive = suspended || !UsbConfig;
        if (inactive != was_inactive) {
            lighting_dirty = 1;
            keyboard_resend = 1;
            was_inactive = inactive;
        }
        held = kph_keys_update(&input_state, keys_read());
        movement = kph_encoder_update(&input_state, encoder_read());
        if (movement > 0 && queued < 8) ++queued;
        if (movement < 0 && queued > -8) --queued;
        if (!UsbConfig || suspended) { queued = 0; dial_phase = 0; }
        if (!dial_phase && queued) dial_phase = queued > 0 ? 1 : -1;
        kph_keyboard_report(held, dial_phase == 2 ? 0 : dial_phase, proposed_report);
        changed = keyboard_resend;
        for (i = 0; i < 8; ++i) if (proposed_report[i] != sent_report[i]) changed = 1;
        if (keyboard_idle && ++idle_ticks >= ((uint16_t)keyboard_idle << 2)) changed = 1;
        if (changed && HID_trySend(proposed_report)) {
            keyboard_resend = 0;
            idle_ticks = 0;
            for (i = 0; i < 8; ++i) { sent_report[i] = proposed_report[i]; keyboard_report[i] = proposed_report[i]; }
            if (dial_phase == 1) { --queued; dial_phase = 2; }
            else if (dial_phase == -1) { ++queued; dial_phase = 2; }
            else if (dial_phase == 2) dial_phase = 0;
        }
        update_lights(inactive);
        DLY_ms(1);
    }
}
void usb_isr(void) __interrupt (INT_NO_USB) { USB_interrupt(); }
