import AVFoundation
import BitChordShared
import Combine
import Foundation

@MainActor
final class IOSPlaybackController: ObservableObject {
    @Published private(set) var track: YtMusicTrack?
    @Published private(set) var isResolving = false
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var sponsorBlockStatus = "Memuat SponsorBlock..."
    @Published private(set) var playbackError: String?

    private let player = AVPlayer()
    private let resolver = IOSStreamResolver()
    private let sponsorBlock = SponsorBlockClient()
    private var timeObserver: Any?
    private var playerObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var sponsorTask: Task<Void, Never>?
    private var currentRequest = 0
    private var segments: [SponsorBlockSegment] = []
    private var skippedSegments = Set<String>()

    init() {
        player.automaticallyWaitsToMinimizeStalling = true
        playerObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.isPlaying = player.timeControlStatus == .playing
                self?.isBuffering = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, time.isNumeric else { return }
            self.currentTime = time.seconds
            let itemDuration = self.player.currentItem?.duration.seconds ?? 0
            self.duration = itemDuration.isFinite ? max(itemDuration, 0) : 0
            self.skipSponsorSegmentIfNeeded(at: time.seconds)
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    func play(_ track: YtMusicTrack) {
        currentRequest += 1
        let requestID = currentRequest
        self.track = track
        playbackError = nil
        isResolving = true
        isPlaying = false
        isBuffering = true
        currentTime = 0
        duration = 0
        segments = []
        skippedSegments.removeAll()
        sponsorTask?.cancel()
        player.pause()
        player.replaceCurrentItem(with: nil)

        sponsorTask = Task { [weak self] in
            do {
                let fetchedSegments = try await sponsorBlock.segments(for: track.id)
                guard let self, self.currentRequest == requestID, !Task.isCancelled else { return }
                segments = fetchedSegments
                sponsorBlockStatus = fetchedSegments.isEmpty
                    ? "SponsorBlock aktif · tidak ada segmen"
                    : "SponsorBlock aktif · \(fetchedSegments.count) segmen"
            } catch is CancellationError {
            } catch {
                guard let self, self.currentRequest == requestID, !Task.isCancelled else { return }
                sponsorBlockStatus = "SponsorBlock tidak tersedia: \(error.localizedDescription)"
            }
        }

        let locale = Locale.current
        resolver.resolve(
            videoId: track.id,
            region: locale.regionCode ?? "US",
            language: locale.languageCode ?? "en"
        ) { [weak self] stream, errorMessage in
            Task { @MainActor [weak self] in
                guard let self, self.currentRequest == requestID else { return }
                if let errorMessage {
                    isResolving = false
                    isBuffering = false
                    playbackError = errorMessage
                    return
                }
                guard let stream else {
                    isResolving = false
                    isBuffering = false
                    playbackError = "YouTube did not return a playable audio stream."
                    return
                }
                startPlayback(stream)
            }
        }
    }

    func togglePlayback() {
        guard !isResolving else { return }
        if isPlaying {
            player.pause()
        } else if player.currentItem != nil {
            player.play()
        } else if let track {
            play(track)
        }
    }

    func seek(to progress: Double) {
        guard duration > 0 else { return }
        skippedSegments.removeAll()
        let target = duration * min(max(progress, 0), 1)
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    private func startPlayback(_ stream: IOSResolvedStream) {
        guard let url = URL(string: stream.url) else {
            isResolving = false
            isBuffering = false
            playbackError = "YouTube returned an invalid audio URL."
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            isResolving = false
            isBuffering = false
            playbackError = error.localizedDescription
            return
        }

        let asset = AVURLAsset(
            url: url,
            options: ["AVURLAssetHTTPHeaderFieldsKey": stream.headers]
        )
        let item = AVPlayerItem(asset: asset)
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                isResolving = false
                isBuffering = false
                playbackError = item.error?.localizedDescription ?? "The audio stream could not be played."
            }
        }
        player.replaceCurrentItem(with: item)
        isResolving = false
        player.play()
    }

    private func skipSponsorSegmentIfNeeded(at time: Double) {
        guard isPlaying else { return }
        guard let segment = segments.first(where: {
            !skippedSegments.contains($0.id) && time >= $0.start && time < $0.end
        }) else {
            return
        }
        skippedSegments.insert(segment.id)
        player.seek(
            to: CMTime(seconds: segment.end + 0.1, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }
}
