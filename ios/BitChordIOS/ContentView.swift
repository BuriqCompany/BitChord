import SwiftUI
import UIKit

private enum BitChordStyle {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.055)
    static let accent = Color(red: 0.78, green: 0.67, blue: 0.98)
    static let muted = Color.white.opacity(0.58)
    static let card = Color.white.opacity(0.07)
}

private enum AppTab: String, CaseIterable {
    case home = "Beranda"
    case search = "Cari"
    case library = "Koleksi"

    var symbol: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .library: return "square.stack"
        }
    }
}

@MainActor
private final class YtMusicViewModel: ObservableObject {
    @Published var homeTracks: [YtMusicTrack] = []
    @Published var searchTracks: [YtMusicTrack] = []
    @Published var recentTracks: [YtMusicTrack] = []
    @Published var isLoadingHome = false
    @Published var isSearching = false
    @Published var alertMessage = ""
    @Published var showAlert = false

    private let client = YtMusicClient()
    private var homeTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var activeSearchQuery = ""

    func loadHomeIfNeeded() {
        guard homeTracks.isEmpty, !isLoadingHome else { return }
        isLoadingHome = true
        homeTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let tracks = try await client.searchSongs("trending songs")
                homeTracks = tracks
            } catch is CancellationError {
            } catch {
                present(error)
            }
            isLoadingHome = false
            homeTask = nil
        }
    }

    func retryHome() {
        homeTracks = []
        loadHomeIfNeeded()
    }

    func search(_ query: String) {
        activeSearchQuery = query
        searchTask?.cancel()
        searchTracks = []

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                let tracks = try await client.searchSongs(trimmedQuery)
                guard !Task.isCancelled, activeSearchQuery == query else { return }
                searchTracks = tracks
            } catch is CancellationError {
            } catch {
                if !Task.isCancelled {
                    present(error)
                }
            }
            if activeSearchQuery == query {
                isSearching = false
            }
        }
    }

    func remember(_ track: YtMusicTrack) {
        recentTracks.removeAll { $0.id == track.id }
        recentTracks.insert(track, at: 0)
    }

    private func present(_ error: Error) {
        alertMessage = error.localizedDescription
        showAlert = true
    }
}

struct ContentView: View {
    @StateObject private var model = YtMusicViewModel()
    @State private var selectedTab: AppTab = .home
    @State private var selectedTrack: YtMusicTrack?
    @State private var isShowingPlayer = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        tracks: model.homeTracks,
                        isLoading: model.isLoadingHome,
                        onRetry: model.retryHome,
                        onSelect: selectTrack
                    )
                case .search:
                    SearchView(model: model, onSelect: selectTrack)
                case .library:
                    LibraryView(tracks: model.recentTracks, onSelect: selectTrack)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let track = selectedTrack {
                MiniPlayer(track: track) {
                    isShowingPlayer = true
                } onOpenInYouTubeMusic: {
                    openInYouTubeMusic(track)
                }
            }

            BottomTabBar(selection: $selectedTab)
        }
        .background(BitChordStyle.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isShowingPlayer) {
            if let track = selectedTrack {
                NowPlayingView(track: track) {
                    isShowingPlayer = false
                } onOpenInYouTubeMusic: {
                    openInYouTubeMusic(track)
                }
            }
        }
        .alert(isPresented: $model.showAlert) {
            Alert(
                title: Text("YouTube Music"),
                message: Text(model.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear(perform: model.loadHomeIfNeeded)
    }

    private func selectTrack(_ track: YtMusicTrack) {
        selectedTrack = track
        model.remember(track)
        isShowingPlayer = true
    }

    private func openInYouTubeMusic(_ track: YtMusicTrack) {
        UIApplication.shared.open(track.watchURL)
    }
}

private struct HomeView: View {
    let tracks: [YtMusicTrack]
    let isLoading: Bool
    let onRetry: () -> Void
    let onSelect: (YtMusicTrack) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 25) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("BITCHORD")
                            .font(.caption.weight(.bold))
                            .tracking(2.2)
                            .foregroundColor(BitChordStyle.accent)
                        Text("Untuk kamu")
                            .font(.largeTitle.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "waveform")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(BlurView(style: .systemThinMaterialDark))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Trending di YouTube Music", detail: "Lagu")
                    if isLoading && tracks.isEmpty {
                        LoadingCard()
                    } else if tracks.isEmpty {
                        EmptyCatalogView(
                            title: "Belum ada lagu",
                            message: "Periksa koneksi lalu coba muat katalog lagi.",
                            actionTitle: "Coba lagi",
                            action: onRetry
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Array(tracks.prefix(6))) { track in
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
                                    .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
                                    .padding(6)
                                    .background(BlurView(style: .systemThinMaterialDark))
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }

                if !tracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Jelajahi lagu", detail: "\(tracks.count) hasil")
                        ForEach(tracks) { track in
                            TrackRow(track: track) {
                                onSelect(track)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
    }
}

private struct SearchView: View {
    @ObservedObject var model: YtMusicViewModel
    let onSelect: (YtMusicTrack) -> Void
    @State private var query = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Cari")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                HStack(spacing: 11) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(BitChordStyle.muted)
                    TextField("Lagu atau artis", text: $query)
                        .font(.body)
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if !query.isEmpty {
                        Button {
                            query = ""
                            model.search("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(BitChordStyle.muted)
                        }
                        .accessibilityLabel("Hapus pencarian")
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(BlurView(style: .systemThinMaterialDark))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }
                .onChange(of: query) { newValue in
                    model.search(newValue)
                }

                if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    Text("Cari katalog YouTube Music")
                        .font(.subheadline)
                        .foregroundColor(BitChordStyle.muted)
                        .padding(.top, 4)
                } else if model.isSearching && model.searchTracks.isEmpty {
                    LoadingCard()
                } else if model.searchTracks.isEmpty {
                    Text("Tidak ada hasil untuk pencarian ini.")
                        .font(.subheadline)
                        .foregroundColor(BitChordStyle.muted)
                        .padding(.vertical, 16)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Hasil lagu", detail: "\(model.searchTracks.count)")
                        ForEach(model.searchTracks) { track in
                            TrackRow(track: track) {
                                onSelect(track)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 26)
        }
    }
}

private struct LibraryView: View {
    let tracks: [YtMusicTrack]
    let onSelect: (YtMusicTrack) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("Koleksi")
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.white)

                if tracks.isEmpty {
                    EmptyCatalogView(
                        title: "Belum ada lagu",
                        message: "Lagu yang kamu pilih akan muncul di sini."
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeading(title: "Baru dipilih", detail: "\(tracks.count)")
                        ForEach(tracks) { track in
                            TrackRow(track: track) {
                                onSelect(track)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 26)
        }
    }
}

private struct NowPlayingView: View {
    let track: YtMusicTrack
    let onClose: () -> Void
    let onOpenInYouTubeMusic: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let artworkSize = min(geometry.size.width - 64, min(geometry.size.height * 0.39, 350))
            ZStack {
                BlurredArtworkBackdrop(track: track)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        HStack {
                            PlayerChromeButton(symbol: "chevron.down", action: onClose)
                                .accessibilityLabel("Tutup pemutar")
                            Spacer()
                            VStack(spacing: 4) {
                                Text("BITCHORD")
                                    .font(.caption.weight(.bold))
                                    .tracking(2.2)
                                    .foregroundColor(.white)
                                Text("YOUTUBE MUSIC")
                                    .font(.caption2.weight(.semibold))
                                    .tracking(1.2)
                                    .foregroundColor(BitChordStyle.muted)
                            }
                            Spacer()
                            PlayerChromeButton(symbol: "ellipsis", action: onOpenInYouTubeMusic)
                                .accessibilityLabel("Buka di YouTube Music")
                        }

                        ArtworkView(track: track, size: artworkSize)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.42), radius: 26, x: 0, y: 18)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(track.title)
                                        .font(.title2.weight(.bold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                    Text(track.artist)
                                        .font(.body)
                                        .foregroundColor(BitChordStyle.muted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "music.note")
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundColor(BitChordStyle.accent)
                                    .frame(width: 42, height: 42)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            }

                            Button(action: onOpenInYouTubeMusic) {
                                HStack(spacing: 12) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(BitChordStyle.background)
                                        .frame(width: 54, height: 54)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Putar di YouTube Music")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                        Text("Buka pemutar resmi untuk lagu ini")
                                            .font(.caption)
                                            .foregroundColor(BitChordStyle.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(BitChordStyle.muted)
                                }
                                .padding(12)
                                .background(BlurView(style: .systemThinMaterialDark))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(16)
                        .background(BlurView(style: .systemUltraThinMaterialDark))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.11), lineWidth: 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct MiniPlayer: View {
    let track: YtMusicTrack
    let onOpen: () -> Void
    let onOpenInYouTubeMusic: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    ArtworkView(track: track, size: 46)
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
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Buka pemutar")

            Button(action: onOpenInYouTubeMusic) {
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 46)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("Putar di YouTube Music")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(BlurView(style: .systemThinMaterialDark))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.13), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 5)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.1))
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
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .background(BlurView(style: .systemThinMaterialDark))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct BlurredArtworkBackdrop: View {
    let track: YtMusicTrack

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BitChordStyle.background
                if let url = track.artworkURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width * 1.35, height: geometry.size.height * 1.2)
                                .blur(radius: 48)
                                .clipped()
                        }
                    }
                }
                Color.black.opacity(0.22)
                BlurView(style: .systemUltraThinMaterialDark)
                LinearGradient(
                    colors: [
                        BitChordStyle.background.opacity(0.18),
                        BitChordStyle.background.opacity(0.42),
                        BitChordStyle.background.opacity(0.84)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct ArtworkView: View {
    let track: YtMusicTrack
    let size: CGFloat

    var body: some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.29, green: 0.23, blue: 0.47),
                    Color(red: 0.12, green: 0.16, blue: 0.27)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "waveform")
                .font(.system(size: size * 0.28, weight: .light))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

private struct TrackRow: View {
    let track: YtMusicTrack
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

private struct SectionHeading: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundColor(BitChordStyle.muted)
        }
    }
}

private struct EmptyCatalogView: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(BitChordStyle.muted)
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(BitChordStyle.accent)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BlurView(style: .systemThinMaterialDark))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct LoadingCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: BitChordStyle.accent))
            Text("Memuat katalog YouTube Music...")
                .font(.subheadline)
                .foregroundColor(BitChordStyle.muted)
            Spacer()
        }
        .padding(16)
        .background(BlurView(style: .systemThinMaterialDark))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct PlayerChromeButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(BlurView(style: .systemThinMaterialDark))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        if uiView.effect == nil {
            uiView.effect = UIBlurEffect(style: style)
        }
    }
}
