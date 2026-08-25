import AVFoundation
import SwiftUI

/// A muted video player for feed card backgrounds.
///
/// `playbackGroupID` lets two render surfaces share one AVQueuePlayer. This is
/// used by the feed card and its full-screen destination so navigation can add
/// a second AVPlayerLayer without restarting or seeking the film.
struct LoopingVideoPlayer: UIViewRepresentable {
    let urls: [URL]
    var loops: Bool
    var playbackEnabled: Bool
    var playbackGroupID: String?
    var videoGravity: AVLayerVideoGravity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        url: URL,
        loops: Bool = true,
        playbackEnabled: Bool = true,
        playbackGroupID: String? = nil,
        videoGravity: AVLayerVideoGravity = .resizeAspectFill
    ) {
        self.urls = [url]
        self.loops = loops
        self.playbackEnabled = playbackEnabled
        self.playbackGroupID = playbackGroupID
        self.videoGravity = videoGravity
    }

    init(
        urls: [URL],
        loops: Bool = true,
        playbackEnabled: Bool = true,
        playbackGroupID: String? = nil,
        videoGravity: AVLayerVideoGravity = .resizeAspectFill
    ) {
        self.urls = urls
        self.loops = loops
        self.playbackEnabled = playbackEnabled
        self.playbackGroupID = playbackGroupID
        self.videoGravity = videoGravity
    }

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(
            urls: urls,
            loops: loops,
            playbackEnabled: playbackEnabled && !reduceMotion,
            playbackGroupID: playbackGroupID,
            videoGravity: videoGravity
        )
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.setPlaybackEnabled(playbackEnabled && !reduceMotion)
        uiView.setVideoGravity(videoGravity)
    }

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: ()) {
        uiView.tearDown()
    }

    // MARK: - UIView surface

    final class PlayerUIView: UIView {
        private let urls: [URL]
        private let loops: Bool
        private let playbackGroupID: String?
        private var playbackEnabled: Bool
        private var videoGravity: AVLayerVideoGravity
        private var session: SharedVideoPlaybackSession?
        private var clientID: UUID?
        private var playerLayer: AVPlayerLayer?
        private var isSetUp = false

        init(
            urls: [URL],
            loops: Bool,
            playbackEnabled: Bool,
            playbackGroupID: String?,
            videoGravity: AVLayerVideoGravity
        ) {
            self.urls = urls
            self.loops = loops
            self.playbackEnabled = playbackEnabled
            self.playbackGroupID = playbackGroupID
            self.videoGravity = videoGravity
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }

        private func setUp() {
            guard !isSetUp, !urls.isEmpty else { return }
            isSetUp = true

            let session: SharedVideoPlaybackSession
            if let playbackGroupID {
                session = SharedVideoPlaybackRegistry.shared.session(
                    id: playbackGroupID,
                    urls: urls,
                    loops: loops
                )
            } else {
                session = SharedVideoPlaybackSession(urls: urls, loops: loops)
            }

            let clientID = session.register(enabled: playbackEnabled)
            backgroundColor = videoGravity == .resizeAspect ? .white : .black
            let layer = AVPlayerLayer(player: session.player)
            layer.videoGravity = videoGravity
            layer.backgroundColor = backgroundColor?.cgColor
            layer.frame = bounds
            self.layer.addSublayer(layer)

            self.session = session
            self.clientID = clientID
            self.playerLayer = layer
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                setUp()
                updateSessionPlayback()
            } else {
                // Lazy feed cells can remain retained after leaving the
                // viewport. Detach their decode pipeline immediately instead
                // of keeping buffered frames alive off-screen.
                tearDown()
            }
        }

        func setPlaybackEnabled(_ enabled: Bool) {
            playbackEnabled = enabled
            updateSessionPlayback()
        }

        func setVideoGravity(_ gravity: AVLayerVideoGravity) {
            videoGravity = gravity
            playerLayer?.videoGravity = gravity
        }

        private func updateSessionPlayback() {
            session?.setEnabled(playbackEnabled && window != nil, for: clientID)
        }

        func tearDown() {
            let detachedSession = session
            detachedSession?.unregister(clientID)
            if let playbackGroupID, let detachedSession {
                SharedVideoPlaybackRegistry.shared.release(
                    id: playbackGroupID,
                    session: detachedSession
                )
            }
            playerLayer?.removeFromSuperlayer()
            playerLayer = nil
            session = nil
            clientID = nil
            isSetUp = false
        }
    }
}

/// Plays the pull-to-refresh film as a windable cycle. It repeats while the
/// gesture is held, then completes the in-flight cycle exactly once on release.
struct PullRefreshVideoPlayer: UIViewRepresentable {
    let url: URL
    let isWinding: Bool
    let finishRequested: Bool
    let onFinished: () -> Void

    func makeUIView(context: Context) -> PullRefreshPlayerUIView {
        let view = PullRefreshPlayerUIView(url: url)
        view.setState(
            isWinding: isWinding,
            finishRequested: finishRequested,
            onFinished: onFinished
        )
        return view
    }

    func updateUIView(_ uiView: PullRefreshPlayerUIView, context: Context) {
        uiView.setState(
            isWinding: isWinding,
            finishRequested: finishRequested,
            onFinished: onFinished
        )
    }

    static func dismantleUIView(_ uiView: PullRefreshPlayerUIView, coordinator: ()) {
        uiView.tearDown()
    }

    final class PullRefreshPlayerUIView: UIView {
        private let player: AVPlayer
        private let playerLayer: AVPlayerLayer
        private var endObserver: NSObjectProtocol?
        private var isWinding = false
        private var isFinishing = false
        private var onFinished: () -> Void = {}

        init(url: URL) {
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            self.player = player
            self.playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)

            backgroundColor = .white
            player.isMuted = true
            player.actionAtItemEnd = .pause
            player.preventsDisplaySleepDuringVideoPlayback = false
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = UIColor.white.cgColor
            layer.addSublayer(playerLayer)

            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.didReachEnd()
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }

        func setState(
            isWinding: Bool,
            finishRequested: Bool,
            onFinished: @escaping () -> Void
        ) {
            self.onFinished = onFinished
            let beganWinding = isWinding && !self.isWinding
            let released = !isWinding && self.isWinding
            self.isWinding = isWinding

            if beganWinding {
                isFinishing = false
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) {
                    [weak self] _ in self?.player.play()
                }
            } else if released, finishRequested {
                isFinishing = true
                player.play()
            } else if released {
                player.pause()
                player.seek(to: .zero)
            }
        }

        private func didReachEnd() {
            if isWinding {
                player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) {
                    [weak self] _ in self?.player.play()
                }
            } else if isFinishing {
                isFinishing = false
                onFinished()
            }
        }

        func tearDown() {
            player.pause()
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            endObserver = nil
            playerLayer.player = nil
            playerLayer.removeFromSuperlayer()
        }
    }
}

@MainActor
private final class SharedVideoPlaybackRegistry {
    static let shared = SharedVideoPlaybackRegistry()

    private var sessions: [String: SharedVideoPlaybackSession] = [:]

    func session(id: String, urls: [URL], loops: Bool) -> SharedVideoPlaybackSession {
        if let session = sessions[id], session.urls == urls, session.loops == loops {
            return session
        }

        let session = SharedVideoPlaybackSession(urls: urls, loops: loops)
        sessions[id] = session
        return session
    }

    func release(id: String, session: SharedVideoPlaybackSession) {
        guard sessions[id] === session, !session.hasClients else { return }
        sessions[id] = nil
    }
}

@MainActor
private final class SharedVideoPlaybackSession {
    let urls: [URL]
    let loops: Bool
    let player: AVQueuePlayer

    private var looper: AVPlayerLooper?
    private var playlistObserver: NSObjectProtocol?
    private var clients: [UUID: Bool] = [:]
    private var ownedPlaylistItems = Set<ObjectIdentifier>()
    private var nextPlaylistIndex = 0

    var hasClients: Bool { !clients.isEmpty }

    init(urls: [URL], loops: Bool) {
        self.urls = urls
        self.loops = loops

        if loops, let onlyURL = urls.first, urls.count == 1 {
            let player = AVQueuePlayer()
            self.player = player
            self.looper = AVPlayerLooper(
                player: player,
                templateItem: AVPlayerItem(url: onlyURL)
            )
        } else {
            let items = urls.map(AVPlayerItem.init(url:))
            let player = AVQueuePlayer(items: items)
            self.player = player
            self.ownedPlaylistItems = Set(items.map(ObjectIdentifier.init))
            player.actionAtItemEnd = loops ? .advance : .pause

            if loops, urls.count > 1 {
                playlistObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    MainActor.assumeIsolated {
                        self?.appendNextItem(after: notification)
                    }
                }
            }
        }

        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    deinit {
        if let playlistObserver {
            NotificationCenter.default.removeObserver(playlistObserver)
        }
    }

    func register(enabled: Bool) -> UUID {
        let id = UUID()
        clients[id] = enabled
        refreshPlayback()
        return id
    }

    func setEnabled(_ enabled: Bool, for id: UUID?) {
        guard let id, clients[id] != nil else { return }
        clients[id] = enabled
        refreshPlayback()
    }

    func unregister(_ id: UUID?) {
        guard let id else { return }
        clients[id] = nil
        refreshPlayback()
    }

    private func refreshPlayback() {
        if clients.values.contains(true) {
            player.play()
        } else {
            player.pause()
        }
    }

    private func appendNextItem(after notification: Notification) {
        guard loops,
              urls.count > 1,
              let finishedItem = notification.object as? AVPlayerItem,
              ownedPlaylistItems.remove(ObjectIdentifier(finishedItem)) != nil else {
            return
        }

        let nextURL = urls[nextPlaylistIndex % urls.count]
        nextPlaylistIndex += 1
        let nextItem = AVPlayerItem(url: nextURL)
        ownedPlaylistItems.insert(ObjectIdentifier(nextItem))
        player.insert(nextItem, after: nil)
    }
}

#Preview {
    if let asset = NSDataAsset(name: "map") {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview-map.mp4")
        try? asset.data.write(to: tempURL)
        return AnyView(
            LoopingVideoPlayer(url: tempURL)
                .frame(width: 360, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
                .padding()
                .background(GravityColors.bg)
        )
    } else {
        return AnyView(Text("Video preview unavailable"))
    }
}
