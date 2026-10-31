/* Adapted from Stefan Wagner's CH552-Macropad-mini; CC-BY-SA-3.0. */
#pragma once
#include <stdint.h>
#include "usb.h"
#define EP0_SIZE 64
#define EP1_SIZE 8
#define EP0_ADDR 0
#define EP1_ADDR 64
#define EP0_BUF_SIZE 64
#define EP1_BUF_SIZE 8
extern __code uint8_t DevDescr[18];
extern __code uint8_t CfgDescr[52];
extern __code uint8_t KeyboardReportDescr[43];
extern __code uint8_t LightingReportDescr[21];
extern __code uint16_t LangDescr[];
extern __code uint16_t ManufDescr[];
extern __code uint16_t ProdDescr[];
extern __code uint16_t SerDescr[];
#define USB_STR_DESCR_i0 ((uint8_t*)LangDescr)
#define USB_STR_DESCR_i1 ((uint8_t*)ManufDescr)
#define USB_STR_DESCR_i2 ((uint8_t*)ProdDescr)
#define USB_STR_DESCR_i3 ((uint8_t*)SerDescr)
#define USB_STR_DESCR_ix ((uint8_t*)LangDescr)
