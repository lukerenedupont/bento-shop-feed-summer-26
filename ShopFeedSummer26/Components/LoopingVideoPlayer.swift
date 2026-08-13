import AVFoundation
import SwiftUI

/// A muted video player for feed card backgrounds.
///
/// Automatically pauses when scrolled off-screen and resumes when visible,
/// keeping GPU/CPU usage low when many video tiles exist in a scrollable feed.
/// Set `loops` to `false` to play once and hold on the last frame.
struct LoopingVideoPlayer: UIViewRepresentable {
    let url: URL
    var loops: Bool = true

    func makeUIView(context: Context) -> PlayerUIView {
        PlayerUIView(url: url, loops: loops)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerUIView, coordinator: ()) {
        uiView.tearDown()
    }

    // MARK: - UIView subclass

    final class PlayerUIView: UIView {
        private let url: URL
        private let loops: Bool
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var playerLayer: AVPlayerLayer?
        private var isPlaying = false
        private var isSetUp = false
        private var didFinish = false

        init(url: URL, loops: Bool) {
            self.url = url
            self.loops = loops
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }

        private func setUp() {
            guard !isSetUp else { return }
            isSetUp = true

            let item = AVPlayerItem(url: url)
            let queuePlayer = AVQueuePlayer(items: [item])
            queuePlayer.isMuted = true
            queuePlayer.preventsDisplaySleepDuringVideoPlayback = false

            if loops {
                let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
                self.looper = looper
            } else {
                queuePlayer.actionAtItemEnd = .pause
            }

            let layer = AVPlayerLayer(player: queuePlayer)
            layer.videoGravity = .resizeAspectFill
            layer.frame = bounds
            self.layer.addSublayer(layer)

            self.player = queuePlayer
            self.playerLayer = layer
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                setUp()
                if !didFinish {
                    play()
                }
            } else {
                if loops {
                    pause()
                }
            }
        }

        func play() {
            guard !isPlaying else { return }
            isPlaying = true
            player?.play()

            if !loops {
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(playerDidFinish),
                    name: .AVPlayerItemDidPlayToEndTime,
                    object: player?.currentItem
                )
            }
        }

        @objc private func playerDidFinish(_ note: Notification) {
            didFinish = true
            isPlaying = false
        }

        func pause() {
            guard isPlaying else { return }
            isPlaying = false
            player?.pause()
        }

        func tearDown() {
            NotificationCenter.default.removeObserver(self)
            player?.pause()
            player?.removeAllItems()
            playerLayer?.removeFromSuperlayer()
            player = nil
            looper = nil
            playerLayer = nil
        }
    }
}

#Preview {
    // The kit ships a "map" video asset used by DeliveriesPage — reuse it so
    // this preview works offline.
    if let asset = NSDataAsset(name: "map") {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview-map.mp4")
        try? asset.data.write(to: tempURL)
        return AnyView(
            LoopingVideoPlayer(url: tempURL)
                .frame(width: PurlTune.value("Components/LoopingVideoPlayer.swift:frame:width:134:31", default: 360), height: PurlTune.value("Components/LoopingVideoPlayer.swift:frame:height:134:127", default: 240))
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
                .padding()
                .background(PurlTune.token("Components/LoopingVideoPlayer.swift:background:_:137:29", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        )
    } else {
        return AnyView(
            Text("Video preview unavailable — no \"map\" asset in target")
                .foregroundStyle(PurlTune.token("Components/LoopingVideoPlayer.swift:foregroundStyle:_:142:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                .padding()
        )
    }
}
