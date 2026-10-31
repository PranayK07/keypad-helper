# Board and recovery verification

Research status: 2026-10-30. The working keypad still has its original firmware. No firmware, bootloader, or configuration writes have been performed.

## What we know

- The owner's underside photograph clearly identifies **WCH CH552G**, marked **U7**.
- The layout strongly matches [eccherda's reference board](https://github.com/eccherda/ch552g_mini_keyboard/blob/master/img/bottom.jpeg): U7 placement, the C2/R10/R12 and C4/R16/R17 groups, switch sockets, USB/encoder position, and surrounding traces.
- That project's [documented pinout](https://github.com/eccherda/ch552g_mini_keyboard#pinout) uses **P3.4** for three addressable LEDs. This supports the firmware candidate, but does not electrically verify this particular board or its LED order.
- The reference project [marks R12 for boot entry](https://github.com/eccherda/ch552g_mini_keyboard/blob/master/img/short.jpeg). **R12 is a candidate on the owner's board, not a confirmed connection. Do not bridge it yet.**

## The two useful photos

The owner has no multimeter. With USB disconnected, provide:

1. A sharp, close, straight-on photo containing the entire **U7 chip and its pin-1 dot**, **C2/R10/R12**, and the traces between them. Keep the chip legs and resistor markings in focus.
2. A sharp photo of the **opposite/component side**, showing all three LEDs and their nearby traces and markings, if accessible without desoldering.

These can improve the visual match. They may still leave connections that require an unpowered continuity check by someone with suitable equipment. Do not guess at obscured traces or substitute arbitrary pads.

## Recovery constraints

The [WCH CH552 datasheet](https://cdn-learn.adafruit.com/assets/assets/000/129/847/original/CH552DS1.PDF?1715004485=) (manufacturer document mirrored by Adafruit, sections 3–4 and 6) establishes:

- On CH552G SOP16, **P3.4 is pin 11**, **P3.6/USB D+ is pin 12**, and **V33 is pin 16**. P3.6 is in the V33 voltage domain and is **not 5 V tolerant**. Generic instructions saying “VCC” must not be interpreted as permission to connect USB 5 V to it.
- Application flash ends at **0x37FF**. The bootloader starts at **0x3800**, and configuration starts at **0x3FF8**. The bootloader is stored in rewritable flash, not immutable ROM. Preserve both its region and boot configuration.
- Protected code cannot be read through the external programmer. Removing protection by erasing is not a backup method.

After identifying the correct recovery connection, the next hardware milestone is a supervised **bootloader identification check followed by a return to the original keyboard**, without programming. The current [wchisp `info` implementation](https://github.com/ch32-rs/wchisp/blob/main/src/flashing.rs) identifies the chip and reads configuration; its [command definitions](https://github.com/ch32-rs/wchisp/blob/main/src/main.rs) provide no code-flash backup command. EEPROM dump covers separate DataFlash, not the factory firmware.

Successful bootloader access would support recovery to a compatible custom image. **Restoring the original factory behavior still requires an original firmware image; that rollback is not currently available.** Until the recovery path is verified and a firmware test is explicitly authorized, retain stock operation. The app's individual LED controls must remain gated on compatible firmware detection and the owner's physical LED verification.
