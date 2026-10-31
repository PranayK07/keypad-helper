# Experimental steady lighting

This is a **build-only firmware candidate** for the CH552G version of the three-key, one-dial keypad. It has not been installed or tested on the physical keypad. The app can be updated independently; it continues using the existing lighting controls while the keypad has stock firmware.

It is designed to let Keypad Helper choose a steady RGB color, brightness, and on/off state independently for each of the three lights. Key presses and dial actions do not change the lighting. All lights start off after power-up; the app sends its chosen colors after connection and user verification. Lights stay dark until USB configuration is granted, go dark during USB suspend and restore their RAM colors on wake; key presses never select a lighting effect.

The app keeps its existing controls: F13, F14, F15 for the three keys; F16 for turning left, F17 for holding the dial button, and F18 for turning right. Buttons send genuine press and release reports, including simultaneous holds. The dial never changes the profile.

## What has been checked

- The firmware compiles with SDCC for CH552G and fits below the bootloader area.
- Host-side tests check malformed-packet rejection, atomic updates, all brightness values, held keys, debouncing, simultaneous controls, and encoder transitions.
- Embedded linker checks reject overlapping function parameters and generic-pointer helpers that could corrupt state across USB interrupts. The build retains at least 128 bytes of stack.
- Descriptor checks confirm a regular keyboard interface and a separate, identifiable lighting interface.
- No flashing tool or flash/install target is included. Building and testing do not access USB devices.

**These are software checks, not confirmation that the lights or controls work on this board.** The processor marking is confirmed from a photo, but the wiring below still needs physical verification.

## Build without touching the keypad

Requires SDCC with its MCS-51 backend, Python 3, make, and clang for host tests.

```sh
cd Firmware
make test
make all
```

An explicit compiler path is supported:

```sh
make SDCC=/path/to/sdcc all
```

For this development build, a checksum-verified copy of SDCC 4.2.2 build 13407 is kept locally in the ignored `.toolchain/` directory:

```sh
make SDCC=.toolchain/sdcc/bin/sdcc all
```

Outputs in `build/`: `keypad-helper-rgb.hex`, `.bin`, and a `.json` manifest with the binary checksum and `hardware_verified: false`. The packaging step rejects code outside the CH552 application range `0x0000…0x37ff`. It does not read, erase, or program any device. Keep the firmware binary separate from the ordinary app download.

## Board assumptions to verify

| Connection | Candidate pin |
|---|---|
| Key 1 / Key 2 / Key 3 | P1.1 / P1.7 / P1.6 |
| Dial button | P3.3 |
| Dial A / B | P3.1 / P3.0 |
| Three addressable LEDs | P3.4, GRB order |

The definitions are in `src/config.h`. LED numbering follows the physical LED chain, so which light the app calls 1, 2, or 3 must also be checked on hardware. Encoder direction and detents need checking. A matching CH552G chip or USB ID alone does not validate these assumptions.

The firmware uses the existing keypad's `1189:8890` USB identity only as a replacement for that device. It additionally identifies itself as **Keypad Helper RGB**, manufacturer **Keypad Helper**, and exposes the documented lighting signature. These IDs are not an allocation for manufacturing new USB products. Its fixed serial is a firmware-family label, not a unique physical-device identifier; the app must not reuse a visual verification solely because that serial matches.

## Before any future hardware test

A separate, explicitly approved installation step must first establish the correct pin wiring, board-specific programming access, and a recovery method. Return to the original vendor firmware is not guaranteed; no stock firmware backup has been obtained. Do not follow a generic instruction to bridge a component simply because its label matches another board.

See the [board verification notes](BOARD-VERIFICATION.md) for the current evidence and the remaining physical checks.

After an approved installation, verify all six controls and real held-key release behavior. Then use the app's explicit light test: confirm all three LEDs hold their requested colors while pressing, holding, and releasing every key. Check each LED individually, brightness, profile changes, reconnect, and sleep/wake before enabling automatic custom lighting or publishing it as supported. The app's USB acknowledgement only confirms accepted bytes, not visible light output.

See [protocol](PROTOCOL.md) for the app contract and [provenance](PROVENANCE.md) for the source and license.
