import SwiftUI
import AVFoundation
import Combine
import UniformTypeIdentifiers
import UIKit

private enum BitChordStyle {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.055)
    static let surface = Color(red: 0.105, green: 0.11, blue: 0.135)
    static let accent = Color(red: 0.78, green: 0.67, blue: 0.98)
    static let muted = Color.white.opacity(0.58)
}

private struct Track: Identifiable {
    let id: String
    let title: String
    let artist: String
    let firstColor: Color
    let secondColor: Color
    var audioURL: URL? = nil
    var duration: Double? = nil
    var artwork: UIImage? = nil

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
    @State private var importedTracks: [Track] = []
    @State private var currentTrack: Track?
    @State private var audioPlayer = AVPlayer()
    @State private var isPlaying = false
    @State private var elapsed: Double = 0
    @State private var hasLoadedLibrary = false
    @State private var isShowingPlayer = false
    @State private var isShowingImporter = false
    @State private var isShowingImportError = false
    @State private var importError = ""
    @State private var nextArtworkColor = 0

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(
                        tracks: importedTracks,
                        onSelect: selectTrack,
                        onImport: { isShowingImporter = true }
                    )
                case .search:
                    SearchView(
                        searchText: $searchText,
                        tracks: importedTracks,
                        onSelect: selectTrack
                    )
                case .library:
                    LibraryView(
                        tracks: importedTracks,
                        onSelect: selectTrack,
                        onImport: { isShowingImporter = true }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let currentTrack = currentTrack {
                MiniPlayer(
                    track: currentTrack,
                    isPlaying: isPlaying,
                    progress: playbackProgress,
                    onOpen: { isShowingPlayer = true },
                    onTogglePlay: togglePlayback,
                    onNext: playNextTrack
                )
            }

            BottomTabBar(selection: $selectedTab)
        }
        .background(BitChordStyle.background.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $isShowingPlayer) {
            if let currentTrack = currentTrack {
                NowPlayingView(
                    track: currentTrack,
                    isPlaying: isPlaying,
                    elapsed: elapsed,
                    duration: currentTrack.duration ?? 0,
                    onClose: { isShowingPlayer = false },
                    onTogglePlay: togglePlayback,
                    onSeek: seek,
                    onNext: playNextTrack,
                    onPrevious: playPreviousTrack,
                    onImport: importFromPlayer
                )
            }
        }
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true,
            onCompletion: importAudio
        )
        .alert("Tidak dapat mengimpor lagu", isPresented: $isShowingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError)
        }
        .onAppear(perform: loadImportedTracks)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            guard isPlaying else { return }
            let currentTime = audioPlayer.currentTime().seconds
            if currentTime.isFinite {
                elapsed = currentTime
            }
        }
    }

    private func selectTrack(_ track: Track) {
        currentTrack = track
        elapsed = 0
        if let audioURL = track.audioURL {
            do {
                try prepareAudioSession()
                audioPlayer.replaceCurrentItem(with: AVPlayerItem(url: audioURL))
                audioPlayer.play()
                isPlaying = true
            } catch {
                presentPlaybackError(error)
            }
        } else {
            audioPlayer.pause()
            audioPlayer.replaceCurrentItem(with: nil)
            isPlaying = false
        }
        isShowingPlayer = true
    }

    private var playbackProgress: Double {
        guard let duration = currentTrack?.duration, duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    private func togglePlayback() {
        guard let audioURL = currentTrack?.audioURL else {
            importFromPlayer()
            return
        }
        do {
            if isPlaying {
                audioPlayer.pause()
            } else {
                try prepareAudioSession()
                if audioPlayer.currentItem == nil {
                    audioPlayer.replaceCurrentItem(with: AVPlayerItem(url: audioURL))
                }
                audioPlayer.play()
            }
            isPlaying.toggle()
        } catch {
            presentPlaybackError(error)
        }
    }

    private func prepareAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func presentPlaybackError(_ error: Error) {
        importError = error.localizedDescription
        isShowingImportError = true
        isPlaying = false
    }

    private func seek(to progress: Double) {
        guard let duration = currentTrack?.duration, duration > 0 else { return }
        elapsed = duration * min(max(progress, 0), 1)
        audioPlayer.seek(to: CMTime(seconds: elapsed, preferredTimescale: 600))
    }

    private func playNextTrack() {
        guard !importedTracks.isEmpty else {
            importFromPlayer()
            return
        }
        let currentIndex = importedTracks.firstIndex(where: { $0.id == currentTrack?.id }) ?? -1
        selectTrack(importedTracks[(currentIndex + 1) % importedTracks.count])
    }

    private func playPreviousTrack() {
        guard !importedTracks.isEmpty else {
            importFromPlayer()
            return
        }
        let currentIndex = importedTracks.firstIndex(where: { $0.id == currentTrack?.id }) ?? 0
        let previousIndex = (currentIndex - 1 + importedTracks.count) % importedTracks.count
        selectTrack(importedTracks[previousIndex])
    }

    private func importFromPlayer() {
        isShowingPlayer = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isShowingImporter = true
        }
    }

    private func loadImportedTracks() {
        guard !hasLoadedLibrary else { return }
        hasLoadedLibrary = true
        let folder = musicFolder
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else { return }

        importedTracks = files
            .filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .audio) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map(makeTrack(from:))
    }

    private var musicFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Music", isDirectory: true)
    }

    private func importAudio(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            do {
                try FileManager.default.createDirectory(
                    at: musicFolder,
                    withIntermediateDirectories: true
                )
                var newlyImported: [Track] = []
                for source in urls {
                    let hasAccess = source.startAccessingSecurityScopedResource()
                    defer {
                        if hasAccess {
                            source.stopAccessingSecurityScopedResource()
                        }
                    }
                    var destination = musicFolder.appendingPathComponent(source.lastPathComponent)
                    if FileManager.default.fileExists(atPath: destination.path) {
                        destination = musicFolder
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension(source.pathExtension)
                    }
                    try FileManager.default.copyItem(at: source, to: destination)
                    let track = makeTrack(from: destination)
                    newlyImported.append(track)
                    importedTracks.append(track)
                }
                if let firstTrack = newlyImported.first {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectTrack(firstTrack)
                    }
                }
            } catch {
                importError = error.localizedDescription
                isShowingImportError = true
            }
        case .failure(let error):
            importError = error.localizedDescription
            isShowingImportError = true
        }
    }

    private func makeTrack(from url: URL) -> Track {
        let asset = AVURLAsset(url: url)
        let metadata = asset.commonMetadata
        let title = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierTitle
        ).first?.stringValue ?? url.deletingPathExtension().lastPathComponent
        let artist = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierArtist
        ).first?.stringValue ?? "Unknown artist"
        let artwork = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierArtwork
        ).first?.dataValue.flatMap(UIImage.init(data:))
        let duration = asset.duration.seconds
        let colors = [
            (Color(red: 0.38, green: 0.25, blue: 0.63), Color(red: 0.87, green: 0.4, blue: 0.57)),
            (Color(red: 0.2, green: 0.43, blue: 0.54), Color(red: 0.54, green: 0.69, blue: 0.71)),
            (Color(red: 0.66, green: 0.35, blue: 0.23), Color(red: 0.93, green: 0.68, blue: 0.4)),
            (Color(red: 0.24, green: 0.34, blue: 0.55), Color(red: 0.58, green: 0.43, blue: 0.73))
        ]
        let color = colors[nextArtworkColor % colors.count]
        nextArtworkColor += 1
        return Track(
            id: url.absoluteString,
            title: title,
            artist: artist,
            firstColor: color.0,
            secondColor: color.1,
            audioURL: url,
            duration: duration.isFinite ? duration : nil,
            artwork: artwork
        )
    }
}

private struct HomeView: View {
    let tracks: [Track]
    let onSelect: (Track) -> Void
    let onImport: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                header
                musicSection
                featuredCard

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Explore the look", action: "UI demo")
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Track.samples) { track in
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
                    SectionHeading(title: "Sample artwork", action: "Not playable")
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

    private var musicSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeading(title: "Your music", action: "\(tracks.count) songs")
            }
            if tracks.isEmpty {
                Button(action: onImport) {
                    HStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(BitChordStyle.background)
                            .frame(width: 42, height: 42)
                            .background(BitChordStyle.accent)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add songs from Files")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Text("Import audio stored on your iPhone")
                                .font(.caption)
                                .foregroundColor(BitChordStyle.muted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(BitChordStyle.muted)
                    }
                    .padding(14)
                    .background(BlurView(style: .systemThinMaterialDark))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                VStack(spacing: 13) {
                    ForEach(tracks.prefix(3)) { track in
                        TrackRow(track: track) {
                            onSelect(track)
                        }
                    }
                    if tracks.count > 3 {
                        Text("+ \(tracks.count - 3) more songs in Library")
                            .font(.caption)
                            .foregroundColor(BitChordStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
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
                    Text("Album-color player · iOS 15")
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
    let tracks: [Track]
    let onSelect: (Track) -> Void

    private var filteredTracks: [Track] {
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter {
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
                    if !tracks.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeading(title: "Your songs", action: "\(tracks.count) tracks")
                            ForEach(tracks) { track in
                                TrackRow(track: track) {
                                    onSelect(track)
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("YOUR SONGS")
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
    let tracks: [Track]
    let onSelect: (Track) -> Void
    let onImport: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Your Library")
                        .font(.largeTitle.weight(.bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onImport) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Import songs")
                }

                VStack(spacing: 0) {
                    LibraryRow(symbol: "music.note.list", title: "Songs", detail: "\(tracks.count) imported")
                }
                .padding(.horizontal, 14)
                .background(BitChordStyle.surface.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading(title: "Your songs", action: "\(tracks.count)")
                    if tracks.isEmpty {
                        Button(action: onImport) {
                            HStack(spacing: 14) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 22))
                                    .foregroundColor(BitChordStyle.accent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Import your music")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                    Text("Choose audio files stored on your iPhone.")
                                        .font(.caption)
                                        .foregroundColor(BitChordStyle.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(BitChordStyle.muted)
                            }
                            .padding(16)
                            .background(BlurView(style: .systemThinMaterialDark))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        ForEach(tracks) { track in
                            TrackRow(track: track) {
                                onSelect(track)
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

private struct NowPlayingView: View {
    let track: Track
    let isPlaying: Bool
    let elapsed: Double
    let duration: Double
    let onClose: () -> Void
    let onTogglePlay: () -> Void
    let onSeek: (Double) -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onImport: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BlurredArtworkBackdrop(track: track)

                LinearGradient(
                    stops: [
                        .init(color: BitChordStyle.background.opacity(0.12), location: 0),
                        .init(color: BitChordStyle.background.opacity(0.26), location: 0.48),
                        .init(color: BitChordStyle.background.opacity(0.72), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        HStack {
                            PlayerChromeButton(symbol: "chevron.down", action: onClose)
                                .accessibilityLabel("Close player")
                            Spacer()
                            VStack(spacing: 4) {
                                Text("BITCHORD")
                                    .font(.caption.weight(.bold))
                                    .tracking(2.2)
                                    .foregroundColor(.white)
                                Text(track.audioURL == nil ? "DESIGN PREVIEW" : "NOW PLAYING")
                                    .font(.caption2.weight(.semibold))
                                    .tracking(1.2)
                                    .foregroundColor(BitChordStyle.muted)
                            }
                            Spacer()
                            PlayerChromeButton(symbol: "ellipsis", action: {})
                                .accessibilityLabel("More options")
                        }

                        ArtworkView(
                            track: track,
                            size: min(geometry.size.width - 68, min(geometry.size.height * 0.37, 330))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.38), radius: 25, x: 0, y: 18)
                        .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 16) {
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
                            Button(action: {}) {
                                Image(systemName: "heart")
                                    .font(.system(size: 21))
                                    .foregroundColor(.white.opacity(0.82))
                            }
                            .accessibilityLabel("Add to favorites")
                        }

                        VStack(spacing: 2) {
                            Slider(
                                value: Binding(
                                    get: { duration > 0 ? min(max(elapsed / duration, 0), 1) : 0 },
                                    set: onSeek
                                ),
                                in: 0...1
                            )
                            .accentColor(BitChordStyle.accent)
                            .disabled(duration <= 0)
                            HStack {
                                Text(timeString(elapsed))
                                Spacer()
                                Text(duration > 0 ? timeString(duration) : "--:--")
                            }
                            .font(.caption2.monospacedDigit())
                            .foregroundColor(BitChordStyle.muted)
                        }

                        HStack {
                            PlayerButton(symbol: "shuffle", size: 18, action: {})
                            Spacer()
                            PlayerButton(symbol: "backward.end.fill", size: 24, action: onPrevious)
                            Spacer()
                            Button {
                                onTogglePlay()
                            } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(BitChordStyle.background)
                                    .frame(width: 62, height: 62)
                                    .background(Color.white)
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel(track.audioURL == nil ? "Import a song to play" : (isPlaying ? "Pause" : "Play"))
                            Spacer()
                            PlayerButton(symbol: "forward.end.fill", size: 24, action: onNext)
                            Spacer()
                            PlayerButton(symbol: "repeat", size: 18, action: {})
                        }
                        .padding(.vertical, 3)

                        if let audioURL = track.audioURL {
                            HStack(spacing: 10) {
                                Image(systemName: "waveform")
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(BitChordStyle.accent)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("On this iPhone")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                    Text(audioURL.lastPathComponent)
                                        .font(.caption)
                                        .foregroundColor(BitChordStyle.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "hifispeaker")
                                    .foregroundColor(BitChordStyle.muted)
                            }
                            .padding(14)
                            .background(BlurView(style: .systemThinMaterialDark))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        } else {
                            Button(action: onImport) {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.badge.plus")
                                        .font(.title3)
                                        .foregroundColor(BitChordStyle.accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Artwork preview only")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(.white)
                                        Text("Import an audio file to listen.")
                                            .font(.caption)
                                            .foregroundColor(BitChordStyle.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(BitChordStyle.muted)
                                }
                                .padding(14)
                                .background(BlurView(style: .systemThinMaterialDark))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(BlurView(style: .systemUltraThinMaterialDark))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                    .padding(.bottom, 28)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}

private struct MiniPlayer: View {
    let track: Track
    let isPlaying: Bool
    let progress: Double
    let onOpen: () -> Void
    let onTogglePlay: () -> Void
    let onNext: () -> Void

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
                onTogglePlay()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 44)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button(action: onNext) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.88))
                    .frame(width: 32, height: 44)
            }
            .accessibilityLabel("Next track")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(BlurView(style: .systemThinMaterialDark))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .overlay(alignment: .bottomLeading) {
            GeometryReader { geometry in
                Capsule()
                    .fill(BitChordStyle.accent)
                    .frame(width: geometry.size.width * progress, height: 2)
                    .offset(x: 12, y: -7)
            }
            .allowsHitTesting(false)
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
        .background(BlurView(style: .systemThinMaterialDark))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct BlurredArtworkBackdrop: View {
    let track: Track

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BitChordStyle.background
                ArtworkView(
                    track: track,
                    size: max(geometry.size.width, geometry.size.height) * 1.15
                )
                .blur(radius: 56)
                .scaleEffect(1.35)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
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
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ArtworkView: View {
    let track: Track
    let size: CGFloat

    var body: some View {
        ZStack {
            if let artwork = track.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [track.firstColor, track.secondColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
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
        .clipped()
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
