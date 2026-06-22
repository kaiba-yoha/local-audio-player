import Foundation
import AVFoundation
import MediaPlayer
import Combine

enum LoopMode: String, CaseIterable {
    case one = "Loop"
    case all = "All"
    case none = "None"
}

@MainActor
final class AudioPlayerViewModel: ObservableObject {
    // MARK: - Published state
    @Published var tracks: [Track] = []
    @Published var currentIndex: Int = -1
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var loopMode: LoopMode = .one
    @Published var playbackSpeed: Float = 1.0
    @Published var sleepMinutes: Int = 0
    @Published var sleepRemaining: TimeInterval = 0
    @Published var sleepStatusText: String = ""

    // MARK: - Private
    private var player: AVAudioPlayer?
    private var timeTimer: Timer?
    private var sleepTimer: Timer?
    private var sleepEndDate: Date?

    var currentTrack: Track? {
        guard currentIndex >= 0, currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    let sleepOptions: [Int] = [0, 15, 30, 60]

    init() {
        configureAudioSession()
        setupRemoteCommands()
    }

    // MARK: - Audio Session
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    // MARK: - File Import
    func importFiles(urls: [URL]) {
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            let name = url.deletingPathExtension().lastPathComponent

            // Copy to app sandbox for reliable access
            let dest = copyToSandbox(url: url)
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }

            guard let dest else { continue }

            var track = Track(name: name, url: dest, duration: nil, isSecurityScoped: false)

            // Read duration
            if let audio = try? AVAudioPlayer(contentsOf: dest) {
                track.duration = audio.duration
            }

            tracks.append(track)
        }

        if currentIndex == -1 && !tracks.isEmpty {
            loadTrack(at: 0)
        }
    }

    private func copyToSandbox(url: URL) -> URL? {
        let fm = FileManager.default
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AudioFiles", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let dest = dir.appendingPathComponent(url.lastPathComponent)
        // Remove existing copy
        try? fm.removeItem(at: dest)

        do {
            try fm.copyItem(at: url, to: dest)
            return dest
        } catch {
            print("Copy error: \(error)")
            return nil
        }
    }

    // MARK: - Track Loading
    func loadTrack(at index: Int) {
        guard index >= 0, index < tracks.count else { return }
        stopTimeUpdates()

        currentIndex = index
        let track = tracks[index]

        do {
            player = try AVAudioPlayer(contentsOf: track.url)
            player?.enableRate = true
            player?.rate = playbackSpeed
            player?.delegate = PlayerDelegate.shared
            player?.prepareToPlay()
            totalDuration = player?.duration ?? 0
            currentTime = 0

            // Update track duration if we didn't have it
            if tracks[index].duration == nil {
                tracks[index].duration = totalDuration
            }

            PlayerDelegate.shared.onFinish = { [weak self] in
                Task { @MainActor in
                    self?.trackDidFinish()
                }
            }

            updateNowPlaying()
        } catch {
            print("Load error: \(error)")
        }
    }

    // MARK: - Playback Controls
    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimeUpdates()
        } else {
            player.play()
            isPlaying = true
            startTimeUpdates()
        }
        updateNowPlaying()
    }

    func play() {
        player?.play()
        isPlaying = true
        startTimeUpdates()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimeUpdates()
        updateNowPlaying()
    }

    func skipBackward() {
        guard let player else { return }
        player.currentTime = max(0, player.currentTime - 15)
        currentTime = player.currentTime
        updateNowPlaying()
    }

    func skipForward() {
        guard let player else { return }
        player.currentTime = min(player.duration, player.currentTime + 15)
        currentTime = player.currentTime
        updateNowPlaying()
    }

    func previousTrack() {
        guard let player else { return }
        if player.currentTime > 3 {
            player.currentTime = 0
            currentTime = 0
        } else if currentIndex > 0 {
            loadTrack(at: currentIndex - 1)
            play()
        }
        updateNowPlaying()
    }

    func nextTrack() {
        if currentIndex < tracks.count - 1 {
            loadTrack(at: currentIndex + 1)
            play()
        } else if loopMode == .all {
            loadTrack(at: 0)
            play()
        }
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        let time = fraction * player.duration
        player.currentTime = time
        currentTime = time
        updateNowPlaying()
    }

    // MARK: - Track finished
    private func trackDidFinish() {
        switch loopMode {
        case .one:
            player?.currentTime = 0
            player?.play()
            currentTime = 0
        case .all:
            let next = (currentIndex + 1) % tracks.count
            loadTrack(at: next)
            play()
        case .none:
            if currentIndex < tracks.count - 1 {
                loadTrack(at: currentIndex + 1)
                play()
            } else {
                isPlaying = false
                stopTimeUpdates()
            }
        }
        updateNowPlaying()
    }

    // MARK: - Loop Mode
    func setLoopMode(_ mode: LoopMode) {
        loopMode = (loopMode == mode) ? .none : mode
    }

    // MARK: - Speed
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.rate = speed
    }

    // MARK: - Sleep Timer
    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        if minutes == 0 {
            sleepMinutes = 0
            return
        }

        sleepMinutes = minutes
        sleepEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSleepCountdown()
            }
        }
    }

    private func updateSleepCountdown() {
        guard let endDate = sleepEndDate else { return }
        let remaining = endDate.timeIntervalSinceNow
        if remaining <= 0 {
            pause()
            cancelSleepTimer()
            sleepStatusText = NSLocalizedString("sleep.stopped", comment: "")
            return
        }
        sleepRemaining = remaining
        let mins = Int(ceil(remaining / 60))
        sleepStatusText = String(format: NSLocalizedString("sleep.remaining", comment: ""), mins)
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepEndDate = nil
        sleepMinutes = 0
        sleepRemaining = 0
        sleepStatusText = ""
    }

    // MARK: - Playlist Management
    func deleteTrack(at index: Int) {
        let track = tracks[index]
        // Clean up sandbox copy
        try? FileManager.default.removeItem(at: track.url)

        tracks.remove(at: index)
        if tracks.isEmpty {
            currentIndex = -1
            player?.stop()
            player = nil
            isPlaying = false
            stopTimeUpdates()
        } else if index == currentIndex {
            let next = min(index, tracks.count - 1)
            loadTrack(at: next)
        } else if index < currentIndex {
            currentIndex -= 1
        }
    }

    func moveTrack(from source: IndexSet, to destination: Int) {
        var updatedTracks = tracks
        updatedTracks.move(fromOffsets: source, toOffset: destination)

        // Recalculate currentIndex
        if let sourceIdx = source.first {
            if sourceIdx == currentIndex {
                if destination > sourceIdx {
                    currentIndex = destination - 1
                } else {
                    currentIndex = destination
                }
            } else if sourceIdx < currentIndex && destination > currentIndex {
                currentIndex -= 1
            } else if sourceIdx > currentIndex && destination <= currentIndex {
                currentIndex += 1
            }
        }

        tracks = updatedTracks
    }

    func selectTrack(at index: Int) {
        loadTrack(at: index)
        play()
    }

    // MARK: - Time Updates
    private func startTimeUpdates() {
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopTimeUpdates() {
        timeTimer?.invalidate()
        timeTimer = nil
    }

    // MARK: - Now Playing (Lock Screen)
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.nextTrack() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previousTrack() }
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipForward() }
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipBackward() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.player?.currentTime = event.positionTime
                self?.currentTime = event.positionTime
                self?.updateNowPlaying()
            }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack, let player else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.name,
            MPMediaItemPropertyArtist: "Local Audio Player",
            MPMediaItemPropertyPlaybackDuration: player.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackSpeed) : 0.0,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - AVAudioPlayerDelegate
private class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerDelegate()
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}
