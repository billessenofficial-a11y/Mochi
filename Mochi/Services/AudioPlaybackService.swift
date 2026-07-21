@preconcurrency import AVFoundation
import Foundation

@MainActor
final class AudioPlaybackService: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var loadedURL: URL?
    private var progressTask: Task<Void, Never>?

    func load(_ url: URL) throws {
        guard loadedURL != url else { return }
        stop()
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        self.player = player
        loadedURL = url
        duration = player.duration
        currentTime = 0
    }

    func toggle(url: URL) {
        do {
            try load(url)
            if isPlaying {
                pause()
            } else {
                play()
            }
        } catch {
            stop()
        }
    }

    func play(url: URL, from time: TimeInterval) {
        do {
            try load(url)
            player?.currentTime = min(max(0, time), duration)
            currentTime = player?.currentTime ?? 0
            play()
        } catch {
            stop()
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = min(max(0, time), duration)
        currentTime = player?.currentTime ?? 0
    }

    func pause() {
        player?.pause()
        isPlaying = false
        progressTask?.cancel()
        progressTask = nil
    }

    func stop() {
        progressTask?.cancel()
        progressTask = nil
        player?.stop()
        player = nil
        loadedURL = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    private func play() {
        guard let player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        isPlaying = true

        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.isPlaying = false
                    return
                }
            }
        }
    }
}
