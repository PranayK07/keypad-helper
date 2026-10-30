# First cup: connect your keypad ☕

This version is for the Bright Data three-key keypad with one rotary dial (CH57x, USB `1189:8890`). Similar-looking keypads may work differently.

## Give the keypad its six signals

Your keypad needs a one-time setup before the app can recognize it. After that, changing profiles never reprograms the keypad.

The setup replaces its existing button assignments. Keep any configuration file you already use so you can restore it later; the programmer cannot read the current assignments back from the device.

<details>
<summary>First-time keypad programming</summary>

1. Download this repository using **Code → Download ZIP**, then unzip it.
2. Install [Rust](https://www.rust-lang.org/tools/install) if it is not already installed. Follow its macOS prerequisites.
3. Connect the keypad with a USB data cable. Open Terminal, type `cd` followed by a space, drag the unzipped repository folder into Terminal, and press Return.
4. Run these commands, one at a time:

```sh
cargo install ch57x-keyboard-tool --version 1.8.0
~/.cargo/bin/ch57x-keyboard-tool validate config/keypad-bindings.yaml
~/.cargo/bin/ch57x-keyboard-tool upload config/keypad-bindings.yaml
```

The final command writes the [provided configuration](../config/keypad-bindings.yaml): F13–F15 for the three keys, and F16/F17/F18 for dial left/press/right. See the [programmer’s documentation](https://github.com/kriomant/ch57x-keyboard-tool) if your device is not detected.

</details>

## Connect the app

Open **Keypad Companion** and follow its permission prompts. Enable **Accessibility** and **Input Monitoring** for the app in System Settings. Reopen it if macOS asks.

In **Overview**, pause controls and expand **Check keypad input**. Press all three keys and turn/press the dial to confirm each registers, then resume.

## A small extra step for Coding

Coding uses Codex with these shortcuts:

| Action | Shortcut |
|---|---|
| Hold to dictate | Control + Shift + D |
| Lower reasoning | Control + Shift + 0 |
| Clear prompt | Control + Shift + 1 |
| Higher reasoning | Control + Shift + 2 |

Add or update the four entries in the [Codex shortcut sample](../config/codex-keybindings.json) within `~/.codex/keybindings.json`. Preserve your other shortcuts; do not replace the whole file. Bring Codex to the front when using Coding controls.
