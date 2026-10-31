# Keypad Helper lighting protocol 1

Experimental, unverified on hardware. A replacement-firmware protocol; never send these reports to stock firmware.

## Discovery and transport

- USB VID/PID: `1189:8890` (existing keypad identity).
- Manufacturer exactly `Keypad Helper`; product exactly `Keypad Helper RGB`.
- Interface 0: boot-compatible keyboard, 8-byte Input reports, no report ID, endpoint 1 IN.
- Interface 1: HID vendor usage page `0xFF60`, top-level usage `0x61`, 32-byte **Feature** report, report ID 0. No interrupt input/output endpoint on this interface.
- macOS: `IOHIDDeviceGetReport` / `IOHIDDeviceSetReport`, type Feature, report ID 0, length 32. The buffer is exactly the payload below; do not prepend an ID byte.
- Read and validate the signature before writing. Exact descriptors alone are insufficient.
- Reject multiple candidates; require a single matching device. A shared firmware serial is not a unique unit identity.

## Frame

| Byte(s) | Meaning |
|---|---|
| 0–3 | ASCII `KPHL` |
| 4 | Protocol version `1` |
| 5 | LED count `3` |
| 6 | Capability flags `1` = independent steady RGB + brightness |
| 7 | Read response: `0`; write request: `1` = apply |
| 8 | 8-bit sequence supplied by app, echoed after acceptance; wrapping allowed |
| 9 | `0` |
| 10–13 | LED 1: red, green, blue, brightness |
| 14–17 | LED 2: red, green, blue, brightness |
| 18–21 | LED 3: red, green, blue, brightness |
| 22–31 | Reserved, all zero |

Each channel is 0…255. Brightness 0 turns that LED off; 255 gives the requested color. Firmware scales each channel as `(color * brightness + 127) / 255`. Lighting writes replace all three records atomically. There are no animations, keypress overrides, EEPROM saves, mapping writes, erase commands, or bootloader commands.

`GET_REPORT` returns the most recently accepted RGB/brightness values and sequence. Startup is sequence zero, all RGB and brightness zero. `SET_REPORT` rejects incorrect size, magic, version, count, capability bits, operation, byte 9, or reserved fields by stalling the control transfer; the previously accepted lighting state remains intact. A new valid setup transaction can follow a stall normally.

After a write, read back and match the entire frame, including sequence and all three LED records. Readback confirms a firmware state change, **not** physical LED behavior. Actual LED output is refreshed by the main loop after the accepted write. Profile changes only write RAM; removing power clears colors until the app reapplies them.

## Example

Apply sequence 42, dim red/green/blue respectively:

```
4b 50 48 4c 01 03 01 01 2a 00 ff 00 00 40 00 ff
00 40 00 00 ff 40 00 00 00 00 00 00 00 00 00 00
```

The response is identical except byte 7 is zero.

USB suspend or an unconfigured USB connection blanks the physical LEDs without changing the stored scene or readback. Wake restores the same scene and resends the current physical key state, including releases that happened while asleep.
