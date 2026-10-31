import Foundation

enum Profile: String, CaseIterable, Identifiable {
    case coding, music, calls
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

// Only the three effects supported by the 1189:8890 firmware are exposed.
enum LEDMode: Int, CaseIterable, Identifiable {
    case off = 0, reactive = 1, rainbow = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .off: return "Lights off"
        case .reactive: return "Key glow"
        case .rainbow: return "Rainbow cycle"
        }
    }
    var detail: String {
        switch self {
        case .off: return "Keep the keypad dark, including when you press a key."
        case .reactive: return "The keypad’s single-key effect changes colors as you use it."
        case .rainbow: return "Colors move across all three keys. They do not stay steady."
        }
    }
}

struct LightingPreferences {
    static func load(_ stored: [String: Int]) -> [Profile: LEDMode] {
        Dictionary(uniqueKeysWithValues: Profile.allCases.map {
            ($0, LEDMode(rawValue: stored[$0.rawValue] ?? 0) ?? .off)
        })
    }
    static func resolved(followsProfile: Bool, global: LEDMode,
                         profiles: [Profile: LEDMode], active: Profile) -> LEDMode {
        followsProfile ? (profiles[active] ?? .off) : global
    }
}

// Custom RGB preferences are separate from the stock firmware's saved effects.
struct RGBColor: Codable, Equatable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
}

struct LEDSetting: Codable, Equatable {
    var color: RGBColor
    var brightness: UInt8
    var enabled: Bool
    static let off = LEDSetting(color: RGBColor(red: 0, green: 0, blue: 0), brightness: 0, enabled: false)
}

struct RGBLightingScene: Codable, Equatable {
    var leds: [LEDSetting]
    init(leds: [LEDSetting]) { self.leds = Array((leds + Array(repeating: .off, count: 3)).prefix(3)) }
    var normalized: RGBLightingScene { RGBLightingScene(leds: leds) }
    var wireValues: [UInt8] {
        normalized.leds.flatMap { [$0.color.red, $0.color.green, $0.color.blue, $0.enabled ? $0.brightness : 0] }
    }
    static let off = RGBLightingScene(leds: [])
    static let hardwareTest = RGBLightingScene(leds: Array(repeating:
        LEDSetting(color: RGBColor(red: 255, green: 170, blue: 80), brightness: 64, enabled: true), count: 3))
    static func defaults(for profile: Profile?) -> RGBLightingScene {
        let color: RGBColor
        switch profile {
        case .coding: color = RGBColor(red: 85, green: 140, blue: 255)
        case .music: color = RGBColor(red: 90, green: 205, blue: 135)
        case .calls: color = RGBColor(red: 225, green: 100, blue: 215)
        case nil: color = RGBColor(red: 255, green: 170, blue: 80)
        }
        return RGBLightingScene(leds: Array(repeating: LEDSetting(color: color, brightness: 96, enabled: true), count: 3))
    }
    static func load(_ data: Data?, fallback: RGBLightingScene) -> RGBLightingScene {
        guard let data, let scene = try? JSONDecoder().decode(Self.self, from: data), scene.leds.count == 3 else { return fallback }
        return scene
    }
}

struct CustomLightingConnection: Equatable {
    let identity: String
    let firmwareVersion: Int
}

struct CustomLightingReply {
    let sequence: UInt8
    let scene: RGBLightingScene
    func matches(scene: RGBLightingScene) -> Bool { self.scene.wireValues == scene.wireValues }
}

// Feature report ID 0, 32 bytes. GET is read-only; SET only changes RAM lighting.
// A positive descriptor match and a valid GET reply are required before any SET.
enum CustomLightingProtocol {
    static let magic: [UInt8] = [0x4b, 0x50, 0x48, 0x4c] // KPHL
    static let version: UInt8 = 1
    static func encode(scene: RGBLightingScene, sequence: UInt8) -> [UInt8] {
        magic + [version, 3, 1, 1, sequence, 0] + scene.wireValues + Array(repeating: 0, count: 10)
    }
    static func decode(_ bytes: [UInt8]) -> CustomLightingReply? {
        guard bytes.count == 32, Array(bytes.prefix(4)) == magic,
              bytes[4] == version, bytes[5] == 3, bytes[6] == 1,
              bytes[7] == 0, bytes[9] == 0, bytes[22...31].allSatisfy({ $0 == 0 }) else { return nil }
        let leds = (0..<3).map { index -> LEDSetting in
            let offset = 10 + index * 4
            return LEDSetting(color: RGBColor(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2]),
                              brightness: bytes[offset + 3], enabled: bytes[offset + 3] > 0)
        }
        return CustomLightingReply(sequence: bytes[8], scene: RGBLightingScene(leds: leds))
    }
}

// Hardware confirmation is intentionally session-only and tied to the current
// connection. Read-back proves delivery, never that the physical LEDs work.
struct RGBHardwareVerification {
    enum Stage: Equatable { case disconnected, needsTest, testing, awaitingConfirmation, verified }
    private(set) var identity: String?
    private(set) var stage: Stage = .disconnected
    mutating func connect(_ identity: String?) {
        guard identity != self.identity else { return }
        self.identity = identity
        stage = identity == nil ? .disconnected : .needsTest
    }
    mutating func beginTest() -> Bool {
        guard identity != nil else { return false }
        stage = .testing
        return true
    }
    mutating func received(_ scene: RGBLightingScene) {
        if stage == .testing && scene.wireValues == RGBLightingScene.hardwareTest.wireValues { stage = .awaitingConfirmation }
    }
    mutating func confirm() -> Bool {
        guard stage == .awaitingConfirmation else { return false }
        stage = .verified
        return true
    }
    mutating func reset() { stage = identity == nil ? .disconnected : .needsTest }
}

enum LightingPreview: String { case stock, verify, custom, unavailable }

enum ControlKey: Int, CaseIterable, Identifiable {
    case key1 = 0, key2, key3, ccw, press, cw
    var id: Int { rawValue }
    var title: String { ["Key 1", "Key 2", "Key 3", "Turn left", "Press dial", "Turn right"][rawValue] }
    static func fromTriggerKeyCode(_ code: UInt16) -> ControlKey? {
        switch code {
        case 105: return .key1
        case 107: return .key2
        case 113: return .key3
        case 106: return .ccw
        case 64: return .press
        case 79: return .cw
        default: return nil
        }
    }
    static func fromHIDUsage(_ usage: UInt32) -> ControlKey? {
        switch usage {
        case 7: return .key1 // D in the existing Ctrl+Shift+D mapping
        case 40: return .key2
        case 41: return .key3
        case 98: return .ccw // keypad 0
        case 89: return .press // keypad 1
        case 90: return .cw // keypad 2
        default: return nil
        }
    }
}
enum KeyAction: String, CaseIterable, Identifiable {
    case none, dictation, send, stop, lowerReasoning, clearPrompt, higherReasoning
    case previousTrack, playPause, nextTrack, spotifyDown, spotifyMute, spotifyUp
    case callMic, callSecondary, showCallApp, systemDown, systemMute, systemUp
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "No action"
        case .dictation: return "Hold to dictate"
        case .send: return "Send prompt"
        case .stop: return "Stop response"
        case .lowerReasoning: return "Lower reasoning"
        case .clearPrompt: return "Clear prompt"
        case .higherReasoning: return "Higher reasoning"
        case .previousTrack: return "Previous track"
        case .playPause: return "Play / pause"
        case .nextTrack: return "Next track"
        case .spotifyDown: return "Spotify volume −"
        case .spotifyMute: return "Mute / restore Spotify"
        case .spotifyUp: return "Spotify volume +"
        case .callMic: return "Toggle microphone"
        case .callSecondary: return "Toggle deafen / camera"
        case .showCallApp: return "Show call app"
        case .systemDown: return "Output volume −"
        case .systemMute: return "Mute / unmute output"
        case .systemUp: return "Output volume +"
        }
    }
    var needsAccessibility: Bool {
        switch self {
        case .dictation, .send, .stop, .lowerReasoning, .clearPrompt, .higherReasoning, .callMic, .callSecondary: return true
        default: return false
        }
    }
}
enum CallTarget: String, CaseIterable, Identifiable {
    case autoDetect, discord, zoom, teams
    var id: String { rawValue }
    var title: String {
        switch self { case .autoDetect: return "Automatic (foreground app)"; case .discord: return "Discord"; case .zoom: return "Zoom"; case .teams: return "Microsoft Teams" }
    }
    var bundleID: String {
        switch self { case .autoDetect, .discord: return "com.hnc.Discord"; case .zoom: return "us.zoom.xos"; case .teams: return "com.microsoft.teams2" }
    }
    static func resolve(_ selected: CallTarget, foreground: String?) -> CallTarget {
        guard selected == .autoDetect else { return selected }
        return [.discord, .zoom, .teams].first { $0.bundleID == foreground } ?? .discord
    }
}
struct ProfileMappings {
    static let defaults: [Profile: [KeyAction]] = [
        .coding: [.dictation, .send, .stop, .lowerReasoning, .clearPrompt, .higherReasoning],
        .music: [.previousTrack, .playPause, .nextTrack, .spotifyDown, .spotifyMute, .spotifyUp],
        .calls: [.callMic, .callSecondary, .showCallApp, .systemDown, .systemMute, .systemUp]
    ]
    static func load(_ stored: [String: [String]]) -> [Profile: [KeyAction]] {
        var result = defaults
        for profile in Profile.allCases {
            guard let values = stored[profile.rawValue], values.count == 6 else { continue }
            result[profile] = values.enumerated().map { KeyAction(rawValue: $0.element) ?? defaults[profile]![$0.offset] }
        }
        return result
    }
}
func boundedVolume(_ current: Int, delta: Int) -> Int { min(100, max(0, current + delta)) }

// Descriptor identity is separate from the read-only protocol handshake. Both
// must match before an RGB write; matching the shared USB ID alone is unsafe.
enum CustomFirmwareIdentity {
    static let vendorID = 0x1189
    static let productID = 0x8890
    static let manufacturer = "Keypad Helper"
    static let product = "Keypad Helper RGB"
    static let usagePage = 0xFF60
    static let usage = 0x61

    static func belongsToCustomFamily(product: String, manufacturer: String) -> Bool {
        product.hasPrefix("Keypad Helper") || manufacturer == Self.manufacturer
    }

    static func matches(vendorID: Int, productID: Int, manufacturer: String,
                        product: String, usagePage: Int, usage: Int,
                        featureReportSize: Int) -> Bool {
        vendorID == Self.vendorID && productID == Self.productID &&
            manufacturer == Self.manufacturer && product == Self.product &&
            usagePage == Self.usagePage && usage == Self.usage && featureReportSize == 32
    }
}

enum CustomLightingAuthorization {
    static func permits(expected: String, current: String?) -> Bool {
        !expected.isEmpty && current == expected
    }
}
