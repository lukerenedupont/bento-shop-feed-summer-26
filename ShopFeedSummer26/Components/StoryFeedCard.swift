import SwiftUI

/// Full-screen commerce-content card. A story can mix products and merchants;
/// the stable formats keep interaction familiar while the content supplies the novelty.
struct StoryFeedCard: View {
    let story: FeedStory
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    var isActive = true
    var showsBackground = true
    var showsForegroundContent = true
    var showsFooterArrow = true
    var foregroundBottomPadding: CGFloat = GravitySpacing.space20
    var backgroundBlurRadius: CGFloat = 0
    var backgroundPlaybackEnabled = true
    var cornerRadius: CGFloat = GravityRadius.r28
    var freezesParallax = false
    /// Enables scroll-relative movement for the ambient film without moving
    /// any foreground commerce content. Nil outside a paginated feed.
    var scrollViewportHeight: CGFloat? = nil
    var onTap: (() -> Void)? = nil

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mediaIsMoving = false

    private var items: [ResolvedStoryProduct] {
        story.resolvedProducts(from: merchants)
    }

    private var ambientFilmURLs: [URL] {
        guard story.coverImageName == nil else { return [] }
        return items.compactMap {
            $0.product.ambientFilmURL(merchantID: $0.merchant.id)
        }
    }

    private var leadFilmURL: URL? {
        ambientFilmURLs.first
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            if let onTap {
                onTap()
            } else {
                coordinator.pushRoute(.story(storyId: story.id))
            }
        } label: {
            ZStack {
                if showsBackground {
                    atmosphericBackground
                        .scaleEffect(backgroundBlurRadius > 0 ? 1.12 : 1)
                        .blur(radius: backgroundBlurRadius, opaque: true)
                    backgroundScrim
                }

                if showsForegroundContent {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: GravitySpacing.space12)
                        storyHeader
                        storyFooter
                            .padding(.top, GravitySpacing.space12)
                    }
                    .padding(.horizontal, GravitySpacing.space20)
                    .padding(.top, GravitySpacing.space20)
                    .padding(.bottom, foregroundBottomPadding)
                    .transition(.opacity)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
            .gravityShadow(GravityShadows.medium)
        }
        .buttonStyle(PressScaleButtonStyle())
        .onAppear { mediaIsMoving = true }
        .accessibilityLabel("\(story.title). \(story.subtitle)")
        .accessibilityHint(story.destinationLabel)
    }

    // MARK: - Atmosphere

    private var atmosphericBackground: some View {
        ZStack {
            Color(hex: story.accentHex)

            if let coverImageName = story.coverImageName {
                // Overlay-on-clear keeps the fill image from expanding the
                // ZStack beyond the card frame and breaking sibling layout.
                Color.clear
                    .overlay {
                        Image(coverImageName)
                            .resizable()
                            .scaledToFill()
                            .scaleEffect(mediaIsMoving ? 1.0 : 1.04)
                            .animation(
                                .easeInOut(duration: 8).repeatForever(autoreverses: true),
                                value: mediaIsMoving
                            )
                    }
                    .clipped()
            } else if let first = items.first, let leadFilmURL {
                parallaxFilm {
                    AmbientProductVideo(
                        videoURLs: ambientFilmURLs,
                        posterImageURL: first.product.imageURL,
                        playbackEnabled: backgroundPlaybackEnabled,
                        playbackGroupID: "story-card-\(story.id)"
                    )
                }
            } else if let first = items.first,
                      let imageURL = first.product.imageURL,
                      let url = URL(string: imageURL) {
                CachedAsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 22)
                            .scaleEffect(mediaIsMoving ? 1.08 : 1.22)
                            .opacity(0.42)
                            .animation(
                                .easeInOut(duration: 8).repeatForever(autoreverses: true),
                                value: mediaIsMoving
                            )
                    }
                }
            }

            if leadFilmURL == nil {
                LinearGradient(
                    colors: [Color(hex: story.accentHex).opacity(0.08), Color(hex: story.accentHex).opacity(0.68)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipped()
    }

    /// The film travels at a fraction of the card's scroll velocity. A small
    /// overscan keeps the card edges covered while the media shifts underneath
    /// its stationary title, products, and scrims.
    @ViewBuilder
    private func parallaxFilm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let scrollViewportHeight, !reduceMotion {
            content()
                .scaleEffect(1.05)
                .visualEffect { film, proxy in
                    film.offset(
                        y: freezesParallax
                            ? 0
                            : max(
                                -14,
                                min(
                                    14,
                                    -(proxy.frame(in: .scrollView(axis: .vertical)).midY
                                        - scrollViewportHeight / 2) * 0.025
                                )
                            )
                    )
                }
        } else {
            content()
        }
    }

    private var backgroundScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.36), location: 0),
                .init(color: .clear, location: 0.30),
                .init(color: .clear, location: 0.72),
                .init(color: .black.opacity(0.34), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var storyHeader: some View {
        // Same hero treatment as topic-page titles: centered, heavy,
        // tightly tracked display text.
        Text(story.title)
            .font(.system(size: 32, weight: .heavy).leading(.tight))
            .tracking(-1.1)
            .lineSpacing(-11)
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stable formats

    @ViewBuilder
    private var storyContent: some View {
        switch story.format {
        case .world:
            StoryWorldLayout(items: items, isActive: isActive)
        case .shortlist:
            StoryShortlistLayout(items: items, isActive: isActive)
        case .setup:
            StorySetupLayout(items: items, isActive: isActive)
        }
    }

    // MARK: - Footer

    private var storyFooter: some View {
        HStack(spacing: GravitySpacing.space12) {
            Text(story.destinationLabel)
                .gravityTextStyle(GravityTypography.headerBold)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if showsFooterArrow {
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.12), in: Circle())
            }
        }
    }

}

#Preview("World story") {
    StoryFeedCard(
        story: FeedStory.previews.first(where: { $0.format == .world }) ?? FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}

#Preview("Shortlist story") {
    StoryFeedCard(
        story: FeedStory.previews.first(where: { $0.format == .shortlist }) ?? FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}

#Preview("Setup story") {
    StoryFeedCard(
        story: FeedStory.previews.first(where: { $0.format == .setup }) ?? FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}
