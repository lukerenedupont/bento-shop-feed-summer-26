import SwiftUI

/// Full-screen commerce-content card. One structure for every story — a
/// full-bleed ambient film or cover image, the title, and a product carousel
/// with price overlays along the bottom. A level playing field to build from.
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
                        .padding(.horizontal, GravitySpacing.space20)
                    Spacer(minLength: GravitySpacing.space12)
                    productCarousel
                }
                .padding(.vertical, GravitySpacing.space20)
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

    /// The story's hero product film, when its dossier has one.
    private var heroFilmURL: URL? {
        guard let hero = items.first else { return nil }
        return DossierStore.ambientVideoURL(merchantID: hero.merchant.id, productID: hero.product.id)
    }

    private var atmosphericBackground: some View {
        ZStack {
            Color(hex: story.accentHex)

            if let heroFilmURL {
                AmbientProductVideo(
                    videoURL: heroFilmURL,
                    posterImageURL: items.first?.product.imageURL
                )
            } else if let coverImageName = story.coverImageName {
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

    // MARK: - Product carousel

    private var productCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space8) {
                ForEach(items) { item in
                    productTile(item)
                }
            }
            .padding(.horizontal, GravitySpacing.space20)
        }
    }

    private func productTile(_ item: ResolvedStoryProduct) -> some View {
        ZStack(alignment: .bottomLeading) {
            ProductImageView(product: item.product, merchant: item.merchant)
                .frame(width: 108, height: 132)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))

            Text(formatPrice(item.product.price))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, GravitySpacing.space8)
                .padding(.vertical, GravitySpacing.space4)
                .background(.white.opacity(0.92), in: Capsule())
                .padding(GravitySpacing.space6)
        }
        .accessibilityLabel("\(item.product.title), \(formatPrice(item.product.price))")
    }
}

#Preview("Story card") {
    StoryFeedCard(
        story: FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}

#Preview("Story card — no cover") {
    StoryFeedCard(
        story: FeedStory.previews.first(where: { $0.coverImageName == nil }) ?? FeedStory.preview,
        merchants: SampleMerchant.previews,
        width: 377,
        height: 645
    )
    .padding()
    .background(GravityColors.bg)
    .environment(NavigationCoordinator())
}
