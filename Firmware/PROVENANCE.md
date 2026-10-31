# Firmware provenance

The firmware directory is licensed under **Creative Commons Attribution-ShareAlike 3.0 Unported**. The original license notice is retained in [LICENSE](LICENSE). License text: https://creativecommons.org/licenses/by-sa/3.0/legalcode . This attribution and share-alike licensing apply to this firmware derivative; it is kept separate from the Mac application.

Foundation: **Stefan Wagner, CH552-Macropad-mini (2023)**

- Repository: https://github.com/wagiminator/CH552-Macropad-mini
- Pinned commit: `31a16d4c17c0326108934d5fb63a48a311193c89`
- License at that commit: https://github.com/wagiminator/CH552-Macropad-mini/blob/31a16d4c17c0326108934d5fb63a48a311193c89/LICENSE
- Imported from `software/src`: `ch554.h`, `delay.c`, `delay.h`, `gpio.h`, `neo.c`, `neo.h`, `system.h`, `usb.h`, `usb_descr.h`, `usb_handler.c`, `usb_handler.h`, `usb_hid.c`, and `usb_hid.h`.
- Original author and WCH register-header notices remain in the source.

Changes made for Keypad Helper (2026): composite keyboard/Feature descriptors, strict lighting requests and acknowledgement, nonblocking HID keyboard transport, bounded encoder queue, real held-key tracking, independent static color/brightness rendering, build-only packaging, and native tests. No unlicensed Tastierino source or binary is incorporated. No upstream flashing utility or flash target is included.

Candidate wiring was researched from the CH552G three-key/one-knob projects, including https://github.com/eccherda/ch552g_mini_keyboard . These pin assignments remain an unverified board assumption, not a claim of schematic equivalence.

## Compiler used for the local check

SDCC 4.2.2 build 13407, macOS x86_64, distributed by CH55xDuino. This compiler is a development dependency, ignored by git and not part of the firmware source distribution.

- Package index: https://github.com/DeqingSun/ch55xduino/blob/ch55xduino/package_ch55xduino_mcs51_index.json
- Archive: https://github.com/DeqingSun/ch55xduino/releases/download/0.0.20/sdcc-mcs51-x86_64-apple-macosx-20220422-13407_4.tar.bz2
- SHA-256: `95380334bf51cf8e29e2654b59c8840528f94dc7367d411bb66efe48d5260746`

The compiler archive was checksum-verified before extraction. The local build used the MCS-51 backend, `--nooverlay`, explicit XDATA core pointers, and a 14 KiB application limit. No connected device was opened during compilation, tests, or packaging.
