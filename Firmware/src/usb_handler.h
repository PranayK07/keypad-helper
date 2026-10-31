/* Adapted from Stefan Wagner's CH552-Macropad-mini; CC-BY-SA-3.0. */
#pragma once
#include <stdint.h>
#include "usb_descr.h"
#include "lighting_protocol.h"
#ifdef KPH_DEFINE_USB_BUFFERS
__xdata __at (EP0_ADDR) uint8_t EP0_buffer[EP0_BUF_SIZE];
__xdata __at (EP1_ADDR) uint8_t EP1_buffer[EP1_BUF_SIZE];
#else
extern __xdata uint8_t EP0_buffer[EP0_BUF_SIZE];
extern __xdata uint8_t EP1_buffer[EP1_BUF_SIZE];
#endif
#define USB_setupBuf ((PXUSB_SETUP_REQ)EP0_buffer)
extern uint8_t SetupReq;
extern volatile uint8_t UsbConfig;
extern __xdata KPHLighting lighting_state;
extern volatile uint8_t lighting_dirty;
extern __xdata uint8_t keyboard_report[8];
void HID_setup(void);
void HID_reset(void);
void HID_EP1_IN(void);
void HID_init(void);
uint8_t HID_trySend(__xdata uint8_t *buf);
uint8_t HID_classRequest(void);
#define USB_INIT_handler HID_setup
#define USB_RESET_handler HID_reset
#define USB_CTRL_NS_handler HID_classRequest
#define EP0_SETUP_callback USB_EP0_SETUP
#define EP0_IN_callback USB_EP0_IN
#define EP0_OUT_callback USB_EP0_OUT
#define EP1_IN_callback HID_EP1_IN
void USB_interrupt(void);
void USB_init(void);
