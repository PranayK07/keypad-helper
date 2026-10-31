# A color for every light

This is an **unreleased development preview**. The app and firmware have been built and checked in software, but the firmware has not been installed on the keypad. Steady lighting is not yet a hardware-verified feature.

The separate **Keypad Lighting Preview** app lets you try the interface safely:

1. Open the preview. Its window says **Offline preview · no keypad changes**.
2. Choose **Test steady lights**, then **Preview color controls**. This simulates the hardware check; your physical LEDs will not change.
3. Select Coding, Music, or Calls, then choose LED 1, 2, or 3. Each light has its own color, brightness, and on/off setting.
4. Use **Match all** for a single color across the keypad, or turn off **Follow selected profile** to use one palette everywhere.

Preview edits are temporary. The preview does not read keypad input, send lighting commands, change your real app's preferences, register a startup item, or replace the working app. Closing its window leaves only the preview menu-bar icon; use **Quit app** in Preferences to exit it.

## When hardware testing becomes possible

The ordinary app keeps the existing Lights off, Key glow, and Rainbow cycle controls for stock firmware. It only offers custom RGB settings after it recognizes the experimental firmware and you confirm a physical light check. That check is required again after an app restart or keypad reconnect while this feature is experimental.

The real development app includes the per-light controls and USB transport; the offline preview is optional. Updating the app alone does not install firmware or unlock color controls on the stock keypad.

The proposed palettes are blue for Coding, green for Music, and magenta for Calls. You can change every light independently. Settings save on your Mac; changing profiles does not write the keypad's permanent memory. The dial retains its normal profile controls.

Installing firmware is a separate future step. The chip is confirmed as CH552G, but the board wiring and recovery method still need verification. The [board verification notes](../Firmware/BOARD-VERIFICATION.md) record the evidence and remaining checks. No flashing is part of this preview, and returning to the original vendor firmware has not been established.

After an approved installation, test steady light during presses and releases, individual LEDs, brightness, all six controls, profile changes, reconnect, and sleep/wake. Until those checks pass, keep the public release and working keypad on the current setup.

## Local build checks

For contributors, these commands only build or test; they do not open the keypad:

```sh
bash Tests/run.sh
make -C Firmware test
KEYPAD_PREVIEW=1 bash build.sh dist/preview
```

The firmware has its own [build notes and license](../Firmware/README.md). Its binaries remain separate from the normal app download.
