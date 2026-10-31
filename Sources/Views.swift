import AppKit
import SwiftUI

private enum CoffeeTheme {
    static let espresso = Color(red: 0.16, green: 0.105, blue: 0.08)
    static let cocoa = Color(red: 0.205, green: 0.145, blue: 0.11)
    static let roast = Color(red: 0.26, green: 0.185, blue: 0.14)
    static let raised = Color(red: 0.31, green: 0.225, blue: 0.17)
    static let cream = Color(red: 0.96, green: 0.89, blue: 0.78)
    static let muted = Color(red: 0.76, green: 0.65, blue: 0.53)
    static let latte = Color(red: 0.87, green: 0.70, blue: 0.49)
    static let line = Color(red: 0.50, green: 0.36, blue: 0.26).opacity(0.36)
    static let sage = Color(red: 0.70, green: 0.77, blue: 0.57)
}

private extension Profile {
    var pixelIcon: PixelIcon.Kind {
        switch self { case .coding: return .coffee; case .music: return .headphones; case .calls: return .microphone }
    }
    var accent: Color {
        switch self {
        case .coding: return CoffeeTheme.latte
        case .music: return CoffeeTheme.sage
        case .calls: return Color(red: 0.80, green: 0.68, blue: 0.77)
        }
    }
    var summary: String {
        switch self {
        case .coding: return "Dictation & reasoning"
        case .music: return "Spotify playback"
        case .calls: return "Microphone & call controls"
        }
    }
}

private struct CoffeeButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(prominent ? CoffeeTheme.espresso : CoffeeTheme.cream)
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(prominent ? CoffeeTheme.latte : CoffeeTheme.raised,
                        in: RoundedRectangle(cornerRadius: 9))
            .opacity(configuration.isPressed ? 0.72 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

private struct PixelLightIcon: View {
    let color: Color
    private let rows = ["0011100", "0100010", "1000001", "1000001", "0100010", "0010100", "0011100", "0011100", "0001000"]
    var body: some View {
        Canvas { context, size in
            let unit = floor(min(size.width / 7, size.height / 9))
            let origin = CGPoint(x: (size.width - unit * 7) / 2, y: (size.height - unit * 9) / 2)
            for (y, row) in rows.enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "1" {
                    context.fill(Path(CGRect(x: origin.x + CGFloat(x) * unit, y: origin.y + CGFloat(y) * unit,
                                             width: unit, height: unit)), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct CompanionView: View {
    @ObservedObject var model: AppModel
    @State private var hovered: Profile?
    @State private var settingsHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Choose a profile").font(.system(size: 12, weight: .semibold))
                Spacer()
                if model.paused {
                    Text("Paused").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(CoffeeTheme.muted)
                }
            }
            .padding(.horizontal, 11).padding(.top, 6).padding(.bottom, 12)

            VStack(spacing: 5) {
                ForEach(Profile.allCases) { profile in
                    let selected = model.profile == profile
                    Button { model.selectProfile(profile) } label: {
                        HStack(spacing: 13) {
                            PixelIcon(kind: profile.pixelIcon, color: selected ? CoffeeTheme.espresso : profile.accent)
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.title).font(.system(size: 14, weight: .semibold))
                                Text(profile.summary).font(.system(size: 10))
                                    .foregroundStyle(selected ? CoffeeTheme.espresso.opacity(0.75) : CoffeeTheme.muted)
                            }
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundStyle(selected ? CoffeeTheme.espresso : CoffeeTheme.cream)
                        .padding(.horizontal, 12).padding(.vertical, 12)
                        .background(selected ? CoffeeTheme.latte : (hovered == profile ? CoffeeTheme.raised : Color.clear),
                                    in: RoundedRectangle(cornerRadius: 11))
                        .contentShape(RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovered = $0 ? profile : nil }
                    .accessibilityLabel("\(profile.title) profile\(selected ? ", selected" : "")")
                    .accessibilityHint("Switches your keypad to \(profile.title)")
                }
            }
            Rectangle().fill(CoffeeTheme.line).frame(height: 1).padding(.vertical, 12)
            Button { model.openSettings() } label: {
                HStack {
                    Text("Settings…")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 12)).foregroundStyle(CoffeeTheme.cream)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(settingsHovered ? CoffeeTheme.roast : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).onHover { settingsHovered = $0 }
            Text("Right-click the menu icon to switch quickly.")
                .font(.system(size: 9)).foregroundStyle(CoffeeTheme.muted)
                .padding(.horizontal, 11).padding(.top, 9).padding(.bottom, 4)
        }
        .padding(12).frame(width: 296)
        .foregroundStyle(CoffeeTheme.cream).background(CoffeeTheme.cocoa)
        .preferredColorScheme(.dark)
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case overview = "Overview", profiles = "Profiles", lights = "Lights", preferences = "Preferences"
    var id: String { rawValue }
    var icon: PixelIcon.Kind {
        switch self { case .overview, .lights: return .keyboard; case .profiles: return .pencil; case .preferences: return .dial }
    }
}

struct PreferencesView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: SettingsPage = .overview
    @State private var editingProfile: Profile = .coding
    @State private var resetRequested = false
    @State private var diagnosticsExpanded = false
    @State private var hoveredPage: SettingsPage?

    private var needsSetup: Bool { !model.accessibilityReady || !model.inputReady }
    private var connected: Bool { model.deviceStatus == "Keypad connected" }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(CoffeeTheme.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(page.rawValue).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Spacer()
                    statusLabel
                }
                .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 20)
                if model.isLightingPreview {
                    Label("Offline preview · no keypad changes", systemImage: "eye")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CoffeeTheme.latte)
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CoffeeTheme.espresso, in: RoundedRectangle(cornerRadius: 9))
                        .padding(.horizontal, 28).padding(.bottom, 15)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch page {
                        case .overview: overview
                        case .profiles: profileEditor
                        case .lights: lighting
                        case .preferences: preferences
                        }
                    }
                    .padding(.horizontal, 28).padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(page)
            }
            .background(CoffeeTheme.cocoa)
        }
        .frame(width: 780, height: 600)
        .background(CoffeeTheme.espresso)
        .foregroundStyle(CoffeeTheme.cream)
        .tint(CoffeeTheme.latte)
        .preferredColorScheme(.dark)
        .onAppear {
            editingProfile = model.profile
            if model.isLightingPreview { page = .lights }
        }
        .alert("Reset \(editingProfile.title) controls?", isPresented: $resetRequested) {
            Button("Cancel", role: .cancel) {}
            Button("Reset controls", role: .destructive) { model.resetMappings(for: editingProfile) }
        } message: { Text("This restores the six default actions for \(editingProfile.title). Your other profiles stay as they are.") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            PixelIcon(kind: .keyboard, color: CoffeeTheme.latte).frame(width: 60, height: 42)
                .padding(.bottom, 13)
            Text("Keypad\nCompanion").font(.system(size: 19, weight: .semibold, design: .rounded))
                .lineSpacing(2).padding(.bottom, 34)
            VStack(spacing: 5) {
                ForEach(SettingsPage.allCases) { item in
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { page = item }
                    } label: {
                        HStack(spacing: 10) {
                            if item == .lights {
                                PixelLightIcon(color: page == item ? CoffeeTheme.latte : CoffeeTheme.muted)
                                    .frame(width: 24, height: 19)
                            } else {
                                PixelIcon(kind: item.icon, color: page == item ? CoffeeTheme.latte : CoffeeTheme.muted)
                                    .frame(width: 24, height: 19)
                            }
                            Text(item.rawValue).font(.system(size: 12, weight: page == item ? .semibold : .regular))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(page == item ? CoffeeTheme.cream : CoffeeTheme.muted)
                        .padding(.horizontal, 11).padding(.vertical, 11)
                        .background(page == item ? CoffeeTheme.roast : (hoveredPage == item ? CoffeeTheme.cocoa : Color.clear),
                                    in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain).onHover { hoveredPage = $0 ? item : nil }
                    .accessibilityLabel("\(item.rawValue)\(page == item ? ", selected" : "")")
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    PixelIcon(kind: model.profile.pixelIcon, color: model.profile.accent).frame(width: 16, height: 16)
                    Text(model.profile.title).font(.system(size: 12, weight: .medium))
                }
                Text(model.paused ? "Keypad actions paused" : "Your active profile")
                    .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
            }
            .padding(.horizontal, 9).padding(.bottom, 3)
        }
        .padding(.horizontal, 15).padding(.vertical, 28).frame(width: 172)
        .background(CoffeeTheme.espresso)
    }

    private var statusLabel: some View {
        HStack(spacing: 6) {
            Circle().fill(model.isLightingPreview ? CoffeeTheme.muted : (needsSetup ? CoffeeTheme.latte : (connected ? CoffeeTheme.sage : CoffeeTheme.muted))).frame(width: 6, height: 6)
            Text(model.isLightingPreview ? "Offline" : (needsSetup ? "Setup needed" : (connected ? "Keypad connected" : "Waiting for keypad")))
                .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
        }
    }

    @ViewBuilder private var overview: some View {
        if needsSetup { setupPanel }
        VStack(alignment: .leading, spacing: 12) {
            sectionHeading("Active profile", subtitle: "Choose here or from the menu bar. It stays selected when you switch apps.")
            HStack(spacing: 9) {
                ForEach(Profile.allCases) { profile in
                    profileChoice(profile, selected: model.profile == profile) { model.selectProfile(profile) }
                }
            }
        }
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your \(model.profile.title.lowercased()) controls").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Customize") { editingProfile = model.profile; page = .profiles }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(CoffeeTheme.latte)
            }
            HStack(alignment: .top, spacing: 10) {
                keySummary(.key1, number: "1")
                keySummary(.key2, number: "2")
                keySummary(.key3, number: "3")
            }
            Rectangle().fill(CoffeeTheme.line).frame(height: 1)
            HStack(spacing: 17) {
                PixelIcon(kind: .dial, color: CoffeeTheme.latte).frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 7) {
                    dialSummary("Turn left", .ccw)
                    dialSummary("Press", .press)
                    dialSummary("Turn right", .cw)
                }
            }
        }
        .padding(18).background(CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 15))
        .opacity(model.paused ? 0.6 : 1)
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(model.paused ? "Taking a break" : "Keypad actions are on")
                    .font(.system(size: 13, weight: .medium))
                Text(model.paused ? "Resume when you’re ready." : "Pause any time. Your profile stays selected.")
                    .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
            }
            Spacer()
            Button(model.paused ? "Resume controls" : "Pause controls") { model.paused.toggle() }
                .buttonStyle(CoffeeButtonStyle(prominent: model.paused))
        }
        DisclosureGroup(isExpanded: $diagnosticsExpanded) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Press each key and turn the dial to check its input. Pause controls first if you only want to test the buttons.")
                    .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                Text(model.lastInput).font(.system(size: 12, weight: .medium, design: .monospaced))
                    .textSelection(.enabled)
                Text(model.lastAction).font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted).textSelection(.enabled)
                Button("Reconnect keypad") { model.reconnect() }.buttonStyle(CoffeeButtonStyle())
            }.padding(.top, 12)
        } label: {
            Text("Check keypad input").font(.system(size: 12, weight: .medium))
        }
    }

    @ViewBuilder private var profileEditor: some View {
        sectionHeading("Make each profile yours", subtitle: "Pick a profile to edit. Your active profile won’t change.")
        HStack(spacing: 9) {
            ForEach(Profile.allCases) { profile in
                profileChoice(profile, selected: editingProfile == profile) { editingProfile = profile }
            }
        }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ControlKey.allCases) { control in
                HStack(spacing: 12) {
                    Text(control.title).font(.system(size: 12, weight: .medium)).frame(width: 78, alignment: .leading)
                    Spacer(minLength: 0)
                    Menu {
                        ForEach(KeyAction.allCases) { action in
                            Button {
                                model.setAction(action, for: control, in: editingProfile)
                            } label: {
                                if model.action(for: control, in: editingProfile) == action {
                                    Label(action.title, systemImage: "checkmark")
                                } else { Text(action.title) }
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(model.action(for: control, in: editingProfile).title).lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .semibold))
                        }
                        .font(.system(size: 12)).foregroundStyle(CoffeeTheme.cream)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(CoffeeTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .frame(maxWidth: 285)
                    .accessibilityLabel("\(control.title) action")
                }
                .padding(.vertical, 9)
                if control != .cw { Rectangle().fill(CoffeeTheme.line).frame(height: 1) }
            }
        }
        HStack {
            Label(model.isLightingPreview ? "Temporary preview edits" : "Saved automatically", systemImage: "checkmark.circle")
                .font(.system(size: 11)).foregroundStyle(CoffeeTheme.sage)
            Spacer()
            Button("Reset \(editingProfile.title) controls…") { resetRequested = true }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
        }
        Text(editingProfile == .coding ? "Coding actions work when Codex is in front. Dictation uses your existing hold-to-talk shortcut." :
             editingProfile == .music ? "Music actions control Spotify, even when you’re using another app." :
             "Calls use the app chosen in Preferences. Microphone and camera shortcuts require that app in front.")
            .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted).fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var lighting: some View {
        if model.customLightingConnection != nil {
            CustomLightsView(model: model)
        } else if model.customFirmwarePresent {
            unavailableCustomLighting
        } else {
            stockLighting
        }
    }

    private var unavailableCustomLighting: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                PixelLightIcon(color: CoffeeTheme.latte).frame(width: 23, height: 29)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Custom lighting unavailable")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("The keypad’s lighting connection needs checking.")
                        .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                }
            }
            Text(model.customLightingStatus)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text("This keypad identifies as custom firmware. Color controls stay unavailable until the app confirms a compatible connection.")
                .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Reconnect the keypad to check again. If the status asks you to reopen the app, quit and reopen Keypad Companion. If the connection still fails, the firmware needs a compatibility check.")
                .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20).background(CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 15))
    }

    @ViewBuilder private var stockLighting: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("A little light for your desk", subtitle: "Choose one effect for every profile, or let your lighting follow along.")
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Follow selected profile").font(.system(size: 13, weight: .medium))
                    Text(model.lightingFollowsProfile ? "Switching profiles also changes the lighting effect." : "Use the same lighting effect for Coding, Music, and Calls.")
                        .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("Follow selected profile", isOn: $model.lightingFollowsProfile)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
        }

        if model.lightingFollowsProfile {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeading("An effect for each profile", subtitle: "Editing a profile here won’t switch your active profile.")
                ForEach(Profile.allCases) { profile in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            PixelIcon(kind: profile.pixelIcon, color: profile.accent).frame(width: 22, height: 22)
                            Text(profile.title).font(.system(size: 12, weight: .semibold))
                            if model.profile == profile {
                                Text("Active").font(.system(size: 9, weight: .medium)).foregroundStyle(CoffeeTheme.sage)
                            }
                            Spacer(minLength: 8)
                            Picker("\(profile.title) lighting", selection: Binding(
                                get: { model.lightingMode(for: profile) },
                                set: { model.setLightingMode($0, for: profile) }
                            )) {
                                ForEach(LEDMode.allCases) { Text($0.title).tag($0) }
                            }
                            .labelsHidden().frame(width: 172)
                        }
                        Text(model.lightingMode(for: profile).detail)
                            .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if profile != .calls { rule }
                }
            }
            .padding(18).background(CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 15))
        } else {
            VStack(spacing: 8) {
                ForEach(LEDMode.allCases) { mode in
                    lightingChoice(mode)
                }
            }
        }

        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.lightingStatus).font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.isLightingPreview ? "Preview edits are temporary. Your keypad and saved settings are unchanged." : "Choices save automatically. Pausing keypad controls doesn’t change the lighting.")
                    .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Reapply effect") { model.reapplyLighting() }
                .buttonStyle(CoffeeButtonStyle())
                .help("Send the active lighting effect to the connected keypad again.")
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("What this keypad can do").font(.system(size: 12, weight: .semibold))
            Text("Colors and animation are built into the keypad. Rainbow cycle moves across all three keys; it doesn’t keep all three steadily lit. Fixed profile colors, brightness, and speed aren’t supported by the stock firmware’s available controls.")
                .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Choose Off for no blinking or color changes.")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(CoffeeTheme.latte)
            Text("Per-light colors become available only with compatible custom firmware and a successful light check.")
                .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).background(CoffeeTheme.espresso.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private func lightingChoice(_ mode: LEDMode) -> some View {
        let selected = model.lightingMode == mode
        return Button { model.lightingMode = mode } label: {
            HStack(spacing: 13) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17)).foregroundStyle(selected ? CoffeeTheme.latte : CoffeeTheme.muted)
                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.title).font(.system(size: 13, weight: .semibold))
                    Text(mode.detail).font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(CoffeeTheme.cream)
            .padding(.horizontal, 16).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? CoffeeTheme.raised : CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? CoffeeTheme.latte.opacity(0.55) : Color.clear, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode.title)\(selected ? ", selected" : "")")
        .accessibilityHint(mode.detail)
    }

    @ViewBuilder private var preferences: some View {
        VStack(alignment: .leading, spacing: 17) {
            sectionHeading("Everyday preferences")
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Start at login").font(.system(size: 13, weight: .medium))
                    Text(model.loginStatus).font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                }
                Spacer()
                Toggle("Start at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLoginEnabled($0) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            rule
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Volume per dial step").font(.system(size: 13, weight: .medium))
                    Text("Applies to Music and Calls.").font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button { model.volumeStep = max(1, model.volumeStep - 1) } label: { Image(systemName: "minus") }
                        .buttonStyle(CoffeeButtonStyle()).disabled(model.volumeStep <= 1)
                        .accessibilityLabel("Decrease volume step")
                    Text("\(Int(model.volumeStep))%").font(.system(size: 12, weight: .semibold)).monospacedDigit().frame(width: 35)
                    Button { model.volumeStep = min(20, model.volumeStep + 1) } label: { Image(systemName: "plus") }
                        .buttonStyle(CoffeeButtonStyle()).disabled(model.volumeStep >= 20)
                        .accessibilityLabel("Increase volume step")
                }
            }
        }
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Calls", subtitle: "Automatic uses Discord, Zoom, or Teams when it’s in front. Otherwise, Discord is the default.")
            Picker("Call app", selection: $model.callsTarget) {
                ForEach(CallTarget.allCases) { Text($0.title).tag($0) }
            }.font(.system(size: 12))
            Text("The second button toggles deafen in Discord, or camera in Zoom and Teams. Dial volume and mute control your Mac’s audio output, not your microphone.")
                .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading("Connection & permissions")
            permissionRow("Accessibility", detail: "Send shortcuts to your apps.", ready: model.accessibilityReady) { model.openAccessibilitySettings() }
            permissionRow("Input Monitoring", detail: "Receive the keypad’s button signals.", ready: model.inputReady) { model.openInputSettings() }
            if needsSetup {
                Button("Set up permissions…") { model.requestPermissions() }.buttonStyle(CoffeeButtonStyle(prominent: true))
            }
            HStack {
                Text(model.deviceStatus).font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                Spacer()
                Button("Reconnect") { model.reconnect() }.buttonStyle(CoffeeButtonStyle())
            }
            Text("Spotify may ask for Automation access the first time you use Music. The six F13–F18 keys are reserved while this app runs.")
                .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted).fixedSize(horizontal: false, vertical: true)
        }
        rule
        HStack {
            Text("Closing settings keeps the menu-bar app running.")
                .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
            Spacer()
            Button("Quit app") { model.quit() }.buttonStyle(CoffeeButtonStyle())
        }
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Let’s connect your keypad", systemImage: "hand.wave")
                .font(.system(size: 15, weight: .semibold))
            Text("Two macOS permissions let your keypad control your apps. Enable Keypad Companion in each settings pane.")
                .font(.system(size: 12)).foregroundStyle(CoffeeTheme.muted).fixedSize(horizontal: false, vertical: true)
            permissionRow("Accessibility", detail: "Send app shortcuts", ready: model.accessibilityReady) { model.openAccessibilitySettings() }
            permissionRow("Input Monitoring", detail: "Read keypad buttons", ready: model.inputReady) { model.openInputSettings() }
            Button("Set up permissions…") { model.requestPermissions() }.buttonStyle(CoffeeButtonStyle(prominent: true))
            Text("If macOS asks you to quit and reopen, do that once after enabling access.")
                .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
        }
        .padding(18).background(CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 15))
    }

    private func permissionRow(_ title: String, detail: String, ready: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15)).foregroundStyle(ready ? CoffeeTheme.sage : CoffeeTheme.latte)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
            }
            Spacer()
            Button(ready ? "Manage" : "Open settings", action: action)
                .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(CoffeeTheme.latte)
        }
    }

    private func sectionHeading(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .semibold))
            if let subtitle {
                Text(subtitle).font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func profileChoice(_ profile: Profile, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                PixelIcon(kind: profile.pixelIcon, color: selected ? CoffeeTheme.espresso : profile.accent).frame(width: 22, height: 22)
                Text(profile.title).font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? CoffeeTheme.espresso : CoffeeTheme.cream)
            .padding(.horizontal, 13).padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(selected ? CoffeeTheme.latte : CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 11))
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(profile.title)\(selected ? ", selected" : "")")
    }

    private func keySummary(_ control: ControlKey, number: String) -> some View {
        VStack(spacing: 9) {
            Text(number).font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(CoffeeTheme.espresso).frame(width: 50, height: 40)
                .background(CoffeeTheme.latte, in: RoundedRectangle(cornerRadius: 8))
                .shadow(color: CoffeeTheme.espresso.opacity(0.3), radius: 0, y: 3)
            Text(model.actionTitle(for: control)).font(.system(size: 11)).multilineTextAlignment(.center)
                .lineLimit(2).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity)
    }
    private func dialSummary(_ label: String, _ control: ControlKey) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted).frame(width: 58, alignment: .leading)
            Text(model.actionTitle(for: control)).font(.system(size: 11))
        }
    }
    private var rule: some View { Rectangle().fill(CoffeeTheme.line).frame(height: 1) }
}

// Custom color controls are available only after both a firmware handshake and
// the user's physical check. The stock lighting view never offers RGB commands.
private struct CustomLightsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editingProfile: Profile = .coding
    @State private var selectedLED = 0

    private var target: Profile? { model.rgbFollowsProfile ? editingProfile : nil }
    private var scene: RGBLightingScene { model.rgbScene(for: target) }
    private var selected: LEDSetting { scene.leds[selectedLED] }
    private var isActiveScene: Bool { !model.rgbFollowsProfile || editingProfile == model.profile }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.customLightingVerified {
                editor
            } else {
                hardwareCheck
            }
        }
        .onAppear { editingProfile = model.profile }
    }

    private var hardwareCheck: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                PixelLightIcon(color: CoffeeTheme.latte).frame(width: 23, height: 29)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Let’s check your three lights")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(model.isLightingPreview ? "Simulated firmware · hardware remains unverified" : "Custom firmware detected · hardware check needed")
                        .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                }
            }
            Text(model.isLightingPreview ? "This demonstrates the light-check flow. The test and confirmation are simulated; your physical keypad stays unchanged." : "Color controls unlock after you confirm that the physical LEDs work. A successful connection alone can’t tell us what the lights are doing.")
                .font(.system(size: 12)).foregroundStyle(CoffeeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                checkStep("1", "Send a steady amber color to all three lights.")
                checkStep("2", "Press, hold, and release each key. Turn and press the dial. All three lights should stay amber.")
                checkStep("3", "Confirm below only if the lights stay steady throughout.")
            }
            HStack(spacing: 12) {
                Text(model.paused ? "Keypad actions are paused for testing." : "Pause keypad actions before testing the keys.")
                    .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(model.paused ? "Resume controls" : "Pause controls") { model.paused.toggle() }
                    .buttonStyle(CoffeeButtonStyle())
            }
            HStack(spacing: 12) {
                Button(model.customLightingTestInProgress ? "Sending test…" : (model.customLightingTestSent ? "Send test again" : "Test steady lights")) {
                    model.beginRGBHardwareTest()
                }
                .buttonStyle(CoffeeButtonStyle(prominent: !model.customLightingTestSent))
                .disabled(model.customLightingTestInProgress)
                .opacity(model.customLightingTestInProgress ? 0.55 : 1)
                Button("Turn lights off") { model.cancelRGBHardwareTest() }
                    .buttonStyle(CoffeeButtonStyle())
            }
            Text(model.customLightingStatus)
                .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Light check status: \(model.customLightingStatus)")
            if model.customLightingTestSent {
                Button(model.isLightingPreview ? "Preview color controls" : "All three stay steady") { model.confirmRGBHardwareTest() }
                    .buttonStyle(CoffeeButtonStyle(prominent: true))
            }
        }
        .padding(20).background(CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 15))
    }

    private func checkStep(_ number: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.system(size: 11, weight: .semibold)).foregroundStyle(CoffeeTheme.latte)
                .frame(width: 19, height: 19)
                .background(CoffeeTheme.espresso, in: RoundedRectangle(cornerRadius: 5))
            Text(description).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("A color for every light")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                Label(model.isLightingPreview ? "Simulated check" : "Checked by you", systemImage: "checkmark.circle")
                    .font(.system(size: 10)).foregroundStyle(CoffeeTheme.sage)
            }
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Follow selected profile").font(.system(size: 13, weight: .medium))
                    Text(model.rgbFollowsProfile ? "Each profile gets its own three-light palette." : "Use the same palette across all profiles.")
                        .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("Follow selected profile", isOn: $model.rgbFollowsProfile)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            if model.paused && !model.isLightingPreview {
                HStack {
                    Text("Keypad actions are still paused.")
                        .font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
                    Spacer()
                    Button("Resume controls") { model.paused = false }
                        .buttonStyle(CoffeeButtonStyle())
                }
            }
        }

        if model.rgbFollowsProfile {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    ForEach(Profile.allCases) { profile in
                        profileButton(profile)
                    }
                }
                Text(model.isLightingPreview ? "Editing a temporary \(editingProfile.title) palette. Your keypad stays unchanged." : (isActiveScene ? "Editing your active profile. Changes apply as you go." : "Editing \(editingProfile.title). This palette applies when you select that profile."))
                    .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                ForEach(0..<3, id: \.self) { index in
                    lightPreview(index)
                }
            }
            .accessibilityLabel("Palette preview. Choose a light to edit.")
            Rectangle().fill(CoffeeTheme.line).frame(height: 1)
            HStack {
                Text("LED \(selectedLED + 1)").font(.system(size: 14, weight: .semibold))
                Spacer()
                Toggle("Light on", isOn: Binding(
                    get: { selected.enabled },
                    set: { value in updateSelected { $0.enabled = value } }
                ))
                .font(.system(size: 11)).toggleStyle(.switch).controlSize(.small)
                .accessibilityLabel("LED \(selectedLED + 1) enabled")
            }
            ColorPicker("Color", selection: Binding(
                get: { color(selected.color) },
                set: { value in
                    guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return }
                    updateSelected {
                        $0.color = RGBColor(red: component(rgb.redComponent),
                                            green: component(rgb.greenComponent),
                                            blue: component(rgb.blueComponent))
                    }
                }
            ), supportsOpacity: false)
            .font(.system(size: 12))
            .disabled(!selected.enabled)
            .accessibilityLabel("LED \(selectedLED + 1) color")
            HStack(spacing: 13) {
                Text("Brightness").font(.system(size: 12)).frame(width: 70, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(selected.brightness) },
                    set: { value in updateSelected { $0.brightness = UInt8(value.rounded()) } }
                ), in: 0...255, step: 1)
                .accessibilityLabel("LED \(selectedLED + 1) brightness")
                .accessibilityValue("\(brightnessPercent(selected)) percent")
                Text("\(brightnessPercent(selected))%")
                    .font(.system(size: 11)).monospacedDigit().frame(width: 35, alignment: .trailing)
            }
            .disabled(!selected.enabled)
            HStack {
                Button("Match all to LED \(selectedLED + 1)") {
                    model.setRGBScene(RGBLightingScene(leds: Array(repeating: selected, count: 3)), for: target)
                }
                .buttonStyle(CoffeeButtonStyle())
                .help("Copy this light’s color, brightness, and on/off setting to all three lights.")
                Spacer()
                Button("All lights off") {
                    var updated = scene
                    for index in updated.leds.indices { updated.leds[index].enabled = false }
                    model.setRGBScene(updated, for: target)
                }
                .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(CoffeeTheme.muted)
            }
        }
        .padding(16).background(CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 15))

        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.customLightingStatus)
                        .font(.system(size: 11, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.isLightingPreview ? "Preview edits are temporary. Your keypad and saved settings are unchanged." : "Saved automatically on your Mac. Lights stay steady when you use the keys or dial.")
                        .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button("Reapply colors") { model.reapplyRGBLighting() }
                    .buttonStyle(CoffeeButtonStyle())
            }
            HStack {
                Text("To identify a light’s position, turn the other two off briefly.")
                    .font(.system(size: 10)).foregroundStyle(CoffeeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Reset palette") { model.resetRGBScene(for: target) }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(CoffeeTheme.latte)
            }
        }
    }

    private func profileButton(_ profile: Profile) -> some View {
        let active = editingProfile == profile
        return Button { editingProfile = profile } label: {
            HStack(spacing: 8) {
                PixelIcon(kind: profile.pixelIcon, color: active ? CoffeeTheme.espresso : profile.accent)
                    .frame(width: 20, height: 20)
                Text(profile.title).font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 11)
            .foregroundStyle(active ? CoffeeTheme.espresso : CoffeeTheme.cream)
            .background(active ? CoffeeTheme.latte : CoffeeTheme.roast, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(profile.title) lights\(active ? ", selected" : "")")
    }

    private func lightPreview(_ index: Int) -> some View {
        let light = scene.leds[index]
        let on = light.enabled && light.brightness > 0
        let selected = selectedLED == index
        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.12)) { selectedLED = index }
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(on ? color(light.color).opacity(0.25 + Double(light.brightness) / 255 * 0.75) : CoffeeTheme.espresso)
                    .frame(height: 36)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(selected ? CoffeeTheme.cream : CoffeeTheme.line, lineWidth: selected ? 2 : 1))
                    .overlay(Text("\(index + 1)").font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(CoffeeTheme.cream).frame(width: 25, height: 25)
                        .background(CoffeeTheme.espresso.opacity(0.85), in: RoundedRectangle(cornerRadius: 5)))
                Text(on ? "\(brightnessPercent(light))%" : "Off")
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? CoffeeTheme.cream : CoffeeTheme.muted)
            }
            .padding(5).frame(maxWidth: .infinity)
            .background(selected ? CoffeeTheme.raised : Color.clear, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help("Choose LED \(index + 1) to edit its color and brightness.")
        .accessibilityLabel("LED \(index + 1), \(on ? "on at \(brightnessPercent(light)) percent" : "off")\(selected ? ", selected" : "")")
        .accessibilityHint("Edit this light’s color, brightness, and on/off setting")
    }

    private func updateSelected(_ change: (inout LEDSetting) -> Void) {
        var updated = scene
        change(&updated.leds[selectedLED])
        model.setRGBScene(updated, for: target)
    }
    private func color(_ rgb: RGBColor) -> Color {
        Color(.sRGB, red: Double(rgb.red) / 255, green: Double(rgb.green) / 255, blue: Double(rgb.blue) / 255, opacity: 1)
    }
    private func component(_ value: CGFloat) -> UInt8 { UInt8(min(255, max(0, (value * 255).rounded()))) }
    private func brightnessPercent(_ light: LEDSetting) -> Int { Int((Double(light.brightness) * 100 / 255).rounded()) }
}
