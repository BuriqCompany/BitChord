import SwiftUI

private enum BitChordStyle {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.082)
    static let surface = Color(red: 0.105, green: 0.115, blue: 0.145)
    static let accent = Color(red: 0.73, green: 0.61, blue: 0.96)
    static let muted = Color.white.opacity(0.62)
}

private struct Track: Identifiable {
    let id: String
    let title: String
    let artist: String
    let firstColor: Color
    let secondColor: Color

    static let samples = [
        Track(id: "midnight", title: "Midnight City", artist: "M83", firstColor: Color(red: 0.32, green: 0.24, blue: 0.74), secondColor: Color(red: 0.91, green: 0.38, blue: 0.62)),
        Track(id: "afterglow", title: "Afterglow", artist: "Ed Sheeran", firstColor: Color(red: 0.74, green: 0.31, blue: 0.25), secondColor: Color(red: 0.95, green: 0.66, blue: 0.33)),
        Track(id: "sunset", title: "Sunset Lover", artist: "Petit Biscuit", firstColor: Color(red: 0.23, green: 0.55, blue: 0.62), secondColor: Color(red: 0.76, green: 0.42, blue: 0.61)),
        Track(id: "slow-dancing", title: "Slow Dancing in the Dark", artist: "Joji", firstColor: Color(red: 0.27, green: 0.29, blue: 0.48), secondColor: Color(red: 0.70, green: 0.31, blue: 0.39)),
        Track(id: "space-song", title: "Space Song", artist: "Beach House", firstColor: Color(red: 0.18, green: 0.38, blue: 0.62), secondColor: Color(red: 0.57, green: 0.46, blue: 0.78)),
        Track(id: "golden", title: "Golden Hour", artist: "JVKE", firstColor: Color(red: 0.83, green: 0.49, blue: 0.25), secondColor: Color(red: 0.95, green: 0.77, blue: 0.46))
    ]
}

private enum AppTab: String, CaseIterable {
    case home = "Home"
    case search = "Search"
    case library = "Library"

    var symbol: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .library: return "square.stack"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var searchText = ""
    @State private var currentTrack = Track.samples[0]
    @State private var isPlaying = true
    @State private var isShowingPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(onSelect: selectTrack)
                case .search:
                    SearchView(searchText: $searchText, onSelect: selectTrack)
                case .library:
                    LibraryView(onSelect: selectTrack)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MiniPlayer(
                track: currentTrack,
                isPlaying: $isPlaying,
                onOpen: { isShowingPlayer = true }
            )

            BottomTabBar(selection: $selectedTab)
        }
        .background(BitChordStyle.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isShowingPlayer) {
            NowPlayingView(
                track: currentTrack,
                isPlaying: $isPlaying,
                onClose: { isShowingPlayer = false }
            )
        }
    }

    private func selectTrack(_ track: Track) {
        currentTrack = track
        isPlaying = true
        isShowingPlayer = true
    }
}

private struct HomeView: View {
    let onSelect: (Track) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                header
                featuredCard

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Quick picks", action: "See all")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(Track.samples.prefix(4))) { track in
                            Button {
                                onSelect(track)
                            } label: {
                                HStack(spacing: 10) {
                                    ArtworkView(track: track, size: 54)
                                    Text(track.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                .padding(6)
                                .background(Color.white.opacity(0.055))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Recently played", action: "View history")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(Track.samples) { track in
                                Button {
                                    onSelect(track)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ArtworkView(track: track, size: 142)
                                        Text(track.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.caption)
                                            .foregroundColor(BitChordStyle.muted)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 142, alignment: .leading)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("BITCHORD")
                    .font(.caption.weight(.bold))
                    .tracking(2.2)
                    .foregroundColor(BitChordStyle.accent)
                Text("Good evening")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button {} label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Profile")
        }
    }

    private var featuredCard: some View {
        Button {
            onSelect(Track.samples[0])
        } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color(red: 0.31, green: 0.24, blue: 0.64), Color(red: 0.12, green: 0.17, blue: 0.32)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "waveform")
                    .font(.system(size: 150, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.14))
                    .rotationEffect(.degrees(-12))
                    .offset(x: 125, y: -30)
                VStack(alignment: .leading, spacing: 8) {
                    Text("MADE FOR YOUR MIX")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.76))
                    Text("A little more\nof what you love.")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    Text("Your evening mix · 24 songs")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.72))
                }
                .padding(20)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct SearchView: View {
    @Binding var searchText: String
    let onSelect: (Track) -> Void

    private var filteredTracks: [Track] {
        guard !searchText.isEmpty else { return Track.samples }
        return Track.samples.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let genres = [
        ("Made for you", Color(red: 0.38, green: 0.27, blue: 0.68)),
        ("Pop", Color(red: 0.67, green: 0.31, blue: 0.41)),
        ("Chill", Color(red: 0.21, green: 0.45, blue: 0.53)),
        ("Focus", Color(red: 0.48, green: 0.39, blue: 0.25))
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Search")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(BitChordStyle.muted)
                    TextField("Artists, songs, albums", text: $searchText)
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Browse all")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(0..<genres.count, id: \.self) { index in
                                let genre = genres[index]
                                Text(genre.0)
                                    .font(.headline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottomLeading)
                                    .padding(14)
                                    .background(genre.1)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("RESULTS")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                            .foregroundColor(BitChordStyle.muted)
                        if filteredTracks.isEmpty {
                            Text("No matches yet")
                                .font(.body)
                                .foregroundColor(BitChordStyle.muted)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(filteredTracks) { track in
                                TrackRow(track: track) {
                                    onSelect(track)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }
}

private struct LibraryView: View {
    let onSelect: (Track) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Your Library")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {} label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Create a playlist")
                }

                VStack(spacing: 0) {
                    LibraryRow(symbol: "music.note.list", title: "Playlists", detail: "Your collections")
                    Divider().overlay(Color.white.opacity(0.08))
                    LibraryRow(symbol: "square.stack", title: "Albums", detail: "Saved albums")
                    Divider().overlay(Color.white.opacity(0.08))
                    LibraryRow(symbol: "person.2", title: "Artists", detail: "Followed artists")
                    Divider().overlay(Color.white.opacity(0.08))
                    LibraryRow(symbol: "arrow.down.circle", title: "Downloaded", detail: "Available offline")
                }
                .padding(.horizontal, 14)
                .background(BitChordStyle.surface.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Recently added", action: "Sort")
                    ForEach(Track.samples.prefix(4)) { track in
                        TrackRow(track: track) {
                            onSelect(track)
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }
}

private struct NowPlayingView: View {
    let track: Track
    @Binding var isPlaying: Bool
    let onClose: () -> Void
    @State private var progress = 0.36

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    HStack {
                        Button(action: onClose) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Close player")
                        Spacer()
                        VStack(spacing: 3) {
                            Text("NOW PLAYING")
                                .font(.caption2.weight(.bold))
                                .tracking(1.4)
                                .foregroundColor(BitChordStyle.muted)
                            Text("Playing from Quick picks")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Button {} label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("More options")
                    }

                    ArtworkView(track: track, size: min(geometry.size.width - 56, 340))
                        .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(track.title)
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.body)
                                    .foregroundColor(BitChordStyle.muted)
                            }
                            Spacer()
                            Button {} label: {
                                Image(systemName: "heart")
                                    .font(.system(size: 21))
                                    .foregroundColor(.white.opacity(0.82))
                            }
                            .accessibilityLabel("Add to favorites")
                        }

                        Slider(value: $progress)
                            .accentColor(BitChordStyle.accent)
                        HStack {
                            Text("1:42")
                            Spacer()
                            Text("4:18")
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(BitChordStyle.muted)
                        .padding(.top, -18)

                        HStack {
                            PlayerButton(symbol: "shuffle", size: 18) {}
                            Spacer()
                            PlayerButton(symbol: "backward.end.fill", size: 25) {}
                            Spacer()
                            Button {
                                isPlaying.toggle()
                            } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(BitChordStyle.background)
                                    .frame(width: 62, height: 62)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel(isPlaying ? "Pause" : "Play")
                            Spacer()
                            PlayerButton(symbol: "forward.end.fill", size: 25) {}
                            Spacer()
                            PlayerButton(symbol: "repeat", size: 18) {}
                        }
                        .padding(.vertical, 3)

                        HStack(spacing: 10) {
                            Image(systemName: "quote.opening")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(BitChordStyle.accent)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Waiting in the car")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                Text("A preview of synced lyrics")
                                    .font(.caption)
                                    .foregroundColor(BitChordStyle.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(BitChordStyle.muted)
                        }
                        .padding(14)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 30)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
            .background(BitChordStyle.background.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }
}

private struct MiniPlayer: View {
    let track: Track
    @Binding var isPlaying: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    ArtworkView(track: track, size: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.caption)
                            .foregroundColor(BitChordStyle.muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Open now playing")

            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 44)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button {} label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))
                    .frame(width: 32, height: 44)
            }
            .accessibilityLabel("Next track")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct BottomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 19, weight: selection == tab ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.caption2.weight(selection == tab ? .semibold : .regular))
                    }
                    .foregroundColor(selection == tab ? BitChordStyle.accent : BitChordStyle.muted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct ArtworkView: View {
    let track: Track
    let size: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [track.firstColor, track.secondColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: size * 0.72, height: size * 0.72)
            Circle()
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
                .frame(width: size * 0.48, height: size * 0.48)
            Image(systemName: "waveform")
                .font(.system(size: size * 0.26, weight: .light))
                .foregroundColor(.white.opacity(0.84))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct TrackRow: View {
    let track: Track
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ArtworkView(track: track, size: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(BitChordStyle.muted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundColor(BitChordStyle.muted)
                    .frame(width: 32, height: 44)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct LibraryRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundColor(BitChordStyle.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(BitChordStyle.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(BitChordStyle.muted)
        }
        .padding(.vertical, 14)
    }
}

private struct SectionHeading: View {
    let title: String
    let action: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Spacer()
            Button {
            } label: {
                Text(action)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(BitChordStyle.muted)
            }
        }
    }
}

private struct PlayerButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white.opacity(0.84))
                .frame(minWidth: 30, minHeight: 44)
        }
    }
}
