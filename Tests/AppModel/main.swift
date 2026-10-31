import Foundation

// Only isolated preview models are constructed. No AppDelegate, event tap,
// HID manager, USB transport, login registration, or production defaults writes.
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    precondition(condition(), message)
}
let realSettings = UserDefaults.standard.persistentDomain(forName: "local.pranay.keypadcompanion") ?? [:]
let stock = AppModel(preview: .stock)
stock.start()
check(stock.isLightingPreview && stock.paused, "Preview must isolate input and start paused")
check(stock.customLightingConnection == nil && !stock.customLightingVerified, "Stock firmware cannot expose RGB controls")
stock.beginRGBHardwareTest()
stock.confirmRGBHardwareTest()
check(!stock.customLightingVerified, "Stock cannot be promoted to custom firmware through UI methods")
stock.lightingFollowsProfile = true
stock.setLightingMode(.rainbow, for: .music)
stock.profile = .music
stock.reapplyLighting()
check(stock.lightingMode(for: .music) == .rainbow, "Stock effect editor remains functional")
stock.shutdown()

let unsupported = AppModel(preview: .unavailable)
unsupported.start()
unsupported.beginRGBHardwareTest()
unsupported.confirmRGBHardwareTest()
check(unsupported.customFirmwarePresent && unsupported.customLightingConnection == nil && !unsupported.customLightingVerified,
      "Unrecognized custom protocol must show unavailable, never stock effects or editable RGB")
unsupported.shutdown()

let model = AppModel(preview: .verify)
model.start()
check(model.customLightingConnection != nil && !model.customLightingVerified, "Compatible firmware still needs verification")
model.confirmRGBHardwareTest()
check(!model.customLightingVerified, "Cannot confirm before test delivery")
model.beginRGBHardwareTest()
check(model.customLightingTestSent && !model.customLightingVerified, "Simulated readback must await user confirmation")
model.cancelRGBHardwareTest()
check(!model.customLightingTestSent && !model.customLightingVerified, "Not-working path must revoke custom controls")
model.beginRGBHardwareTest()
model.confirmRGBHardwareTest()
check(model.customLightingVerified, "Confirmed test enables editor")
let originalCoding = model.rgbScene(for: .coding)
let originalCalls = model.rgbScene(for: .calls)
var music = model.rgbScene(for: .music)
music.leds[1].enabled = false
music.leds[2].color = RGBColor(red: 255, green: 24, blue: 48)
music.leds[2].brightness = 12
model.setRGBScene(music, for: .music)
check(model.profile == .coding, "Editing another palette must not switch active profile")
check(model.rgbScene(for: .coding) == originalCoding && model.rgbScene(for: .calls) == originalCalls,
      "Editing Music cannot mutate other palettes")
check(model.rgbScene(for: .music).leds[0].enabled && !model.rgbScene(for: .music).leds[1].enabled,
      "Individual LEDs retain independent enabled states")
check(model.rgbScene(for: .music).leds[2].brightness == 12, "Individual brightness is retained")
model.rgbFollowsProfile = false
model.setRGBScene(.off, for: nil)
model.profile = .music
check(model.rgbScene(for: nil) == .off && model.rgbScene(for: .music) == music,
      "Global palette is separate from profile palettes")
model.resetRGBScene(for: .music)
check(model.rgbScene(for: .music) == .defaults(for: .music), "Reset affects the chosen profile")
check(model.rgbScene(for: nil) == .off, "Reset profile cannot reset global palette")
model.cancelRGBHardwareTest()
check(!model.customLightingVerified, "Turning off during validation revokes confirmation")
model.shutdown()

let anotherPreview = AppModel(preview: .custom)
anotherPreview.start()
check(anotherPreview.rgbScene(for: .music) == .defaults(for: .music), "Preview edits must not persist between sessions")
check(anotherPreview.lightingMode(for: .music) == .off, "Preview stock effects must not persist")
anotherPreview.setLoginEnabled(true)
check(!anotherPreview.loginEnabled, "Preview cannot register a login item")
anotherPreview.requestPermissions()
anotherPreview.reconnect()
anotherPreview.shutdown()
let after = UserDefaults.standard.persistentDomain(forName: "local.pranay.keypadcompanion") ?? [:]
check(NSDictionary(dictionary: realSettings).isEqual(to: after), "Real app settings must remain unchanged")
print("Passed \(checks) offline app-model checks; production preferences unchanged.")
