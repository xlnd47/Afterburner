import SwiftUI
import UIKit

// MARK: - Theme

enum BoosteroidTheme {
    /// Near-black with a hint of blue, so the aurora glow and artwork scrims
    /// fade into it without a visible seam.
    static let background = Color(red: 0.035, green: 0.04, blue: 0.065)
    static let violet = Color(red: 0.49, green: 0.23, blue: 0.93)
    static let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    static let blue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let accent = Color(red: 0.28, green: 0.92, blue: 0.38)

    static var brandGradient: LinearGradient {
        LinearGradient(colors: [violet, indigo, blue], startPoint: .leading, endPoint: .trailing)
    }

    static var cardGradient: LinearGradient {
        LinearGradient(colors: [violet.opacity(0.7), indigo.opacity(0.7), blue.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Artwork Cache
//
// AsyncImage keeps nothing between views, so every focus change on a shelf
// re-downloaded the banner and flashed a placeholder. This keeps decoded
// images in memory: the backdrop can crossfade straight to art a card has
// already loaded, and StreamView's loading screen opens with it instantly.
nonisolated enum ArtworkCache {
    private nonisolated(unsafe) static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Decoded bitmaps, not file sizes — a full-screen banner is ~8 MB.
        cache.totalCostLimit = 256 * 1024 * 1024
        return cache
    }()

    static func cached(_ url: String, maxPixelWidth: CGFloat? = nil) -> UIImage? {
        cache.object(forKey: key(url, maxPixelWidth))
    }

    /// Downloads and decodes off the main actor. `maxPixelWidth` downsamples
    /// (card thumbnails don't need a 4K banner's full bitmap).
    @concurrent
    static func load(_ url: String, maxPixelWidth: CGFloat? = nil) async -> UIImage? {
        let key = key(url, maxPixelWidth)
        if let hit = cache.object(forKey: key) { return hit }
        guard let remote = URL(string: url),
              let data = try? await URLSession.shared.data(from: remote).0,
              let source = UIImage(data: data)
        else { return nil }

        let decoded: UIImage?
        if let maxPixelWidth, source.size.width > maxPixelWidth {
            let height = maxPixelWidth * source.size.height / source.size.width
            decoded = source.preparingThumbnail(of: CGSize(width: maxPixelWidth, height: height))
        } else {
            decoded = source.preparingForDisplay()
        }
        let image = decoded ?? source
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: key, cost: cost)
        return image
    }

    private static func key(_ url: String, _ maxPixelWidth: CGFloat?) -> NSString {
        "\(url)#\(maxPixelWidth.map { Int($0) } ?? 0)" as NSString
    }
}

/// Fills whatever frame it's given (Color.clear takes the proposed size) and
/// fades the image in once loaded; callers clip.
struct ArtworkView: View {
    let url: String?
    var contentMode: ContentMode = .fill
    var maxPixelWidth: CGFloat?
    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                }
            }
            .task(id: url) {
                guard let url else {
                    image = nil
                    return
                }
                if let hit = ArtworkCache.cached(url, maxPixelWidth: maxPixelWidth) {
                    image = hit
                    return
                }
                image = nil
                let loaded = await ArtworkCache.load(url, maxPixelWidth: maxPixelWidth)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.25)) { image = loaded }
            }
    }
}

// MARK: - Aurora Background

/// Slowly drifting blurred brand-color glows — the backdrop for screens with
/// no game artwork (login, settings, help), and what shows through while a
/// game's banner is still loading.
struct AuroraBackground: View {
    var intensity: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            BoosteroidTheme.background
            glow(BoosteroidTheme.violet, size: 1000, opacity: 0.55)
                .offset(x: drift ? -380 : -640, y: drift ? -300 : -120)
            glow(BoosteroidTheme.blue, size: 900, opacity: 0.4)
                .offset(x: drift ? 620 : 380, y: drift ? 200 : 380)
            glow(BoosteroidTheme.indigo, size: 700, opacity: 0.45)
                .offset(x: drift ? 60 : -160, y: drift ? 420 : 180)
        }
        .clipped()
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private func glow(_ color: Color, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 220)
            .opacity(opacity * intensity)
    }
}

// MARK: - Cinematic Backdrop

/// Full-screen game artwork that crossfades whenever `game` changes, over
/// the aurora. `.hero` keeps the art sharp with scrims for text on the left
/// and shelves at the bottom; `.ambient` blurs and dims it behind denser UI.
struct CinematicBackdrop: View {
    enum Style { case hero, ambient }

    let game: GameInfo?
    var style: Style = .hero
    /// Oldest first. A new image is appended on top and fades in over the
    /// previous one, which is only dropped once the new one is fully opaque —
    /// fading both at once dipped through to the aurora mid-transition.
    @State private var layers: [Backdrop] = []

    private struct Backdrop: Identifiable {
        let id = UUID()
        let image: UIImage
        /// Square catalog icon rather than a real banner — blurred so its
        /// low resolution doesn't show when stretched across the TV.
        let isLowRes: Bool
    }

    var body: some View {
        ZStack {
            AuroraBackground(intensity: style == .hero ? 1 : 0.7)
            ZStack {
                ForEach(layers) { layer in
                    let blurred = style == .ambient || layer.isLowRes
                    Color.clear
                        .overlay {
                            Image(uiImage: layer.image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipped()
                        .blur(radius: blurred ? 60 : 0)
                        // Blur pulls transparent edges in; overscan hides them.
                        .scaleEffect(blurred ? 1.15 : 1)
                        .transition(.opacity)
                }
            }
            // On the group, not per layer: two half-transparent layers
            // stacked mid-fade would read brighter than either one alone.
            .opacity(style == .ambient ? 0.5 : 1)
            scrims
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task(id: game?.id) { await loadBackdrop() }
    }

    @ViewBuilder
    private var scrims: some View {
        switch style {
        case .hero:
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.85), location: 0),
                    .init(color: .black.opacity(0.45), location: 0.4),
                    .init(color: .clear, location: 0.75),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.55), location: 0),
                    .init(color: .clear, location: 0.2),
                    .init(color: .clear, location: 0.42),
                    .init(color: BoosteroidTheme.background.opacity(0.9), location: 0.78),
                    .init(color: BoosteroidTheme.background, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        case .ambient:
            BoosteroidTheme.background.opacity(0.5)
            LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var fadeDuration: Double { style == .ambient ? 0.9 : 0.6 }

    private func loadBackdrop() async {
        guard let game, let url = game.heroBannerUrl ?? game.boxArtUrl else {
            withAnimation(.easeInOut(duration: 0.5)) { layers.removeAll() }
            return
        }
        // Blurred at half opacity, the ambient backdrop gains nothing from a
        // full-size banner — the card-sized copy the grid already loaded
        // (BannerCard's width × 2) is usually a cache hit, so it's instant.
        let maxPixelWidth: CGFloat? = style == .ambient ? 760 : nil
        // Moving along a shelf or grid fires a focus change per card; wait
        // for the user to settle so a quick sweep doesn't strobe through
        // every game's art. The dense ambient grid waits a little longer.
        let isCached = ArtworkCache.cached(url, maxPixelWidth: maxPixelWidth) != nil
        let settle = style == .ambient ? 300 : (isCached ? 0 : 180)
        if settle > 0 {
            try? await Task.sleep(for: .milliseconds(settle))
            guard !Task.isCancelled else { return }
        }
        guard let image = await ArtworkCache.load(url, maxPixelWidth: maxPixelWidth),
              !Task.isCancelled
        else { return }
        show(Backdrop(image: image, isLowRes: game.heroBannerUrl == nil))
    }

    private func show(_ backdrop: Backdrop) {
        withAnimation(.easeInOut(duration: fadeDuration)) {
            layers.append(backdrop)
        } completion: {
            // Drop everything underneath, now hidden by the opaque new layer.
            // Keeps anything appended after it, in case focus moved on again.
            guard let index = layers.firstIndex(where: { $0.id == backdrop.id }), index > 0 else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                layers.removeFirst(index)
            }
        }
    }
}

// MARK: - Banner Card

/// 16:9 game tile with the title underneath. A fixed shape keeps shelves and
/// the grid in tidy rows; games with only a square icon get it centered on a
/// blurred copy of itself instead of being cropped.
struct BannerCard: View {
    let game: GameInfo
    var width: CGFloat = 400
    let onSelect: () -> Void
    var onFocus: (() -> Void)?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onSelect) {
                artwork
                    .frame(width: width, height: width * 9 / 16)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.card)
            .focused($isFocused)

            Text(game.title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(isFocused ? 1 : 0.55))
                .lineLimit(1)
                .frame(width: width, alignment: .leading)
                // The focused card lifts and grows; keep the title clear of it.
                .offset(y: isFocused ? 14 : 0)
        }
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused { onFocus?() }
        }
    }

    private var artwork: some View {
        ZStack {
            BoosteroidTheme.cardGradient
            if let hero = game.heroBannerUrl {
                ArtworkView(url: hero, maxPixelWidth: width * 2)
            } else if let box = game.boxArtUrl {
                ArtworkView(url: box, maxPixelWidth: width)
                    .blur(radius: 30)
                    .opacity(0.6)
                ArtworkView(url: box, contentMode: .fit, maxPixelWidth: width)
                    .padding(18)
            } else {
                Text(game.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}

// MARK: - Shared Pieces

extension GameInfo {
    /// "Action · RPG · Open World" — nil when the catalog has no genres.
    var genreLine: String? {
        genres.isEmpty ? nil : genres.prefix(3).joined(separator: "  ·  ")
    }
}

/// Frosted panel used for grouped content over the aurora/backdrop.
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

// MARK: - Row Button Style

/// Full-width translucent row that turns solid on focus and lifts slightly —
/// the tvOS Settings look, drawn explicitly so the label color always flips
/// together with the fill (the system styles didn't reliably, leaving
/// white-on-white or red-on-red text). Used by Settings and Help.
struct RowButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        RowButtonChrome(configuration: configuration, isDestructive: isDestructive)
    }
}

private struct RowButtonChrome: View {
    let configuration: ButtonStyle.Configuration
    let isDestructive: Bool
    @Environment(\.isFocused) private var isFocused

    private static let red = Color(red: 0.93, green: 0.26, blue: 0.3)

    var body: some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(isFocused ? 1.02 : 1)
            .shadow(color: .black.opacity(isFocused ? 0.35 : 0), radius: 20, y: 10)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    /// Destructive rows stay white-on-red in both states, so the label is
    /// readable without focus too.
    private var foreground: Color {
        if isDestructive { return .white }
        return isFocused ? .black : .white
    }

    private var background: AnyShapeStyle {
        if isDestructive {
            return AnyShapeStyle(isFocused ? Self.red : Self.red.opacity(0.28))
        }
        return AnyShapeStyle(isFocused ? Color.white : Color.white.opacity(0.07))
    }
}

extension View {
    /// tvOS 26 draws a grey "scroll edge effect" band where a scroll view
    /// meets the edge of the screen. Across a full-width screen it blends
    /// in; under a single column (Settings) it reads as a stray grey bar.
    @ViewBuilder
    func hidingScrollEdgeEffect() -> some View {
        if #available(tvOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .all)
        } else {
            self
        }
    }
}
