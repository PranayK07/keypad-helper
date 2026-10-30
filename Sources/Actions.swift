import AppKit
import ApplicationServices

final class ActionExecutor {
    let queue = DispatchQueue(label: "local.keypad-companion.actions")
    var report: ((String) -> Void)?
    private var dictationHeld = false
    private var spotifyRestoreVolume = 50
    private var generation = 0
    private let lock = NSLock()
    let codexBundleID = "com.openai.codex"

    func cancelPending() {
        lock.lock(); generation += 1; lock.unlock()
        releaseHeld()
    }
    private func token() -> Int { lock.lock(); defer { lock.unlock() }; return generation }
    func releaseHeld() {
        if dictationHeld { key(2, flags: [.maskControl, .maskShift], down: false); dictationHeld = false }
    }
    private func key(_ code: CGKeyCode, flags: CGEventFlags, down: Bool) {
        let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: code, keyDown: down)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
    }
    private func tap(_ code: CGKeyCode, flags: CGEventFlags = []) {
        key(code, flags: flags, down: true)
        key(code, flags: flags, down: false)
    }
    func perform(_ action: KeyAction, target: CallTarget, step: Int) {
        if action == .none { return }
        if action.needsAccessibility && !AXIsProcessTrusted() { report?("Enable Accessibility to use this control"); return }
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        switch action {
        case .dictation, .send, .stop, .lowerReasoning, .clearPrompt, .higherReasoning:
            guard front == codexBundleID else { report?("Bring Codex forward to use Coding controls"); return }
            switch action {
            case .dictation:
                guard !dictationHeld else { return }
                key(2, flags: [.maskControl, .maskShift], down: true); dictationHeld = true
            case .send: tap(36)
            case .stop: tap(53)
            case .lowerReasoning: tap(29, flags: [.maskControl, .maskShift])
            case .clearPrompt: tap(18, flags: [.maskControl, .maskShift])
            case .higherReasoning: tap(19, flags: [.maskControl, .maskShift])
            default: break
            }
            report?(action.title)
        case .callMic, .callSecondary:
            guard front == target.bundleID else { report?("Bring \(target.title) forward to use call controls"); return }
            let code: CGKeyCode
            if action == .callMic { code = target == .zoom ? 0 : 46 }
            else { code = target == .zoom ? 9 : (target == .teams ? 31 : 2) }
            tap(code, flags: [.maskCommand, .maskShift])
            report?("Sent \(action == .callMic ? "microphone toggle" : (target == .discord ? "deafen toggle" : "camera toggle")) to \(target.title)")
        case .showCallApp:
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) else { report?("\(target.title) is not installed"); return }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
                DispatchQueue.main.async { self?.report?(error.map { $0.localizedDescription } ?? "Opened \(target.title)") }
            }
        default:
            let current = token()
            queue.async { [weak self] in
                guard let self, self.token() == current else { return }
                let script: String
                switch action {
                case .previousTrack, .playPause, .nextTrack:
                    let command = action == .previousTrack ? "previous track" : (action == .nextTrack ? "next track" : "playpause")
                    script = "if application id \"com.spotify.client\" is not running then error \"Open Spotify first\"\ntell application id \"com.spotify.client\" to \(command)"
                case .spotifyDown, .spotifyUp, .spotifyMute:
                    guard let volume = self.runScript("if application id \"com.spotify.client\" is not running then error \"Open Spotify first\"\ntell application id \"com.spotify.client\" to get sound volume") else { return }
                    guard let old = Int(volume.trimmingCharacters(in: .whitespacesAndNewlines)) else { self.say("Could not read Spotify volume"); return }
                    let new: Int
                    if action == .spotifyMute {
                        if old > 0 { self.spotifyRestoreVolume = old; new = 0 } else { new = self.spotifyRestoreVolume }
                    } else { new = boundedVolume(old, delta: action == .spotifyDown ? -step : step) }
                    guard self.token() == current else { return }
                    script = "tell application id \"com.spotify.client\" to set sound volume to \(new)"
                case .systemDown, .systemUp:
                    let delta = action == .systemDown ? -step : step
                    script = "set v to output volume of (get volume settings)\nset v to v + (\(delta))\nif v < 0 then set v to 0\nif v > 100 then set v to 100\nset volume output volume v"
                case .systemMute:
                    script = "set muted to output muted of (get volume settings)\nset volume output muted (not muted)"
                default: return
                }
                guard self.token() == current else { return }
                if self.runScript(script) != nil { self.say(action.title) }
            }
        }
    }
    private func say(_ message: String) { DispatchQueue.main.async { [weak self] in self?.report?(message) } }
    private func runScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: "with timeout of 5 seconds\n\(source)\nend timeout")?.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            say(number == -1743 ? "Allow Spotify control in System Settings → Privacy & Security → Automation" : (error[NSAppleScript.errorMessage] as? String ?? "Action failed"))
            return nil
        }
        guard let result else { say("Could not create automation command"); return nil }
        return result.stringValue ?? ""
    }
}
