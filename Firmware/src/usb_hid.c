/* Adapted from Stefan Wagner's CH552-Macropad-mini; CC-BY-SA-3.0. */
#include "ch554.h"
#include "usb_handler.h"
volatile __bit HID_EP1_writeBusyFlag = 0;
volatile uint8_t keyboard_resend = 1;
void HID_init(void) { USB_init(); UEP1_T_LEN = 0; }
/* Nonblocking so unplug, suspend, or a stopped host never traps the main loop. */
uint8_t HID_trySend(__xdata uint8_t *buf) {
    uint8_t i;
    if (!UsbConfig || HID_EP1_writeBusyFlag || (USB_MIS_ST & bUMS_SUSPEND)) return 0;
    for (i = 0; i < 8; ++i) EP1_buffer[i] = buf[i];
    UEP1_T_LEN = 8;
    HID_EP1_writeBusyFlag = 1;
    UEP1_CTRL = (UEP1_CTRL & ~MASK_UEP_T_RES) | UEP_T_RES_ACK;
    return 1;
}
void HID_setup(void) {
    UEP1_DMA = EP1_ADDR;
    UEP1_CTRL = bUEP_AUTO_TOG | UEP_T_RES_NAK;
    UEP4_1_MOD = bUEP1_TX_EN;
    UEP2_3_MOD = 0;
}
void HID_reset(void) {
    UEP1_CTRL = bUEP_AUTO_TOG | UEP_T_RES_NAK;
    HID_EP1_writeBusyFlag = 0;
    UsbConfig = 0;
    keyboard_resend = 1;
}
void HID_EP1_IN(void) {
    UEP1_T_LEN = 0;
    UEP1_CTRL = (UEP1_CTRL & ~MASK_UEP_T_RES) | UEP_T_RES_NAK;
    HID_EP1_writeBusyFlag = 0;
}
