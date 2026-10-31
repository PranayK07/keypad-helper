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
