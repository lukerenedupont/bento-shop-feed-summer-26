import SwiftUI

/// A contained quick-search results card matching the Figma "QuickSearch" spec.
///
/// Layout: bg-fill-secondary container with 16px padding, 20pt corners, clips content.
/// Contains: filter chips → product card scroll → "View N results" button.
struct QuickSearchCard: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let agentSection: AgentProductSection
    var totalCount: Int = 0
    var onViewMore: (() -> Void)? = nil
    var onProductTap: ((AgentProduct) -> Void)? = nil

    var body: some View {
        VStack(spacing: GravitySpacing.space16) {
            // Product cards — horizontal scroll
            productScroll

            // "View more" button
            viewResultsButton
        }
        .padding(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:21:18", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:background:_:22:21", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28)
                .strokeBorder(GravityColors.border, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
        .padding(.horizontal, GravitySpacing.screenMargin)
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space4) {

                // Filter icon chip (icon-only)
                chipButton {
                    GravityIcon.filter.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:width:43:39", default: 20), height: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:height:43:143", default: 20))
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:foregroundStyle:_:44:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .padding(.horizontal, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:45:47", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                        .padding(.vertical, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:46:45", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                }

                // Text chips
                chipButton {
                    HStack(spacing: 4) {
                        Text("Sells from")
                            .gravityTextStyle(GravityTypography.buttonMedium)
                            .foregroundStyle(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:foregroundStyle:_:54:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        Text("🇺🇸").font(.system(size: 14))
                    }
                    .padding(.horizontal, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:57:43", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                    .padding(.vertical, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:58:41", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                }

                chipButton {
                    Text("Your deals")
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:foregroundStyle:_:64:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .padding(.horizontal, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:65:47", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                        .padding(.vertical, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:66:45", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                }

                chipButton {
                    Text("Following")
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:foregroundStyle:_:72:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .padding(.horizontal, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:73:47", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                        .padding(.vertical, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:74:45", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                }
            }
            .padding(.leading, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:77:32", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        }
        .padding(.horizontal, -GravitySpacing.space16)
    }

    private func chipButton<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: {}) {
            content()
                .frame(height: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:height:85:32", default: 40))
                .background(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:background:_:86:29", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(GravityColors.borderSecondary, lineWidth: 0.5)
                )
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
        .shadow(color: .black.opacity(PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:opacity:_:93:39", default: 0.02)), radius: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:shadow:radius:93:144", default: 1), x: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:shadow:x:93:245", default: 0), y: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:shadow:y:93:341", default: 4))
    }

    // MARK: - Product Scroll

    private var productScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: GravitySpacing.space8) {
                ForEach(agentSection.products) { product in
                    Button {
                        HapticFeedback.light.fire()
                        onProductTap?(product)
                    } label: {
                        AgentProductCard(
                            imageURL: product.imageURL?.absoluteString,
                            merchantName: product.shopName,
                            productName: product.title,
                            rating: product.rating,
                            ratingCount: product.ratingCount,
                            price: product.price,
                            originalPrice: product.originalPrice,
                            showFavoriteButton: true,
                            starColor: GravityColors.text
                        )
                        .frame(width: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:width:117:39", default: 130))
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.95))
                }
            }
            .padding(.horizontal, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:122:35", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.vertical, PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:padding:_:123:33", default: 6)) // room for product card shadows
        }
        .padding(.horizontal, -GravitySpacing.space16)
        .padding(.vertical, PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:padding:_:126:29", default: -6))
    }

    // MARK: - View Results Button

    private var viewResultsButton: some View {
        Button {
            HapticFeedback.light.fire()
            onViewMore?()
        } label: {
            Text("View more")
                .gravityTextStyle(GravityTypography.buttonMedium)
                .foregroundStyle(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:foregroundStyle:_:138:34", default: GravityColors.textInverse, options: GravityColors.purlTuneColorOptions))
        }
        .buttonStyle(ElevatedSecondarySmallButtonStyle())
    }
}

// MARK: - Skeleton

struct QuickSearchCardSkeleton: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    var body: some View {
        VStack(spacing: GravitySpacing.space16) {
            // Filter chip placeholders
            HStack(spacing: GravitySpacing.space4) {
                skeletonPill(width: 40)
                skeletonPill(width: 100)
                skeletonPill(width: 84)
                skeletonPill(width: 80)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Product card placeholders — match real card's horizontal scroll layout
            HStack(spacing: GravitySpacing.space8) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                        RoundedRectangle(cornerRadius: GravityRadius.r20)
                            .fill(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:fill:_:163:35", default: GravityColors.bgFillTertiary, options: GravityColors.purlTuneColorOptions))
                            .aspectRatio(1, contentMode: .fit)

                        VStack(alignment: .leading, spacing: 6) {
                            skeletonLine(widthFraction: 0.8)
                            skeletonLine(widthFraction: 0.6)
                            skeletonLine(widthFraction: 0.5)
                            skeletonLine(widthFraction: 0.3)
                        }
                        .padding(.leading, PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:172:44", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                    }
                }
            }

            // Button placeholder
            RoundedRectangle(cornerRadius: GravityRadius.max)
                .fill(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:fill:_:179:23", default: GravityColors.bgFillTertiary, options: GravityColors.purlTuneColorOptions))
                .frame(height: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:height:180:32", default: 40))
        }
        .padding(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:padding:_:182:18", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:background:_:183:21", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28)
                .strokeBorder(GravityColors.border, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
        .padding(.horizontal, GravitySpacing.screenMargin)
        .pulse()
    }

    private func skeletonPill(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: GravityRadius.max)
            .fill(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:fill:_:196:19", default: GravityColors.bgFillTertiary, options: GravityColors.purlTuneColorOptions))
            .frame(width: width, height: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:height:197:42", default: 40))
    }

    private func skeletonLine(widthFraction: CGFloat) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:fill:_:203:23", default: GravityColors.bgFillTertiary, options: GravityColors.purlTuneColorOptions))
                .frame(width: geo.size.width * widthFraction, height: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:height:204:71", default: 12))
        }
        .frame(height: PurlTune.value("Components/Search/Agent/QuickSearchCard.swift:frame:height:206:24", default: 12))
    }
}

#Preview("Loaded") {
    QuickSearchCard(
        agentSection: AgentProductSection(
            title: "Quick search",
            subtitle: nil,
            products: AgentProduct.previews(),
            isComparison: false,
            isQuickSearch: true
        ),
        totalCount: 142
    )
    .padding()
    .background(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:background:_:222:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("Skeleton") {
    QuickSearchCardSkeleton()
        .padding()
        .background(PurlTune.token("Components/Search/Agent/QuickSearchCard.swift:background:_:228:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
