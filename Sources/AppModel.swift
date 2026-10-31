import AppKit
import SwiftUI
import ServiceManagement
import ApplicationServices

final class AppModel: ObservableObject {
    @Published var profile: Profile { didSet { executor.cancelPending(); persist(profile.rawValue, forKey: "profile"); applyLighting(); onChange?() } }
    @Published var paused: Bool { didSet { executor.cancelPending(); persist(paused, forKey: "paused"); onChange?() } }
    @Published var deviceStatus = "Checking keypad permissions"
    @Published var lastAction = "Ready when you are"
    @Published var lastInput = "Press a keypad control to identify it"
    @Published var accessibilityReady = false
    @Published var inputReady = false
    @Published var callsTarget: CallTarget { didSet { executor.cancelPending(); persist(callsTarget.rawValue, forKey: "callsTarget") } }
    @Published var volumeStep: Double { didSet { persist(volumeStep, forKey: "volumeStep") } }
    @Published var loginEnabled = false
    @Published var loginStatus = "Checking login item"
    @Published var lightingFollowsProfile: Bool { didSet { persist(lightingFollowsProfile, forKey: "lightingFollowsProfile"); applyLighting() } }
    @Published var lightingMode: LEDMode { didSet { persist(lightingMode.rawValue, forKey: "lightingMode"); applyLighting() } }
    @Published var lightingStatus = "Checking keypad lighting"
    @Published private(set) var customLightingConnection: CustomLightingConnection?
    @Published private(set) var customFirmwarePresent = false
    @Published private(set) var customLightingVerified = false
    @Published private(set) var customLightingTestSent = false
    @Published private(set) var customLightingTestInProgress = false
    @Published var customLightingStatus = "Custom lighting requires compatible firmware"
    @Published var rgbFollowsProfile: Bool { didSet { persist(rgbFollowsProfile, forKey: "rgbFollowsProfile"); applyRGBLighting() } }
    @Published private var rgbScenes: [String: RGBLightingScene]
    @Published private var profileLighting: [Profile: LEDMode]
    @Published private var mappings: [Profile: [KeyAction]]
    var onChange: (() -> Void)?
    var onProfileSelected: (() -> Void)?
    var showSettings: (() -> Void)?
    private let defaults: UserDefaults
    let lightingPreview: LightingPreview?
    var isLightingPreview: Bool { lightingPreview != nil }
    private let input = KeypadInput()
    private let executor = ActionExecutor()
    private let lighting = KeypadLighting()
    private let customLighting = CustomLighting()
    private var rgbVerification = RGBHardwareVerification()
    private var held: [ControlKey: KeyAction] = [:]
    private var inputCounts: [String: Int] = [:]
    private var pressTimes: [ControlKey: TimeInterval] = [:]
    private var timer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var captureStarted = false

    init(preview: LightingPreview? = nil) {
        lightingPreview = preview
        // Preview never persists preferences or starts any hardware services.
        let d = preview == nil ? UserDefaults.standard : UserDefaults(suiteName: "local.pranay.keypadcompanion.preview.\(UUID().uuidString)")!
        defaults = d
        profile = Profile(rawValue: d.string(forKey: "profile") ?? "") ?? .coding
        paused = d.bool(forKey: "paused")
        callsTarget = CallTarget(rawValue: d.string(forKey: "callsTarget") ?? "") ?? .autoDetect
        volumeStep = min(20, max(1, d.object(forKey: "volumeStep") as? Double ?? 5))
        mappings = ProfileMappings.load(d.dictionary(forKey: "mappings") as? [String: [String]] ?? [:])
        lightingFollowsProfile = d.bool(forKey: "lightingFollowsProfile")
        lightingMode = LEDMode(rawValue: d.integer(forKey: "lightingMode")) ?? .off
        profileLighting = LightingPreferences.load(d.dictionary(forKey: "profileLighting") as? [String: Int] ?? [:])
        rgbFollowsProfile = d.object(forKey: "rgbFollowsProfile") as? Bool ?? true
        rgbScenes = [:]
        for selected in [Profile?.none] + Profile.allCases.map({ Optional($0) }) {
            let key = selected?.rawValue ?? "global"
            rgbScenes[key] = RGBLightingScene.load(d.data(forKey: "rgbScene.\(key)"), fallback: .defaults(for: selected))
        }
        lighting.onStatus = { [weak self] in self?.lightingStatus = $0 }
        customLighting.onPresence = { [weak self] in self?.customFirmwarePresent = $0 }
        customLighting.onConnection = { [weak self] in self?.customConnectionChanged($0) }
        customLighting.onStatus = { [weak self] in self?.customLightingStatus = $0 }
        customLighting.onApplied = { [weak self] scene in
            guard let self else { return }
            self.rgbVerification.received(scene)
            self.refreshRGBVerification()
        }
        customLighting.onFailure = { [weak self] in
            guard let self, self.customLightingTestInProgress else { return }
            self.rgbVerification.reset()
            self.refreshRGBVerification()
        }
        input.onStatus = { [weak self] in self?.deviceStatus = $0 }
        input.onUnknown = { [weak self] in self?.lastInput = "Unmapped key (HID \($0)) — check keypad bindings" }
        input.onControl = { [weak self] control, down in self?.receive(control, down: down) }
        input.onDisconnect = { [weak self] in self?.executor.cancelPending(); self?.held.removeAll() }
        executor.report = { [weak self] in self?.lastAction = $0 }
        if preview == nil {
            workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.executor.releaseHeld()
                self?.objectWillChange.send()
            }
        }
    }
    private func persist(_ value: Any?, forKey key: String) {
        guard !isLightingPreview else { return }
        defaults.set(value, forKey: key)
    }
    var resolvedCallTarget: CallTarget { CallTarget.resolve(callsTarget, foreground: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) }
    func selectProfile(_ profile: Profile) { self.profile = profile; lastAction = "\(profile.title) profile selected"; onProfileSelected?() }
    func cycleProfile() {
        let choices = Profile.allCases
        let index = choices.firstIndex(of: profile) ?? 0
        selectProfile(choices[(index + 1) % choices.count])
    }
    func lightingMode(for profile: Profile) -> LEDMode { profileLighting[profile] ?? .off }
    func setLightingMode(_ mode: LEDMode, for profile: Profile) {
        profileLighting[profile] = mode
        persist(Dictionary(uniqueKeysWithValues: profileLighting.map { ($0.key.rawValue, $0.value.rawValue) }), forKey: "profileLighting")
        applyLighting()
    }
    private var activeLightingMode: LEDMode {
        LightingPreferences.resolved(followsProfile: lightingFollowsProfile, global: lightingMode,
                                     profiles: profileLighting, active: profile)
    }
    private func applyLighting() {
        if !isLightingPreview { lighting.apply(mode: activeLightingMode) }
        applyRGBLighting()
    }
    func reapplyLighting() {
        guard !isLightingPreview else { lightingStatus = "Preview only · no keypad commands sent"; return }
        lighting.apply(mode: activeLightingMode, force: true)
    }
    func rgbScene(for profile: Profile?) -> RGBLightingScene {
        rgbScenes[profile?.rawValue ?? "global"] ?? .defaults(for: profile)
    }
    func setRGBScene(_ scene: RGBLightingScene, for profile: Profile?) {
        let key = profile?.rawValue ?? "global"
        rgbScenes[key] = scene.normalized
        if let data = try? JSONEncoder().encode(scene.normalized) { persist(data, forKey: "rgbScene.\(key)") }
        applyRGBLighting()
    }
    func resetRGBScene(for profile: Profile?) { setRGBScene(.defaults(for: profile), for: profile) }
    func reapplyRGBLighting() { applyRGBLighting(force: true) }
    private func applyRGBLighting(force: Bool = false) {
        guard let connection = customLightingConnection, rgbVerification.stage == .verified else { return }
        guard !isLightingPreview else { customLightingStatus = "Preview only · no keypad commands sent"; return }
        customLighting.apply(scene: rgbScene(for: rgbFollowsProfile ? profile : nil), expectedConnectionIdentity: connection.identity, force: force)
    }
    private func customConnectionChanged(_ connection: CustomLightingConnection?) {
        guard connection != customLightingConnection else { return }
        customLightingConnection = connection
        rgbVerification.connect(connection?.identity)
        refreshRGBVerification()
        // The transport revokes its desired scene before notifying us. Repeating
        // that cancellation here would invalidate the accompanying error status.
        customLightingStatus = connection == nil ? "Custom firmware is not connected" : "Verify the physical LEDs before enabling profile colors"
    }
    private func refreshRGBVerification() {
        customLightingVerified = rgbVerification.stage == .verified
        customLightingTestSent = rgbVerification.stage == .awaitingConfirmation
        customLightingTestInProgress = rgbVerification.stage == .testing
    }
    func beginRGBHardwareTest() {
        guard let connection = customLightingConnection, rgbVerification.beginTest() else { return }
        refreshRGBVerification()
        customLightingStatus = "Sending steady amber to all three lights…"
        if isLightingPreview {
            rgbVerification.received(.hardwareTest)
            refreshRGBVerification()
            customLightingStatus = "Simulated test · the physical keypad has not changed"
        } else { customLighting.apply(scene: .hardwareTest, expectedConnectionIdentity: connection.identity, force: true) }
    }
    func confirmRGBHardwareTest() {
        guard rgbVerification.confirm() else { return }
        refreshRGBVerification()
        applyRGBLighting(force: true)
    }
    func cancelRGBHardwareTest() {
        guard let connection = customLightingConnection else { return }
        rgbVerification.reset()
        refreshRGBVerification()
        if isLightingPreview { customLightingStatus = "Preview only · no keypad commands sent" }
        else { customLighting.apply(scene: .off, expectedConnectionIdentity: connection.identity, force: true) }
    }
    func action(for control: ControlKey) -> KeyAction { action(for: control, in: profile) }
    func action(for control: ControlKey, in profile: Profile) -> KeyAction { mappings[profile]![control.rawValue] }
    func actionTitle(for control: ControlKey) -> String {
        actionTitle(for: control, in: profile)
    }
    func actionTitle(for control: ControlKey, in profile: Profile) -> String {
        switch action(for: control, in: profile) {
        case .callSecondary: return resolvedCallTarget == .discord ? "Toggle deafen" : "Toggle camera"
        case .showCallApp: return "Show \(resolvedCallTarget.title)"
        default: return action(for: control, in: profile).title
        }
    }
    func setAction(_ action: KeyAction, for control: ControlKey) {
        setAction(action, for: control, in: profile)
    }
    func setAction(_ action: KeyAction, for control: ControlKey, in profile: Profile) {
        if profile == self.profile { executor.cancelPending() }
        mappings[profile]![control.rawValue] = action
        saveMappings()
    }
    func resetMappings(for profile: Profile) {
        if profile == self.profile { executor.cancelPending() }
        mappings[profile] = ProfileMappings.defaults[profile]
        saveMappings()
    }
    private func saveMappings() {
        persist(Dictionary(uniqueKeysWithValues: mappings.map { ($0.key.rawValue, $0.value.map(\.rawValue)) }), forKey: "mappings")
    }
    func start() {
        if let lightingPreview {
            accessibilityReady = true
            inputReady = true
            paused = true
            deviceStatus = "Preview only · hardware disconnected"
            lightingStatus = "Preview only · your current keypad setup is unchanged"
            loginStatus = "Preview does not change startup settings"
            if lightingPreview != .stock {
                customFirmwarePresent = true
                if lightingPreview == .unavailable {
                    customLightingStatus = "Preview only · this firmware’s lighting protocol is not supported"
                    return
                }
                customConnectionChanged(CustomLightingConnection(identity: "offline-preview", firmwareVersion: 1))
                if lightingPreview == .custom {
                    _ = rgbVerification.beginTest()
                    rgbVerification.received(.hardwareTest)
                    _ = rgbVerification.confirm()
                    refreshRGBVerification()
                }
                customLightingStatus = "Preview only · hardware has not been verified"
            }
            return
        }
        customLighting.start()
        lighting.start()
        applyLighting()
        refreshPermissions()
        refreshLogin()
        // The user requested launch on every login. Attempt once; respect later OS opt-out.
        if !defaults.bool(forKey: "loginSetupAttempted") {
            persist(true, forKey: "loginSetupAttempted")
            setLoginEnabled(true)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshPermissions(); self?.refreshLogin() }
    }
    private func receive(_ control: ControlKey, down: Bool) {
        lastInput = "\(control.title) · \(down ? "pressed" : "released")"
        if down {
            inputCounts[control.title, default: 0] += 1
            pressTimes[control] = ProcessInfo.processInfo.systemUptime
        } else if let started = pressTimes.removeValue(forKey: control) {
            lastInput += String(format: " (%.2fs)", ProcessInfo.processInfo.systemUptime - started)
        }
        if !down {
            if held.removeValue(forKey: control) == .dictation && !held.values.contains(.dictation) { executor.releaseHeld() }
            return
        }
        guard !paused else { lastAction = "Controls paused"; return }
        guard held[control] == nil else { return }
        let selected = action(for: control)
        held[control] = selected
        executor.perform(selected, target: resolvedCallTarget, step: min(20, max(1, Int(volumeStep))))
    }
    func refreshPermissions() {
        guard !isLightingPreview else { return }
        accessibilityReady = AXIsProcessTrusted()
        inputReady = CGPreflightListenEventAccess()
        if accessibilityReady && inputReady {
            if !captureStarted { captureStarted = true; input.start() }
        } else {
            if captureStarted { input.stop(); captureStarted = false }
            deviceStatus = "Setup needed · allow Accessibility and Input Monitoring"
        }
    }
    func requestPermissions() {
        guard !isLightingPreview else { return }
        if !AXIsProcessTrusted() { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) }
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        refreshPermissions()
    }
    func reconnect() { guard !isLightingPreview else { return }; executor.cancelPending(); input.stop(); captureStarted = false; refreshPermissions() }
    func openAccessibilitySettings() {
        guard !isLightingPreview else { return }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func openInputSettings() {
        guard !isLightingPreview else { return }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
    func setLoginEnabled(_ enabled: Bool) {
        guard !isLightingPreview else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                else if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else { try SMAppService.mainApp.unregister() }
            refreshLogin()
        } catch { loginStatus = "Login setup failed: \(error.localizedDescription)"; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
    private func refreshLogin() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        switch SMAppService.mainApp.status {
        case .enabled: loginStatus = "Starts automatically when you sign in"
        case .requiresApproval: loginStatus = "Allow Keypad Companion in System Settings → Login Items"
        case .notFound: loginStatus = "Login item unavailable — keep the app in Applications"
        default: loginStatus = "Launch at login is off"
        }
    }
    func openSettings() { showSettings?() }
    func quit() { shutdown(); NSApplication.shared.terminate(nil) }
    func shutdown() {
        guard !isLightingPreview else { return }
        timer?.invalidate(); executor.cancelPending(); input.stop(); lighting.stop(); customLighting.stop()
    }
    func diagnosticSnapshot() -> [String: Any] {
        ["profile": profile.rawValue, "paused": paused, "inputPermission": inputReady, "accessibilityPermission": accessibilityReady, "device": deviceStatus, "loginEnabled": loginEnabled, "loginStatus": loginStatus, "lastInput": lastInput, "lastAction": lastAction, "callsTarget": callsTarget.rawValue, "inputCounts": inputCounts, "lightingMode": activeLightingMode.rawValue, "lightingFollowsProfile": lightingFollowsProfile, "lightingStatus": lightingStatus]
    }
}
