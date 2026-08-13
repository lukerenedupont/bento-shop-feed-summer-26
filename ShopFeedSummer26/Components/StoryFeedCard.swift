import SwiftUI

/// Full-screen commerce-content card. A story can mix products and merchants;
/// the stable formats keep interaction familiar while the content supplies the novelty.
struct StoryFeedCard: View {
    let story: FeedStory
    let merchants: [SampleMerchant]
    let width: CGFloat
    let height: CGFloat
    var onTap: (() -> Void)? = nil

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var mediaIsMoving = false

    private var items: [ResolvedStoryProduct] {
        story.resolvedProducts(from: merchants)
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
                atmosphericBackground
                backgroundScrim

                VStack(alignment: .leading, spacing: 0) {
                    storyHeader
                    Spacer(minLength: GravitySpacing.space12)
                    storyContent
                    Spacer(minLength: GravitySpacing.space12)
                    storyFooter
                }
                .padding(GravitySpacing.space20)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
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

            LinearGradient(
                colors: [Color(hex: story.accentHex).opacity(0.08), Color(hex: story.accentHex).opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipped()
    }

    private var backgroundScrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.28), location: 0),
                .init(color: .clear, location: 0.34),
                .init(color: .black.opacity(0.22), location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header

    private var storyHeader: some View {
        VStack(spacing: GravitySpacing.space8) {
            storyContext

            // Same hero treatment as topic-page titles: centered, heavy,
            // tightly tracked display text.
            Text(story.title)
                .font(.system(size: 40, weight: .heavy))
                .tracking(-1.4)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var storyContext: some View {
        if let merchant = merchantForWordmark {
            MerchantWordmarkImage(merchant: merchant, maxHeight: 22, maxWidth: 150, tint: GravityColors.text)
                .padding(.horizontal, GravitySpacing.space10)
                .padding(.vertical, GravitySpacing.space6)
                .background(.white.opacity(0.92), in: Capsule())
        }
    }

    private var merchantForWordmark: SampleMerchant? {
        guard let first = items.first else { return nil }
        let isMerchantStory = Set(items.map(\.merchant.id)).count == 1
            || story.eyebrow.caseInsensitiveCompare(first.merchant.name) == .orderedSame
        return isMerchantStory ? first.merchant : nil
    }

    // MARK: - Stable formats

    @ViewBuilder
    private var storyContent: some View {
        switch story.format {
        case .world:
            StoryWorldLayout(items: items)
        case .shortlist:
            StoryShortlistLayout(items: items)
        case .setup:
            StorySetupLayout(items: items)
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

            Image(systemName: "arrow.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.12), in: Circle())
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
