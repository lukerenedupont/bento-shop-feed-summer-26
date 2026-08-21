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

    init(
        url: URL,
        loops: Bool = true,
        playbackEnabled: Bool = true,
        playbackGroupID: String? = nil
    ) {
        self.urls = [url]
        self.loops = loops
        self.playbackEnabled = playbackEnabled
        self.playbackGroupID = playbackGroupID
    }

    init(
        urls: [URL],
        loops: Bool = true,
        playbackEnabled: Bool = true,
        playbackGroupID: String? = nil
    ) {
        self.urls = urls
        self.loops = loops
        self.playbackEnabled = playbackEnabled
        self.playbackGroupID = playbackGroupID
    }

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(
            urls: urls,
            loops: loops,
            playbackEnabled: playbackEnabled,
            playbackGroupID: playbackGroupID
        )
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.setPlaybackEnabled(playbackEnabled)
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
        private var session: SharedVideoPlaybackSession?
        private var clientID: UUID?
        private var playerLayer: AVPlayerLayer?
        private var isSetUp = false

        init(
            urls: [URL],
            loops: Bool,
            playbackEnabled: Bool,
            playbackGroupID: String?
        ) {
            self.urls = urls
            self.loops = loops
            self.playbackEnabled = playbackEnabled
            self.playbackGroupID = playbackGroupID
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
            backgroundColor = .black
            let layer = AVPlayerLayer(player: session.player)
            layer.videoGravity = .resizeAspectFill
            layer.backgroundColor = UIColor.black.cgColor
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
