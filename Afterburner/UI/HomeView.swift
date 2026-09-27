import SwiftUI

/// Cinematic home: the focused game's artwork fills the screen behind a big
/// title block, with shelves floating over the bottom fade. Moving focus
/// along a shelf swaps both the backdrop and the hero text to that game.
struct HomeView: View {
    let featuredGame: GameInfo?
    let favoriteGames: [GameInfo]
    let libraryGames: [GameInfo]
    let isLoading: Bool
    let error: String?
    let onPlay: (GameInfo) -> Void
    let onShowDetails: (GameInfo) -> Void
    let onRefresh: () async -> Void

    /// The last card focused on a shelf — nil until the user moves onto one,
    /// so the hero opens on the featured (last played) game.
    @State private var spotlight: GameInfo?

    private var heroGame: GameInfo? { spotlight ?? featuredGame }

    var body: some View {
        ZStack {
            CinematicBackdrop(game: heroGame)

            if isLoading, featuredGame == nil {
                loadingView
            } else if featuredGame == nil {
                emptyView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 56) {
                        if let heroGame { heroInfo(heroGame) }
                        if !favoriteGames.isEmpty {
                            shelf("Favorites", games: favoriteGames)
                        }
                        shelf("Your Library", games: libraryGames)
                        if favoriteGames.isEmpty {
                            Label("Add games to Favorites from their Details screen to pin them here.", systemImage: "star")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 80)
                    .padding(.bottom, 80)
                }
                .scrollClipDisabled()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func heroInfo(_ game: GameInfo) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                if let genres = game.genreLine {
                    Text(genres.uppercased())
                        .font(.system(size: 22, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Text(game.title)
                    .font(.system(size: 76, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.5), radius: 12)
                if let summary = game.summary {
                    Text(summary)
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                        .frame(maxWidth: 900, alignment: .leading)
                }
            }
            // Only the text swaps per game — the buttons stay put so focus
            // never lands on a view that's being replaced.
            .id(game.id)
            .transition(.opacity)

            HStack(spacing: 20) {
                Button { onPlay(game) } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .padding(.horizontal, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(BoosteroidTheme.violet)

                Button { onShowDetails(game) } label: {
                    Label("Details", systemImage: "info.circle")
                        .font(.system(size: 28, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        // Tall enough that the artwork breathes, short enough that the first
        // shelf peeks in at the bottom and invites scrolling down.
        .frame(height: 560, alignment: .bottomLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.35), value: game.id)
        .focusSection()
    }

    private func shelf(_ title: String, games: [GameInfo]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(games) { game in
                        BannerCard(
                            game: game,
                            width: 400,
                            onSelect: { onShowDetails(game) },
                            onFocus: { spotlight = game }
                        )
                    }
                }
                // Room for the card style's focus lift and shadow.
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }

    private var loadingView: some View {
        VStack(spacing: 22) {
            ProgressView()
                .controlSize(.large)
            Text("Loading your Boosteroid library…")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No games yet", systemImage: "gamecontroller")
        } description: {
            Text(error ?? "Install a game in Boosteroid, then choose Refresh.")
        } actions: {
            Button("Refresh") { Task { await onRefresh() } }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct GameOverviewView: View {
    let game: GameInfo
    let isFavorite: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CinematicBackdrop(game: game)

            HStack(alignment: .bottom, spacing: 60) {
                VStack(alignment: .leading, spacing: 20) {
                    if let genres = game.genreLine {
                        Text(genres.uppercased())
                            .font(.system(size: 22, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(game.title)
                        .font(.system(size: 84, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .shadow(color: .black.opacity(0.5), radius: 12)
                    Label("In Library", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(BoosteroidTheme.accent)
                    if let summary = game.summary {
                        Text(summary)
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(4)
                            .frame(maxWidth: 950, alignment: .leading)
                    }
                    HStack(spacing: 20) {
                        Button(action: onPlay) {
                            Label("Play", systemImage: "play.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BoosteroidTheme.violet)

                        Button(action: onToggleFavorite) {
                            Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                  systemImage: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 28, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }
                    .padding(.top, 12)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 22) {
                    metadata("DEVELOPER", game.developer)
                    metadata("PUBLISHER", game.publisher)
                    metadata("RATING", game.rating)
                }
            }
            .padding(.horizontal, 100)
            .padding(.bottom, 100)
        }
        .onExitCommand(perform: onDismiss)
    }

    @ViewBuilder private func metadata(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .trailing, spacing: 4) {
                Text(label)
                    .font(.system(size: 18, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                Text(value)
                    .font(.system(size: 26))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct LibraryView: View {
    let games: [GameInfo]
    let isLoading: Bool
    let onPlay: (GameInfo) -> Void
    @Environment(GamesViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var sortOrder: LibrarySortOrder = .default
    @State private var carouselRequest: LibraryCarouselRequest?
    @State private var spotlight: GameInfo?

    private var filteredGames: [GameInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = games.filter { game in
            query.isEmpty || game.title.localizedCaseInsensitiveContains(query)
        }
        switch sortOrder {
        case .default: break
        case .titleAZ: result.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleZA: result.sort { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        case .recentFirst:
            result.sort {
                if $0.id == viewModel.lastPlayedGameID { return true }
                if $1.id == viewModel.lastPlayedGameID { return false }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
        return result
    }

    /// Four fixed columns: 4 × 380 + 3 × 48 fits the 1760pt content width.
    private let columns = Array(repeating: GridItem(.fixed(380), spacing: 48), count: 4)

    var body: some View {
        let visibleGames = filteredGames
        ZStack {
            CinematicBackdrop(game: spotlight ?? visibleGames.first, style: .ambient)

            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    libraryHeader(visibleCount: visibleGames.count)

                    if visibleGames.isEmpty, !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 140)
                    } else {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 56) {
                            ForEach(visibleGames) { game in
                                BannerCard(
                                    game: game,
                                    width: 380,
                                    onSelect: {
                                        carouselRequest = LibraryCarouselRequest(games: visibleGames, startId: game.id)
                                    },
                                    onFocus: { spotlight = game }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 50)
            }
            // Clipped (unlike Home's shelves) so the grid disappears under
            // the tab bar when scrolling; the 80/50pt padding already leaves
            // room for the focus lift.

            if isLoading, games.isEmpty { ProgressView().controlSize(.large) }
        }
        .fullScreenCover(item: $carouselRequest) { request in
            LibraryCarouselView(request: request, onPlay: onPlay, onDismiss: { carouselRequest = nil })
                .environment(viewModel)
        }
    }

    /// Own search field instead of `.searchable`: tvOS floats the system
    /// search bar over the top of the content, and it sat on top of this
    /// header's title.
    private func libraryHeader(visibleCount: Int) -> some View {
        HStack(alignment: .center, spacing: 24) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text("Library")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)
                Text("\(visibleCount) of \(games.count) games")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
                TextField(games.isEmpty ? "Loading library…" : "Search \(games.count) games", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(width: 460)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
            Menu {
                ForEach(LibrarySortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        Label(order.rawValue, systemImage: sortOrder == order ? "checkmark" : "circle")
                    }
                }
            } label: {
                Label("Sort: \(sortOrder.rawValue)", systemImage: "arrow.up.arrow.down")
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
        .focusSection()
    }
}

private enum LibrarySortOrder: String, CaseIterable {
    case `default` = "Default"
    case titleAZ = "A → Z"
    case titleZA = "Z → A"
    case recentFirst = "Recently Played"
}

private struct LibraryCarouselRequest: Identifiable {
    let id = UUID()
    let games: [GameInfo]
    let startId: String
}

private struct LibraryCarouselView: View {
    private enum ActionFocus: Hashable { case play, favorite }

    let request: LibraryCarouselRequest
    let onPlay: (GameInfo) -> Void
    let onDismiss: () -> Void
    @Environment(GamesViewModel.self) private var viewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentIndex: Int
    @State private var navigationDirection = 1
    @FocusState private var actionFocus: ActionFocus?

    init(request: LibraryCarouselRequest, onPlay: @escaping (GameInfo) -> Void, onDismiss: @escaping () -> Void) {
        self.request = request
        self.onPlay = onPlay
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: request.games.firstIndex { $0.id == request.startId } ?? 0)
    }

    private var game: GameInfo { request.games[currentIndex] }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CinematicBackdrop(game: game, style: .ambient)

                // Match GeForce Now's accordion geometry. GeometryReader uses
                // tvOS's inset safe area here, so the card deliberately extends
                // nearly to that frame's edges to occupy about 90% of the actual
                // television width, while retaining the neighboring previews.
                // A prior HStack clipped the artwork before assigning those
                // widths, allowing the full images to spill over each other.
                ZStack {
                    if currentIndex > 0 {
                        neighborCard(at: currentIndex - 1, alignment: .trailing)
                            .frame(width: geo.size.width * 0.11, height: geo.size.height)
                            .compositingGroup()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            // Center-card half width (49%) + preview half
                            // width (5.5%) + a visible GeForce-style gutter.
                            .offset(x: -(geo.size.width * 0.545 + 24))
                    }

                    overviewCard(game)
                        .frame(width: geo.size.width * 0.98, height: geo.size.height)
                        .compositingGroup()
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        }
                        .id(game.id)
                        .transition(cardTransition)
                        .zIndex(1)

                    if currentIndex + 1 < request.games.count {
                        neighborCard(at: currentIndex + 1, alignment: .leading)
                            .frame(width: geo.size.width * 0.11, height: geo.size.height)
                            .compositingGroup()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .offset(x: geo.size.width * 0.545 + 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, geo.size.height * 0.035)
            }
        }
        .onMoveCommand { direction in
            switch (direction, actionFocus) {
            case (.right, .play):
                actionFocus = .favorite
            case (.left, .favorite):
                actionFocus = .play
            case (.left, .play), (.left, nil):
                if currentIndex > 0 { moveCard(by: -1) }
            case (.right, .favorite), (.right, nil):
                if currentIndex + 1 < request.games.count { moveCard(by: 1) }
            default:
                break
            }
        }
        .onExitCommand(perform: onDismiss)
        .defaultFocus($actionFocus, .play)
    }

    private var cardTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let incoming: Edge = navigationDirection > 0 ? .trailing : .leading
        let outgoing: Edge = navigationDirection > 0 ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: incoming).combined(with: .opacity),
            removal: .move(edge: outgoing).combined(with: .opacity)
        )
    }

    private func moveCard(by offset: Int) {
        let destination = currentIndex + offset
        guard request.games.indices.contains(destination) else { return }
        navigationDirection = offset
        withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.38, dampingFraction: 0.84)) {
            currentIndex = destination
        }
        actionFocus = .play
    }

    @ViewBuilder private func neighborCard(at index: Int, alignment: Alignment) -> some View {
        if request.games.indices.contains(index) {
            carouselArtwork(request.games[index])
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        } else { Color.clear }
    }

    private func overviewCard(_ game: GameInfo) -> some View {
        ZStack(alignment: .bottomLeading) {
            carouselArtwork(game).frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.25), .black.opacity(0.94)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(game.title).font(.system(size: 58, weight: .bold)).lineLimit(2)
                    if !game.genres.isEmpty {
                        Text(game.genres.prefix(6).joined(separator: "  ·  "))
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    if let summary = game.summary {
                        Text(summary)
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(3)
                            .frame(maxWidth: 700, alignment: .leading)
                    }
                    Label("In Library", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(BoosteroidTheme.accent)
                    HStack(spacing: 16) {
                        Button { onPlay(game) } label: {
                            Label("Play", systemImage: "play.fill")
                                .font(.system(size: 28, weight: .medium))
                                .frame(minWidth: 110)
                        }
                            .buttonStyle(.borderedProminent).tint(BoosteroidTheme.violet)
                            .focused($actionFocus, equals: .play)
                        Button { viewModel.toggleFavorite(game) } label: {
                            Label(viewModel.isFavorite(game) ? "Remove from Favorites" : "Add to Favorites",
                                  systemImage: viewModel.isFavorite(game) ? "star.fill" : "star")
                                .font(.system(size: 28, weight: .medium))
                        }
                        .buttonStyle(.bordered).tint(.gray)
                        .focused($actionFocus, equals: .favorite)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 20) {
                    metadata("DEVELOPER", game.developer)
                    metadata("PUBLISHER", game.publisher)
                    metadata("RATING", game.rating)
                }
            }.padding(80)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder private func metadata(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            VStack(alignment: .trailing, spacing: 3) {
                Text(label).font(.system(size: 20, weight: .bold)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 28)).foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder private func carouselArtwork(_ game: GameInfo) -> some View {
        if let value = game.heroBannerUrl, let url = URL(string: value) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase { image.resizable().aspectRatio(contentMode: .fill) }
                else { BoosteroidTheme.cardGradient }
            }
        } else { BoosteroidTheme.cardGradient }
    }
}
