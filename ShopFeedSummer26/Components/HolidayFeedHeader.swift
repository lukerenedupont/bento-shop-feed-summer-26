import SwiftUI

/// Shared campaign hierarchy for the seasonal For You, sale, and gift-guide
/// destinations. Keep these primitives together so related pages cannot drift.
extension View {
    func holidayCampaignTitleStyle() -> some View {
        self
            .font(FeedEditorialTypography.titleFont)
            .tracking(FeedEditorialTypography.titleTracking)
            .lineSpacing(FeedEditorialTypography.titleLineSpacing)
            .tightMultilineLeading(FeedEditorialTypography.titleLineTightening)
    }

    func holidayCampaignSupportingTextStyle() -> some View {
        self
            .font(GravityFont.semiBold.fixedFont(size: 14))
            .tracking(GravityLetterSpacing.cozy)
    }
}

struct HolidayPrimaryCTA: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            action()
        } label: {
            Text(title)
                .holidayCampaignSupportingTextStyle()
                .foregroundStyle(GravityColors.textFixedDark)
                .padding(.horizontal, GravitySpacing.space16)
                .frame(height: 36)
                .background(.white, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.52), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// Optional seasonal lead-in for the personalized For You feed.
/// Home owns placement and scrolling; this file owns the shared campaign art.
struct HolidayFeedHeader: View {
    let width: CGFloat
    let height: CGFloat
    var onShopNow: () -> Void

    var body: some View {
        SeasonalSavingsSurface(
            width: width,
            height: height,
            contentTopPadding: 144,
            showsBottomFade: true,
            onShopNow: onShopNow
        )
        .clipped()
    }
}

/// The same seasonal campaign rendered as a native flick-and-stick feed card.
struct HolidayFeedCard: View {
    let width: CGFloat
    let height: CGFloat
    let products: [ResolvedStoryProduct]
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let foregroundTopPadding: CGFloat
    let expansionProgress: CGFloat
    let borderOpacity: Double
    let shadowOpacity: Double
    var onShopNow: () -> Void
    var onSelectProduct: (ResolvedStoryProduct) -> Void

    private var cardShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: topCornerRadius,
            bottomLeadingRadius: bottomCornerRadius,
            bottomTrailingRadius: bottomCornerRadius,
            topTrailingRadius: topCornerRadius,
            style: .continuous
        )
    }

    private var productTileWidth: CGFloat {
        min(max((width - 72) / 2, 132), 160)
    }

    private var productRailHeight: CGFloat {
        productTileWidth + (GravitySpacing.space8 * 2)
    }

    private var productRailBottomInset: CGFloat {
        let compactInset = FeedCardStyle.bottomNavigationClearance
            + FeedCardStyle.nextCardPeek
            + FeedCardStyle.cardSpacing
        return compactInset
            + ((GravitySpacing.space20 - compactInset) * expansionProgress)
    }

    var body: some View {
        ZStack {
            SeasonalSavingsSurface(
                width: width,
                height: height,
                contentTopPadding: max(foregroundTopPadding + 24, height * 0.14),
                showsBottomFade: false,
                onShopNow: onShopNow
            )

            // Keep the rail inside a stable bottom region. The vertical inset
            // gives ProductCard's shadow and rounded corners room to render
            // before the seasonal card applies its outer clip.
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                productCarousel
                    .frame(height: productRailHeight)
                    .padding(.bottom, productRailBottomInset)
            }
            .frame(width: width, height: height)
        }
        .clipShape(cardShape)
        .overlay {
            cardShape
                .strokeBorder(.white.opacity(borderOpacity), lineWidth: 0.5)
        }
        .shadow(
            color: .black.opacity(0.18 * shadowOpacity),
            radius: 18,
            y: 10
        )
    }

    private var productCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: GravitySpacing.space8) {
                ForEach(products) { item in
                    Button {
                        HapticFeedback.light.fire()
                        onSelectProduct(item)
                    } label: {
                        ProductCard(
                            image: nil,
                            imageURL: item.product.imageURL,
                            priceBadge: formatPrice(item.product.price),
                            showFavoriteButton: true
                        )
                        .frame(width: productTileWidth, height: productTileWidth)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, GravitySpacing.space8)
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, GravitySpacing.space20, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
    }
}

private struct SeasonalSavingsSurface: View {
    let width: CGFloat
    let height: CGFloat
    let contentTopPadding: CGFloat
    let showsBottomFade: Bool
    var onShopNow: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Image("holiday-feed-banner")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.34), location: 0),
                    .init(color: .clear, location: 0.32),
                    .init(color: .black.opacity(0.08), location: 0.62),
                    .init(color: .black.opacity(0.38), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if showsBottomFade {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.72),
                        .white,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 84)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }

            campaignContent
                .padding(.top, contentTopPadding)
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .contain)
    }

    private var campaignContent: some View {
        VStack(spacing: 0) {
            Text("Season’s\nsavings")
                .holidayCampaignTitleStyle()
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.24), radius: 6, y: 2)

            Text("Earn Shop Cash on holiday hauls\nover $50—this week only.")
                .holidayCampaignSupportingTextStyle()
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.24), radius: 6, y: 2)
                .padding(.top, GravitySpacing.space10)

            HolidayPrimaryCTA(title: "Shop now", action: onShopNow)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }
}
