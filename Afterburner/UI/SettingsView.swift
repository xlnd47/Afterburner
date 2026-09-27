import SwiftUI

/// Two columns in the spirit of tvOS's own Settings app: a fixed account and
/// "current setup" summary on the left, and one scrolling list of uniform,
/// full-width rows on the right. Every row — toggle or choice — has the same
/// shape with its value on the trailing edge, so pressing down always lands
/// on the next row. (The previous mix of leading buttons, trailing menus and
/// steppers stranded focus: nothing sat directly below a trailing control.)
///
/// Plain ScrollView with hand-built rows instead of `Form`: on the app's
/// dark background Form's own chrome rendered dark-on-dark.
struct SettingsView: View {
    @Environment(AuthManager.self) var authManager
    @Environment(GamesViewModel.self) var viewModel
    @State private var confirmingSignOut = false
    @State private var showingHelp = false

    private let resolutions: [(String, String)] = [
        ("720p", "1280x720"), ("1080p", "1920x1080"),
        ("1440p", "2560x1440"), ("4K", "3840x2160"),
    ]
    // 30 removed 2026-08-06: Boosteroid never delivers below 60, so offering
    // it only created a setting that silently did nothing.
    private let fpsOptions: [(String, Int)] = [("60 fps", 60), ("120 fps", 120)]
    /// Within StreamSettings' 3–80 Mbps clamp (the official client's range).
    private let bitrateOptions: [(String, Int)] = [3, 5, 10, 15, 20, 25, 30, 40, 50, 60, 70, 80].map { ("\($0) Mbps", $0) }
    private let deadzoneOptions: [(String, Int)] = stride(from: 0, through: 50, by: 5).map { ("\($0)%", $0) }

    var body: some View {
        @Bindable var viewModel = viewModel
        // A ZStack layer, like Home/Library — as a `.background {}` the
        // aurora stopped at the safe-area line and left a grey band of the
        // system background along the bottom of the screen.
        ZStack {
            AuroraBackground(intensity: 0.6)
            HStack(alignment: .top, spacing: 60) {
                sidebar
                    .frame(width: 500)
                    .focusSection()

                ScrollView {
                    VStack(alignment: .leading, spacing: 44) {
                        section("Stream Quality") {
                            ChoiceRow(icon: "tv", title: "Resolution",
                                      options: resolutions,
                                      selection: $viewModel.streamSettings.resolution)
                            ChoiceRow(icon: "speedometer", title: "Frame Rate",
                                      options: fpsOptions,
                                      selection: $viewModel.streamSettings.fps)
                        }
                        section("Bitrate") {
                            ToggleRow(icon: "antenna.radiowaves.left.and.right", title: "Automatic Bitrate",
                                      subtitle: "Matches the bitrate to your resolution, like the official apps.",
                                      isOn: $viewModel.streamSettings.automaticBitrate)
                            if !viewModel.streamSettings.automaticBitrate {
                                ChoiceRow(icon: "slider.horizontal.3", title: "Max Bitrate",
                                          options: bitrateOptions,
                                          fallbackLabel: "\(viewModel.streamSettings.manualBitrateMbps) Mbps",
                                          selection: $viewModel.streamSettings.manualBitrateMbps)
                            }
                        }
                        section("Controller") {
                            ChoiceRow(icon: "scope", title: "Stick Deadzone",
                                      subtitle: "How far a stick moves before it registers.",
                                      options: deadzoneOptions,
                                      fallbackLabel: "\(deadzonePercent.wrappedValue)%",
                                      selection: deadzonePercent)
                            ToggleRow(icon: "waveform", title: "Rumble",
                                      isOn: $viewModel.streamSettings.rumbleEnabled)
                            if viewModel.streamSettings.rumbleEnabled {
                                ChoiceRow(icon: "waveform.path", title: "Rumble Intensity",
                                          options: RumbleIntensity.allCases.map { ($0.displayName, $0) },
                                          selection: $viewModel.streamSettings.rumbleIntensity)
                            }
                        }
                        section("Overlay") {
                            ToggleRow(icon: "chart.bar.xaxis", title: "Performance Overlay",
                                      subtitle: "Bitrate, frame rate, latency and server while streaming.",
                                      isOn: $viewModel.streamSettings.showStatsOverlay)
                        }
                        section("Region") {
                            ToggleRow(icon: "globe", title: "Distant Regions",
                                      subtitle: "More machines to pick from, but possibly more latency.",
                                      isOn: allowDistantRegionsBinding)
                            ChoiceRow(icon: "mappin.and.ellipse", title: "Server Location",
                                      options: playgroundOptions,
                                      selection: preferredPlaygroundBinding)
                            if let regionSettingsError = viewModel.regionSettingsError {
                                Text(regionSettingsError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.leading, 8)
                            }
                        }
                        section("Support") {
                            Button { showingHelp = true } label: {
                                SettingsRowContent(icon: "questionmark.circle", title: "Help & Support",
                                                   subtitle: "Controls, gameplay tips and troubleshooting.",
                                                   value: nil, accessory: .disclosure)
                            }
                            .buttonStyle(RowButtonStyle())
                            .focusEffectDisabled()
                        }
                    }
                    // Room for the focused row's scale and shadow inside the clip.
                    .padding(.horizontal, 24)
                    .padding(.vertical, 30)
                }
                // Rows scroll all the way to the bottom of the screen instead of
                // being cut off at the safe-area line.
                .ignoresSafeArea(edges: .bottom)
                .hidingScrollEdgeEffect()
                .focusSection()
            }
            .padding(.leading, 80)
            .padding(.trailing, 56)
        }
        // Settings controls use Boosteroid's brand color instead of
        // inheriting the app's green launch accent.
        .tint(BoosteroidTheme.violet)
        // Help used to be its own tab; it's reference material rather than a
        // destination, so it lives here now and opens over everything.
        .fullScreenCover(isPresented: $showingHelp) { HelpView() }
        .confirmationDialog("Sign out of Boosteroid?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authManager.logout() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            profileCard
            setupSummary
            Spacer(minLength: 0)
            Text("Afterburner \(appVersion) · unofficial Boosteroid client")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 30)
    }

    private var profileCard: some View {
        let user = authManager.session?.user
        return VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 22) {
                avatar(for: user)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user?.displayName ?? "Boosteroid")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let email = user?.email {
                        Text(email)
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            Button { confirmingSignOut = true } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            .buttonStyle(RowButtonStyle(isDestructive: true))
            .focusEffectDisabled()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 24)
    }

    /// The initial on the brand gradient, replaced by the account's own
    /// avatar once (and if) it loads.
    private func avatar(for user: AuthUser?) -> some View {
        ZStack {
            Circle().fill(BoosteroidTheme.brandGradient)
            Text(String((user?.displayName ?? "B").prefix(1)).uppercased())
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(.white)
            if let url = user?.avatarUrl {
                ArtworkView(url: url, maxPixelWidth: 200)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(Circle())
    }

    private var setupSummary: some View {
        let settings = viewModel.streamSettings
        let resolution = resolutions.first { $0.1 == settings.resolution }?.0 ?? settings.resolution
        return VStack(alignment: .leading, spacing: 18) {
            Text("CURRENT SETUP")
                .font(.system(size: 18, weight: .bold))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
            summaryLine("tv", "\(resolution) · \(settings.fps) fps")
            summaryLine("antenna.radiowaves.left.and.right",
                        settings.automaticBitrate ? "Automatic bitrate" : "Up to \(settings.manualBitrateMbps) Mbps")
            summaryLine("mappin.and.ellipse", selectedPlaygroundLabel)
            summaryLine("gamecontroller",
                        settings.rumbleEnabled ? "Rumble: \(settings.rumbleIntensity.displayName)" : "Rumble off")
            Text("Changes apply the next time you start a game.")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 24)
    }

    private func summaryLine(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(BoosteroidTheme.brandGradient)
                .frame(width: 32)
            Text(text)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    // MARK: Bindings

    /// Mirrors cloud.boosteroid.com/profile/account/main's "Permitir ligação
    /// a regiões distantes" toggle (see GamesViewModel.setAllowDistantRegions
    /// / BoosteroidClient's Streaming Regions section for the confirmed
    /// PATCH this drives). The write is async and server-side, so this is a
    /// custom Binding rather than a plain `$viewModel.foo` — the setter fires
    /// a Task instead of writing synchronously.
    private var allowDistantRegionsBinding: Binding<Bool> {
        Binding(
            get: { viewModel.allowDistantRegions },
            set: { newValue in
                Task { await viewModel.setAllowDistantRegions(newValue, authManager: authManager) }
            }
        )
    }

    /// Same async server-side write as above, for the preferred playground.
    private var preferredPlaygroundBinding: Binding<Int?> {
        Binding(
            get: { viewModel.preferredPlaygroundId },
            set: { newValue in
                Task { await viewModel.setPreferredPlayground(newValue, authManager: authManager) }
            }
        )
    }

    /// Whole percent, so menu options compare exactly — the stored Double
    /// could hold values like 0.0999… from the old ±5% stepper.
    private var deadzonePercent: Binding<Int> {
        Binding(
            get: { Int((viewModel.streamSettings.controllerDeadzone * 100).rounded()) },
            set: { viewModel.streamSettings.controllerDeadzone = Double($0) / 100 }
        )
    }

    private var playgroundOptions: [(String, Int?)] {
        [("Automatic", nil)] + viewModel.playgrounds.map { ($0.displayName, Optional($0.id)) }
    }

    /// The currently selected location's name, or "Automatic Location" while
    /// `preferredPlaygroundId` is nil.
    private var selectedPlaygroundLabel: String {
        guard let id = viewModel.preferredPlaygroundId else { return "Automatic Location" }
        return viewModel.playgrounds.first(where: { $0.id == id })?.displayName ?? "Automatic Location"
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.leading, 8)
            VStack(spacing: 12) {
                content()
            }
        }
    }
}

// MARK: - Rows

/// A choice as a Menu — renders as a proper tvOS popover (unlike Picker's
/// pushed destination, which renders blank inside a TabView here).
private struct ChoiceRow<Value: Hashable>: View {
    let icon: String
    let title: String
    var subtitle: String?
    let options: [(String, Value)]
    /// Shown when the stored value isn't one of the options (e.g. a bitrate
    /// saved by the old stepper).
    var fallbackLabel: String = "—"
    @Binding var selection: Value

    var body: some View {
        Menu {
            ForEach(options, id: \.1) { label, value in
                Button {
                    selection = value
                } label: {
                    if selection == value {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle,
                               value: options.first { $0.1 == selection }?.0 ?? fallbackLabel,
                               accessory: .chevron)
        }
        .buttonStyle(RowButtonStyle())
        .focusEffectDisabled()
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            SettingsRowContent(icon: icon, title: title, subtitle: subtitle,
                               value: nil, accessory: .toggle(isOn))
        }
        .buttonStyle(RowButtonStyle())
        .focusEffectDisabled()
    }
}

private struct SettingsRowContent: View {
    enum Accessory { case chevron, disclosure, toggle(Bool) }

    let icon: String
    let title: String
    let subtitle: String?
    let value: String?
    let accessory: Accessory

    var body: some View {
        HStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                if let subtitle {
                    // Hierarchical: gray on the white focused row, dimmed
                    // white on the translucent unfocused one.
                    Text(subtitle)
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 20)
            if let value {
                Text(value)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            switch accessory {
            case .chevron:
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
            case .disclosure:
                Image(systemName: "chevron.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
            case .toggle(let isOn):
                ToggleSwitch(isOn: isOn)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
    }
}

private struct ToggleSwitch: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? AnyShapeStyle(BoosteroidTheme.violet) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
            .frame(width: 72, height: 40)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                    .padding(4)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
    }
}
