import SwiftUI

/// Source-linked editorial film. A short native loop, not a copied full film
/// or a claim that the featured runner wears every product in the edit.
struct ResearchCoverFilm: Decodable {
    let videoURL: URL
    let posterPath: String
    let posterSHA256: String
    let sourcePage: URL
    let sourceMerchantID: String
    let credit: String
    let loopDuration: TimeInterval
    let sourceDuration: TimeInterval
    let sourceWidth: Int
    let sourceHeight: Int
    let rightsStatus: String
    let checkedAt: String

    var posterURL: URL { ShopCanvasLibrary.rootURL.appendingPathComponent(posterPath) }

    static let norda: ResearchCoverFilm = {
        let url = ShopCanvasLibrary.rootURL.appendingPathComponent("catalog/research-media/cover-film.json")
        do { return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url)) }
        catch { preconditionFailure("Missing research cover film: \(error)") }
    }()
}

/// Both surfaces use the same player group, crop and poster. Visibility pauses
/// the shared player; accessibility/power restrictions show its real first frame.
struct ResearchCoverFilmView: View {
    let film: ResearchCoverFilm
    let story: FeedStory
    let playbackEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playbackRuntime = MediaPlaybackRuntime.shared
    @State private var isVisible = false

    var body: some View {
        Color.black.overlay {
            ZStack {
                CachedAsyncImage(url: film.posterURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                            .accessibilityLabel("Editorial cover: \(story.title)")
                    } else {
                        // EmptyView never starts CachedAsyncImage's load task.
                        Color.clear
                    }
                }
                if !reduceMotion && !playbackRuntime.isLowPowerModeEnabled {
                    LoopingVideoPlayer(
                        url: film.videoURL,
                        loopDuration: film.loopDuration,
                        playbackEnabled: playbackEnabled,
                        isVisible: isVisible,
                        playbackGroupID: "research-cover-\(story.id)"
                    )
                    .accessibilityHidden(true)
                }
                LinearGradient(
                    colors: [.black.opacity(0.04), .clear, .black.opacity(0.36)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .onScrollVisibilityChange(threshold: 0.2) { isVisible = $0 }
        .onDisappear { isVisible = false }
        .accessibilityIdentifier("research.cover-film")
    }
}
