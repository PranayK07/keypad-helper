import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model: AppModel = {
        let requested = CommandLine.arguments.compactMap { argument -> LightingPreview? in
            guard argument.hasPrefix("--lighting-preview=") else { return nil }
            return LightingPreview(rawValue: String(argument.dropFirst("--lighting-preview=".count)))
        }.first
        let previewBuild = Bundle.main.object(forInfoDictionaryKey: "KPHLightingPreview") as? Bool == true
        return AppModel(preview: requested ?? (previewBuild ? .verify : nil))
    }()
    var statusItem: NSStatusItem!
    let popover = NSPopover()
    var preferences: NSWindow?
    var diagnosticTimer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !model.isLightingPreview && NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").count > 1 {
            NSApplication.shared.terminate(nil); return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: CompanionView(model: model))
        model.onChange = { [weak self] in self?.updateStatus() }
        model.onProfileSelected = { [weak self] in self?.popover.performClose(nil) }
        model.showSettings = { [weak self] in self?.openPreferences() }
        configureApplicationMenu()
        if let icon = Bundle.main.path(forResource: "AppIcon", ofType: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOfFile: icon)
        }
        model.start()
        updateStatus()
        if !model.isLightingPreview {
            diagnosticTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.writeDiagnostics() }
        }
        if model.isLightingPreview || !model.accessibilityReady || !model.inputReady || CommandLine.arguments.contains("--settings") { openPreferences() }
    }
    func updateStatus() {
        statusItem.button?.image = PixelArt.menuImage(for: model.profile, paused: model.paused)
        statusItem.button?.title = ""
        statusItem.button?.toolTip = "\(model.profile.title)\(model.paused ? " · Paused" : "") — click to choose a profile; right-click to switch to the next"
        statusItem.button?.setAccessibilityLabel("Keypad Companion: \(model.profile.title)\(model.paused ? ", paused" : "")")
    }
    @objc func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            model.cycleProfile()
            return
        }
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }
    @objc func openPreferences() {
        popover.performClose(nil)
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 600), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = model.isLightingPreview ? "Keypad Companion · Offline lighting preview" : "Keypad Companion"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(red: 0.17, green: 0.11, blue: 0.08, alpha: 1)
            window.appearance = NSAppearance(named: .darkAqua)
            window.delegate = self
            window.contentViewController = NSHostingController(rootView: PreferencesView(model: model))
            window.isReleasedWhenClosed = false
            window.center()
            preferences = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        preferences?.deminiaturize(nil)
        preferences?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === preferences else { return }
        // Keep the menu-bar companion running while removing its Dock tile.
        NSApp.setActivationPolicy(.accessory)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    private func configureApplicationMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Keypad Companion")
        let settings = NSMenuItem(title: "Settings…", action: #selector(openPreferences), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Keypad Companion", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit Keypad Companion", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
    func writeDiagnostics() {
        guard !model.isLightingPreview else { return }
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let directory = base.appendingPathComponent("KeypadCompanion", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONSerialization.data(withJSONObject: model.diagnosticSnapshot(), options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: directory.appendingPathComponent("status.json"), options: .atomic)
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openPreferences(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown(); diagnosticTimer?.invalidate() }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
