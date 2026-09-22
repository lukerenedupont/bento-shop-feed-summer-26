import AVFoundation
import Observation
import SwiftUI
import UIKit

public enum ShopLoopingVideoContentMode: Sendable {
    case fill
    case fit

    var videoGravity: AVLayerVideoGravity {
        switch self {
        case .fill:
            .resizeAspectFill
        case .fit:
            .resizeAspect
        }
    }
}

@MainActor
@Observable
private final class ShopLoopingVideoPlayer {
    let player = AVQueuePlayer()

    private(set) var isReadyToPlay = false

    private var currentURL: URL?
    private var looper: AVPlayerLooper?
    @ObservationIgnored nonisolated(unsafe) private var currentItemObservation: NSKeyValueObservation?
    @ObservationIgnored nonisolated(unsafe) private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored nonisolated(unsafe) private var timeControlObservation: NSKeyValueObservation?

    init() {
        player.actionAtItemEnd = .none
        // This primitive is for silent, decorative looping video only. Keeping the
        // player muted (and expecting audio-free assets) avoids activating an
        // audio session that could interrupt/duck the user's background audio.
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.preventsDisplaySleepDuringVideoPlayback = false

        currentItemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.observeCurrentItemStatus()
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { player, _ in
            let isPlaying = player.timeControlStatus == .playing

            Task { @MainActor [weak self, isPlaying] in
                if isPlaying {
                    self?.isReadyToPlay = true
                }
            }
        }
    }

    func configure(url: URL) {
        guard currentURL != url else {
            return
        }

        currentURL = url
        isReadyToPlay = false
        statusObservation?.invalidate()
        statusObservation = nil
        tearDownPlaybackQueue()

        let item = AVPlayerItem(url: url)
        looper = AVPlayerLooper(player: player, templateItem: item)
        observeCurrentItemStatus()
    }

    func play() {
        player.isMuted = true
        player.play()
    }

    func pause() {
        player.pause()
    }

    func reset() {
        currentURL = nil
        isReadyToPlay = false
        statusObservation?.invalidate()
        statusObservation = nil
        tearDownPlaybackQueue()
    }

    private func tearDownPlaybackQueue() {
        looper?.disableLooping()
        player.pause()
        player.removeAllItems()
        looper = nil
    }

    private func observeCurrentItemStatus() {
        statusObservation?.invalidate()
        statusObservation = nil

        guard let currentItem = player.currentItem else {
            isReadyToPlay = false
            return
        }

        updateReadiness(from: currentItem)
        statusObservation = currentItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            let isReady = item.status == .readyToPlay

            Task { @MainActor [weak self, isReady] in
                self?.isReadyToPlay = isReady || self?.player.timeControlStatus == .playing
            }
        }
    }

    private func updateReadiness(from item: AVPlayerItem) {
        isReadyToPlay = item.status == .readyToPlay || player.timeControlStatus == .playing
    }

    deinit {
        // Only invalidate KVO here. `deinit` is nonisolated, so we must not call
        // AVPlayer control APIs (main-thread-affined) off-actor. Playback is
        // already stopped via `onDisappear`/`reset()` on the main actor.
        currentItemObservation?.invalidate()
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
    }
}

public struct ShopLoopingVideo<Placeholder: View>: View {
    private let url: URL?
    private let isVisible: Bool
    private let contentMode: ShopLoopingVideoContentMode
    private let minimumViewTimeNanoseconds: UInt64
    private let isAccessibilityHidden: Bool
    private let placeholder: Placeholder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var player = ShopLoopingVideoPlayer()
    @State private var pendingPlayTask: Task<Void, Never>?

    private var canLoadVideo: Bool {
        reduceMotion == false && url != nil
    }

    private var shouldPlay: Bool {
        canLoadVideo && isVisible && scenePhase == .active
    }

    public init(
        url: URL?,
        isVisible: Bool = true,
        contentMode: ShopLoopingVideoContentMode = .fill,
        minimumViewTimeNanoseconds: UInt64 = 250_000_000,
        isAccessibilityHidden: Bool = true,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.isVisible = isVisible
        self.contentMode = contentMode
        self.minimumViewTimeNanoseconds = minimumViewTimeNanoseconds
        self.isAccessibilityHidden = isAccessibilityHidden
        self.placeholder = placeholder()
    }

    public var body: some View {
        ZStack {
            if player.isReadyToPlay == false || reduceMotion || url == nil {
                placeholder
            }

            if reduceMotion == false,
               url != nil {
                ShopLoopingVideoPlayerLayerView(
                    player: player.player,
                    videoGravity: contentMode.videoGravity
                )
                .opacity(player.isReadyToPlay ? 1 : 0)
            }
        }
        .clipped()
        .accessibilityHidden(isAccessibilityHidden)
        .onChange(of: url, initial: true) { _, _ in
            updatePlayback()
        }
        .onChange(of: reduceMotion) { _, _ in
            updatePlayback()
        }
        .onChange(of: shouldPlay, initial: true) { _, _ in
            updatePlayback()
        }
        .onDisappear {
            pendingPlayTask?.cancel()
            pendingPlayTask = nil
            player.pause()
        }
    }

    private func configurePlayer() {
        guard let url else {
            return
        }

        player.configure(url: url)
    }

    private func updatePlayback() {
        pendingPlayTask?.cancel()
        pendingPlayTask = nil

        guard canLoadVideo else {
            player.reset()
            return
        }

        configurePlayer()

        guard shouldPlay else {
            player.pause()
            return
        }

        pendingPlayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: minimumViewTimeNanoseconds)
            guard Task.isCancelled == false else {
                return
            }
            player.play()
        }
    }
}

private struct ShopLoopingVideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let videoGravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = videoGravity
        view.playerLayer.player = player
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = videoGravity
    }

    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
    }
}
