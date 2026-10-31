import Foundation

// Pure domain checks: no application launch, keyboard injection, or preference writes.
// Modifier filtering and event suppression belong to the event-tap layer.
// Trigger keycodes alone cannot distinguish keypad events from other keyboards.
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String,
           file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition() { fatalError(message, file: file, line: line) }
}

let expectedUsages: [UInt32: ControlKey] = [
    7: .key1, 40: .key2, 41: .key3,
    98: .ccw, 89: .press, 90: .cw
]
for (usage, control) in expectedUsages {
    check(ControlKey.fromHIDUsage(usage) == control, "Wrong keypad control for usage \(usage)")
}
for usage in UInt32(0)...UInt32(255) where expectedUsages[usage] == nil {
    check(ControlKey.fromHIDUsage(usage) == nil, "Unexpected routing for usage \(usage)")
}
for usage in UInt32(224)...UInt32(231) {
    check(ControlKey.fromHIDUsage(usage) == nil, "Modifier must not trigger an action: \(usage)")
}
check(ControlKey.fromHIDUsage(UInt32.max) == nil, "Out-of-range usage must be ignored")
check(Set(expectedUsages.values.map(\.rawValue)).count == 6, "Every control must be independently addressable")

let expectedTriggerCodes: [UInt16: ControlKey] = [
    105: .key1, // F13
    107: .key2, // F14
    113: .key3, // F15
    106: .ccw,  // F16
    64: .press, // F17
    79: .cw     // F18
]
for code in UInt16(0)...UInt16(255) {
    check(ControlKey.fromTriggerKeyCode(code) == expectedTriggerCodes[code],
          "Unexpected reserved-trigger routing for CG keycode \(code)")
}
check(ControlKey.fromTriggerKeyCode(UInt16.max) == nil, "Out-of-range trigger keycode must be ignored")
check(Set(expectedTriggerCodes.values.map(\.rawValue)).count == 6,
      "Reserved F13–F18 triggers must independently address all six controls")

let expectedMappings: [Profile: [KeyAction]] = [
    .coding: [.dictation, .send, .stop, .lowerReasoning, .clearPrompt, .higherReasoning],
    .music: [.previousTrack, .playPause, .nextTrack, .spotifyDown, .spotifyMute, .spotifyUp],
    .calls: [.callMic, .callSecondary, .showCallApp, .systemDown, .systemMute, .systemUp]
]
for profile in Profile.allCases {
    check(ProfileMappings.defaults[profile] == expectedMappings[profile], "Wrong defaults for \(profile)")
    check(ProfileMappings.defaults[profile]?.count == ControlKey.allCases.count, "Incomplete profile: \(profile)")
}
check(ProfileMappings.load([:]) == expectedMappings, "Missing preferences must use defaults")
check(ProfileMappings.load(["futureProfile": ["none"]]) == expectedMappings, "Unknown profiles must not alter defaults")

for length in [0, 1, 5, 7, 100] {
    let loaded = ProfileMappings.load(["music": Array(repeating: "none", count: length)])
    check(loaded == expectedMappings, "Invalid mapping length \(length) must fall back safely")
}
let customMusic = ["none", "playPause", "nextTrack", "spotifyDown", "spotifyMute", "spotifyUp"]
let customLoaded = ProfileMappings.load(["music": customMusic])
check(customLoaded[.music]?[0] == KeyAction.none, "A deliberate No action mapping must be preserved")
check(customLoaded[.coding] == expectedMappings[.coding], "Music edit must not affect Coding")
check(customLoaded[.calls] == expectedMappings[.calls], "Music edit must not affect Calls")
let partialCorruption = ProfileMappings.load([
    "music": ["none", "removedAction", "nextTrack", "", "spotifyMute", "spotifyUp"]
])
check(partialCorruption[.music] == [.none, .playPause, .nextTrack, .spotifyDown, .spotifyMute, .spotifyUp],
      "Unknown actions must fall back per slot while preserving valid edits")
let roundTrip = ProfileMappings.defaults.reduce(into: [String: [String]]()) { result, entry in
    result[entry.key.rawValue] = entry.value.map(\.rawValue)
}
check(ProfileMappings.load(roundTrip) == expectedMappings, "Saved defaults must round-trip without changing behavior")

for volume in 0...100 {
    check(boundedVolume(volume, delta: 0) == volume, "Zero step must preserve volume")
    check((0...100).contains(boundedVolume(volume, delta: 5)), "Volume up exceeds limits")
    check((0...100).contains(boundedVolume(volume, delta: -5)), "Volume down exceeds limits")
}
check(boundedVolume(98, delta: 5) == 100, "Volume up must clamp at 100")
check(boundedVolume(2, delta: -5) == 0, "Volume down must clamp at zero")
check(boundedVolume(50, delta: 5) == 55, "Normal upward step")
check(boundedVolume(50, delta: -5) == 45, "Normal downward step")
check(boundedVolume(50, delta: 1000) == 100, "Large upward step must clamp")
check(boundedVolume(50, delta: -1000) == 0, "Large downward step must clamp")
check(boundedVolume(-10, delta: 0) == 0, "Invalid negative stored volume must clamp")
check(boundedVolume(110, delta: 0) == 100, "Invalid high stored volume must clamp")

let supportedCalls: [(String, CallTarget)] = [
    ("com.hnc.Discord", .discord), ("us.zoom.xos", .zoom), ("com.microsoft.teams2", .teams)
]
for (bundleID, expected) in supportedCalls {
    check(CallTarget.resolve(.autoDetect, foreground: bundleID) == expected,
          "Automatic call target failed for \(bundleID)")
}
for target in [CallTarget.discord, .zoom, .teams] {
    for foreground in [String?.none, "com.apple.TextEdit", "com.hnc.Discord", "us.zoom.xos", "com.microsoft.teams2"] {
        check(CallTarget.resolve(target, foreground: foreground) == target,
              "Explicit call target must stay selected regardless of foreground")
    }
}
// Discord is a target-selection fallback, not permission to emit shortcuts.
// The action executor must still enforce the configured foreground-app guard.
check(CallTarget.resolve(.autoDetect, foreground: nil) == .discord, "Missing foreground fallback")
check(CallTarget.resolve(.autoDetect, foreground: "com.apple.TextEdit") == .discord, "Unknown foreground fallback")
check(CallTarget.resolve(.autoDetect, foreground: "us.zoom.xos.untrusted") == .discord,
      "Bundle IDs must not be matched by prefix")

// Unknown persisted settings must never become arbitrary device commands.
check(LEDMode.allCases.map(\.rawValue) == [0, 1, 2], "Only verified LED modes may be exposed")
let lightingDefaults = LightingPreferences.load([:])
check(lightingDefaults.values.allSatisfy { $0 == .off } && lightingDefaults.count == 3,
      "New lighting settings should start with lights off")
let damagedLighting = LightingPreferences.load(["coding": -1, "music": 2, "calls": 255, "future": 1])
check(damagedLighting == [.coding: .off, .music: .rainbow, .calls: .off],
      "Corrupt lighting values fall back per profile, preserving supported values")
for coding in LEDMode.allCases {
    for music in LEDMode.allCases {
        for calls in LEDMode.allCases {
            let modes: [Profile: LEDMode] = [.coding: coding, .music: music, .calls: calls]
            let stored = Dictionary(uniqueKeysWithValues: modes.map { ($0.key.rawValue, $0.value.rawValue) })
            check(LightingPreferences.load(stored) == modes, "Profile effects must round-trip")
            for global in LEDMode.allCases {
                for active in Profile.allCases {
                    check(LightingPreferences.resolved(followsProfile: true, global: global,
                          profiles: modes, active: active) == modes[active], "Active profile chooses its effect")
                    check(LightingPreferences.resolved(followsProfile: false, global: global,
                          profiles: modes, active: active) == global, "Global effect ignores profile changes")
                }
            }
        }
    }
}
check(LightingPreferences.resolved(followsProfile: true, global: .rainbow, profiles: [:], active: .calls) == .off,
      "Missing profile effect should be off")
// RGB lighting has a separate, positively identified protocol. These tests never
// open HID/USB devices, run the app, or change user preferences.
let rgbScene = RGBLightingScene(leds: [
    LEDSetting(color: RGBColor(red: 255, green: 0, blue: 127), brightness: 64, enabled: true),
    LEDSetting(color: RGBColor(red: 1, green: 2, blue: 3), brightness: 255, enabled: false),
    LEDSetting(color: RGBColor(red: 10, green: 20, blue: 30), brightness: 0, enabled: true)
])
let rgbPacket = CustomLightingProtocol.encode(scene: rgbScene, sequence: 231)
check(rgbPacket == [75,80,72,76,1,3,1,1,231,0,255,0,127,64,1,2,3,0,10,20,30,0,0,0,0,0,0,0,0,0,0,0],
      "RGB protocol must match the firmware's byte-level contract")
check(CustomLightingProtocol.decode(rgbPacket) == nil, "A SET command cannot masquerade as an acknowledgement")
var rgbReply = rgbPacket
rgbReply[7] = 0
check(CustomLightingProtocol.decode(rgbReply)?.sequence == 231, "Acknowledgement preserves transaction number")
check(CustomLightingProtocol.decode(rgbReply)?.matches(scene: rgbScene) == true, "Readback compares effective LED values")
var changedColor = rgbReply
changedColor[10] = 254
check(CustomLightingProtocol.decode(changedColor)?.matches(scene: rgbScene) == false, "Incorrect hardware readback must be detected")
for index in [0,1,2,3,4,5,6,7,9,22,23,24,25,26,27,28,29,30,31] {
    var malformed = rgbReply
    malformed[index] &+= 1
    check(CustomLightingProtocol.decode(malformed) == nil, "Invalid field at \(index) must reject unsupported firmware/report")
}
for length in 0...65 where length != 32 {
    check(CustomLightingProtocol.decode(Array((rgbReply + rgbReply + rgbReply).prefix(length))) == nil,
          "Reject report length \(length)")
}
for profile in [Profile?.none] + Profile.allCases.map({ Optional($0) }) {
    let scene = RGBLightingScene.defaults(for: profile)
    check(scene.leds.count == 3, "Every profile has exactly three LED settings")
    let data = try! JSONEncoder().encode(scene)
    check(RGBLightingScene.load(data, fallback: .off) == scene, "RGB preference roundtrip")
    check(RGBLightingScene.load(Data("bad data".utf8), fallback: scene) == scene, "Corrupt data uses profile default")
}
check(RGBLightingScene.load(Data("{\"leds\":[]}".utf8), fallback: rgbScene) == rgbScene, "Invalid saved LED count rejects whole scene")
check(RGBLightingScene.load(nil, fallback: rgbScene) == rgbScene, "Absent RGB settings preserve caller fallback")
check(RGBLightingScene(leds: []).wireValues == Array(repeating: 0, count: 12), "Missing lights are safely off")
check(RGBLightingScene(leds: rgbScene.leds + rgbScene.leds).leds.count == 3, "Extra lights cannot extend the packet")
var malformedScene = rgbScene
malformedScene.leds = []
check(CustomLightingProtocol.encode(scene: malformedScene, sequence: 0).count == 32, "Mutation cannot produce malformed packet length")

var verification = RGBHardwareVerification()
check(!verification.confirm() && !verification.beginTest(), "Disconnected hardware cannot be tested or confirmed")
verification.connect("device-a")
check(verification.stage == .needsTest && !verification.confirm(), "Detection alone must not unlock custom controls")
check(verification.beginTest(), "Connected custom device can start the explicit test")
verification.received(.off)
check(verification.stage == .testing && !verification.confirm(), "Unrelated successful write must not count as the test")
verification.received(.hardwareTest)
check(verification.stage == .awaitingConfirmation, "USB delivery must still await the user's physical check")
check(verification.confirm() && verification.stage == .verified, "Physical confirmation unlocks custom lighting")
verification.connect("device-a")
check(verification.stage == .verified, "Polling the same connection must not discard confirmation")
verification.connect("device-b")
check(verification.stage == .needsTest, "A replacement device must be verified independently")
_ = verification.beginTest()
verification.connect(nil)
verification.received(.hardwareTest)
check(verification.stage == .disconnected && !verification.confirm(), "Late readback after unplug must not unlock controls")
verification.connect("device-a")
check(verification.stage == .needsTest, "Reconnect requires a fresh physical check")
_ = verification.beginTest()
verification.received(.hardwareTest)
verification.reset()
check(verification.stage == .needsTest && !verification.confirm(), "Rejected or failed hardware test stays gated")
// Descriptor routing must reject stock, unrelated, and future incompatible
// interfaces before the transport ever opens a report channel or writes bytes.
func matchesRGB(vendor: Int = 0x1189, productID: Int = 0x8890,
                maker: String = "Keypad Helper", product: String = "Keypad Helper RGB",
                page: Int = 0xFF60, usage: Int = 0x61, reportSize: Int = 32) -> Bool {
    CustomFirmwareIdentity.matches(vendorID: vendor, productID: productID,
        manufacturer: maker, product: product, usagePage: page, usage: usage,
        featureReportSize: reportSize)
}
check(matchesRGB(), "Exact custom firmware descriptors are eligible for a read-only handshake")
check(!matchesRGB(vendor: 0x9999), "A different vendor is never an RGB target")
check(!matchesRGB(productID: 0x8842), "A different keypad product is never an RGB target")
check(!matchesRGB(maker: ""), "Missing manufacturer must not be guessed")
check(!matchesRGB(product: "USB Composite Device"), "Stock USB identity must not receive RGB packets")
check(!matchesRGB(product: "Keypad Helper RGB 2"), "Future unrecognized firmware must remain gated")
check(!matchesRGB(page: 0xFF00), "Stock vendor usage page must not receive RGB packets")
check(!matchesRGB(usage: 1), "Wrong vendor usage must not receive RGB packets")
check(!matchesRGB(page: 1, usage: 6), "Typing interface must never be used for RGB reports")
for size in [0, 8, 31, 33, 64] {
    check(!matchesRGB(reportSize: size), "Unexpected feature report size \(size) must be rejected")
}
check(CustomFirmwareIdentity.belongsToCustomFamily(product: "Keypad Helper RGB", manufacturer: ""), "Product marker excludes custom firmware from legacy writes")
check(CustomFirmwareIdentity.belongsToCustomFamily(product: "", manufacturer: "Keypad Helper"), "Manufacturer marker independently excludes legacy writes")
check(CustomFirmwareIdentity.belongsToCustomFamily(product: "Keypad Helper future", manufacturer: ""), "Future custom products must not fall back to legacy writes")
check(!CustomFirmwareIdentity.belongsToCustomFamily(product: "USB Composite Device", manufacturer: "vendor"), "Existing stock device retains legacy controls")
check(CustomLightingAuthorization.permits(expected: "device-a", current: "device-a"), "The same USB connection can receive its authorized scene")
check(!CustomLightingAuthorization.permits(expected: "device-a", current: "device-b"), "A queued action for the old keypad cannot authorize a replacement")
check(!CustomLightingAuthorization.permits(expected: "device-a", current: nil), "Unplugging revokes a queued scene")
check(!CustomLightingAuthorization.permits(expected: "", current: ""), "An empty identity cannot authorize hardware")
check(!CustomLightingAuthorization.permits(expected: "", current: nil), "Missing identities cannot authorize hardware")
print("Passed \(checks) pure domain checks (no app or device side effects).")
