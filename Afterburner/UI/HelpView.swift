import CoreImage
import SwiftUI
import UIKit

/// Help content, opened from Settings → Help & Support (it used to be its own
/// tab). Same two-column shape as Settings: topics on the left, and the
/// focused topic's text on the right — moving focus is enough, no click
/// needed, and everything stays reachable with the Siri Remote's d-pad.
///
/// Everything here describes behavior that actually exists in the app. The
/// original skeleton had two topics that never matched anything real
/// ("Steam Controller" — the app has a Steam OVERLAY button, not Steam
/// Controller support; "Specifications" — vague) and a Technical Support
/// section linking to a Discord and a Reddit that don't exist for this
/// project. Those were dropped rather than filled with invented content.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Topic = .introduction
    @FocusState private var focusedTopic: Topic?

    private enum Topic: String, CaseIterable, Identifiable {
        case introduction = "Introduction"
        case gettingStarted = "Getting Started"
        case controlMethods = "Control Methods"
        case steam = "Steam Overlay"
        case duringGameplay = "During Gameplay"
        case configuration = "Configuration"
        case requirements = "Requirements & Limits"
        case troubleshooting = "Troubleshooting"
        case support = "Support Afterburner"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .introduction: return "sparkles"
            case .gettingStarted: return "flag.checkered"
            case .controlMethods: return "gamecontroller"
            case .steam: return "rectangle.on.rectangle"
            case .duringGameplay: return "play.rectangle"
            case .configuration: return "slider.horizontal.3"
            case .requirements: return "checklist"
            case .troubleshooting: return "wrench.and.screwdriver"
            case .support: return "heart"
            }
        }

        /// One entry per paragraph. A leading "• " marks a bullet; the row
        /// renderer indents those and leaves everything else as body copy.
        var lines: [String] {
            switch self {
            case .introduction:
                return [
                    "Afterburner is an unofficial, open-source Boosteroid client for Apple TV. It signs in to your Boosteroid account, lists the games in your library, and streams a session to your TV over WebRTC with full controller support.",
                    "It is not affiliated with, endorsed by, or supported by Boosteroid, and it needs your own active Boosteroid subscription.",
                ]
            case .gettingStarted:
                return [
                    "• Sign in with your Boosteroid email and password on the login screen — or scan its QR code and type them on your phone instead.",
                    "• Pair a game controller in tvOS Settings → Remotes and Devices → Bluetooth.",
                    "• Pick a game from your library on the Home screen. The app queues a session, waits for a machine, and starts streaming on its own.",
                    "Launching a game resumes it directly if that same game is already running on your account.",
                ]
            case .controlMethods:
                return [
                    "• Game controller — MFi, Xbox, PlayStation, and Nintendo Switch pads. Buttons, triggers, sticks, and D-pad are all forwarded to the cloud PC.",
                    "• Siri Remote — navigates the app. During a stream, press Play/Pause to open the options bar.",
                    "• Options bar from a controller — hold Start + Select together, since controllers have no Play/Pause button.",
                    "• On-screen keyboard — open it from the options bar to type into launchers, logins, or in-game chat.",
                    "• Pointer mode — turns the Siri Remote touch surface into a mouse, for launchers and desktop UI that a gamepad can't reach.",
                ]
            case .steam:
                return [
                    "The Steam Overlay button in the options bar sends Shift+Tab to the cloud PC — the standard Steam overlay shortcut.",
                    "The overlay is drawn inside the stream itself, so once it opens, use your controller as you normally would.",
                ]
            case .duringGameplay:
                return [
                    "To open the options bar: press Play/Pause on the Siri Remote, or hold Start + Select together on a game controller. Repeat to close it.",
                    "Controllers have no Play/Pause button, which is why they use the Start + Select combo instead. Pressing either button on its own still goes to the game as normal.",
                    "• Disconnect — ends the cloud session and returns to the app. Boosteroid keeps your machine warm for a while afterwards, so reconnecting soon after picks the game back up where you left it.",
                    "• Keyboard — opens the on-screen keyboard.",
                    "• Pointer — uses the Siri Remote touch surface as a mouse.",
                    "• Steam Overlay — sends Shift+Tab to the cloud PC.",
                    "• Performance Overlay — shows live bitrate, frame rate, latency, and which server you're on.",
                ]
            case .configuration:
                return [
                    "• Stream quality — resolution from 720p to 4K, and 60 or 120 fps.",
                    "• Bitrate — automatic, or a manual ceiling if you'd rather cap it yourself.",
                    "• Controller — analog stick deadzone, plus rumble on/off and its intensity.",
                    "• Overlay — the performance overlay is off by default; turn it on here to have it show in every stream. You can also toggle it for the current session from the options bar.",
                    "• Region — allow connections to distant regions, and pick a preferred server location. Allowing distant regions widens the pool of machines but can add latency.",
                    "Quality and region changes take effect the next time you start a game, not mid-session.",
                ]
            case .requirements:
                return [
                    "• An Apple TV running tvOS 18 or later.",
                    "• An active, paid Boosteroid subscription.",
                    "• A strong 5 GHz Wi-Fi or wired connection, especially for 1080p60 and above.",
                    "Video is H.264 only. Boosteroid delivers H.265 and AV1 exclusively over its own native transport, which this app does not implement — so that's a service-side limit, not an Apple TV one.",
                ]
            case .support:
                // Custom content (QR code) — see HelpView.supportContent.
                return []
            case .troubleshooting:
                return [
                    "• Can't sign in — use the same email you sign in with on cloud.boosteroid.com, not another address you own. And if you created the account with \"Continue with Google\" it has no password at all, so set one on the website first, then sign in here with it.",
                    "• Controller not responding — make sure the pad is paired in tvOS Settings → Remotes and Devices, not just powered on. If it still doesn't respond, disconnect and start the game again.",
                    "• Rumble not working — check that rumble is enabled in Settings. Some third-party pads running in a compatibility or Xbox emulation mode don't implement vibration at all, even though their buttons work fine.",
                    "• Bitrate drops while playing — the server lowers quality when it detects packet loss or rising latency. Turn on the performance overlay: if latency climbs as the bitrate falls, it's a network condition rather than the app.",
                    "• Long queue times — Boosteroid queues per region. Allowing distant regions in Settings gives you access to more machines.",
                    "• Black screen after connecting — disconnect and start the game again.",
                ]
            }
        }
    }

    var body: some View {
        // A ZStack layer, like Home/Library — as a `.background {}` the
        // aurora stopped at the safe-area line and left a grey band of the
        // system background along the bottom of the screen.
        ZStack {
            AuroraBackground(intensity: 0.6)
            HStack(alignment: .top, spacing: 60) {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Help & Support")
                            .font(.system(size: 52, weight: .heavy))
                            .foregroundStyle(.white)
                        Text("Press Menu to go back")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    VStack(spacing: 10) {
                        ForEach(Topic.allCases) { topic in
                            topicRow(topic)
                        }
                    }
                }
                .frame(width: 540)
                .focusSection()

                detail(selected)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.top, 110)
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 60)
        }
        .defaultFocus($focusedTopic, .introduction)
        .onChange(of: focusedTopic) { _, topic in
            if let topic { selected = topic }
        }
        .onExitCommand { dismiss() }
    }

    private func topicRow(_ topic: Topic) -> some View {
        Button { selected = topic } label: {
            HStack(spacing: 20) {
                Image(systemName: topic.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: 36)
                Text(topic.rawValue)
                    .font(.system(size: 26, weight: .semibold))
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        }
        .buttonStyle(RowButtonStyle())
        .focusEffectDisabled()
        .focused($focusedTopic, equals: topic)
    }

    private func detail(_ topic: Topic) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 18) {
                Image(systemName: topic.icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(BoosteroidTheme.brandGradient)
                Text(topic.rawValue)
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(.white)
            }

            if topic == .support {
                supportContent
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(topic.lines.enumerated()), id: \.offset) { _, line in
                        paragraph(line)
                    }
                }
                .font(.system(size: 24))
                // Not .secondary: on the dark background that renders too dim
                // to read comfortably from a couch.
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 28)
        .id(topic)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: topic)
    }

    /// A leading "• " marks a bullet. Short "Label — explanation" bullets get
    /// the label in bold so the list scans quickly.
    @ViewBuilder
    private func paragraph(_ line: String) -> some View {
        if line.hasPrefix("• ") {
            let text = String(line.dropFirst(2))
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("•")
                    .fontWeight(.heavy)
                    .foregroundStyle(BoosteroidTheme.violet)
                if let range = text.range(of: " — "), text.distance(from: text.startIndex, to: range.lowerBound) <= 40 {
                    let head = Text(String(text[..<range.lowerBound])).fontWeight(.semibold).foregroundStyle(.white)
                    let rest = String(text[range.lowerBound...])
                    Text("\(head)\(rest)")
                } else {
                    Text(text)
                }
            }
        } else {
            Text(line)
        }
    }

    private var supportContent: some View {
        HStack(alignment: .center, spacing: 36) {
            // tvOS has no browser, so a tappable link would go nowhere —
            // a QR code is the only way to hand this URL off to a device
            // that can actually open it.
            if let qr = Self.donationQR {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 240, height: 240)
                    .padding(16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Buy Me a Coffee")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Afterburner is free and open source, and always will be. If it's useful to you, scan the code with your phone to support development.")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.85))
                Text(Self.donationURL)
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private static let donationURL = "https://buymeacoffee.com/xlnd47"

    /// Rendered once (static stored properties are lazy) rather than on every
    /// body evaluation.
    private static let donationQR: UIImage? = QRCode.make(from: donationURL)
}
