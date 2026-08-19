import SwiftUI
import UIKit

/// Immersive destination for a tapped feed story. The Figma-derived header
/// and first commerce rails resolve from the story, so every buyer and topic
/// shares one presentation instead of branching into profile-specific views.
struct TopicDetailPage: View {
    let story: FeedStory
    let merchants: [SampleMerchant]

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var showsControls = false

    private var products: [ResolvedStoryProduct] {
        story.resolvedProducts(from: merchants)
    }

    private var relatedMerchants: [SampleMerchant] {
        var seen = Set<String>()
        return products.map(\.merchant).filter { seen.insert($0.id).inserted }
    }

    private var relatedDeals: [RelatedDeal] {
        relatedMerchants.prefix(6).map { merchant in
            var seen = Set<Int>()
            let topicProducts = products
                .filter { $0.merchant.id == merchant.id }
                .map(\.product)
            let resolvedProducts = (topicProducts + merchant.products)
                .filter { seen.insert($0.id).inserted }

            return RelatedDeal(
                merchant: merchant,
                products: Array(resolvedProducts.prefix(3))
            )
        }
    }

    private var surfaceColor: Color { Color(hex: story.accentHex) }

    private var windowSafeAreaTopInset: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: \.isKeyWindow) else {
            return 0
        }
        return keyWindow.safeAreaInsets.top
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                surfaceColor
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        hero(width: geometry.size.width)

                        VStack(alignment: .leading, spacing: GravitySpacing.space32) {
                            merchantRail
                            dealRail
                        }
                        .padding(.horizontal, GravitySpacing.space12)
                        .padding(.bottom, 120)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                closeButton
                    .padding(.top, windowSafeAreaTopInset + GravitySpacing.space4)
                    .opacity(showsControls ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .task(id: story.id) {
            showsControls = false
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) { showsControls = true }
        }
        .onAppear { coordinator.showNavBar = false }
        .onDisappear {
            coordinator.resetScrollState()
            coordinator.showNavBar = true
        }
    }

    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            surfaceColor

            StoryFeedCard(
                story: story,
                merchants: merchants,
                width: width,
                height: 640,
                isActive: true,
                showsForegroundContent: false,
                showsFooterArrow: false,
                backgroundPlaybackEnabled: true,
                cornerRadius: 0,
                freezesParallax: true
            )
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.56),
                        .init(color: .white.opacity(0.72), location: 0.72),
                        .init(color: .white.opacity(0.22), location: 0.88),
                        .init(color: .clear, location: 0.96),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .clear, location: 0.26),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: surfaceColor.opacity(0.48), location: 0.38),
                        .init(color: surfaceColor.opacity(0.9), location: 0.72),
                        .init(color: surfaceColor, location: 0.9),
                        .init(color: surfaceColor, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 240)

                // A solid overlap prevents a one-pixel compositing seam where
                // the hero hands off to the page surface.
                surfaceColor.frame(height: 24)
            }

            Text(story.title)
                .font(GravityFont.expressiveBold.fixedFont(size: 36))
                .tracking(-1)
                .lineSpacing(-8)
                .tightMultilineLeading(3)
                .foregroundStyle(.white)
                .gravityShadow(GravityShadows.feedText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: width - 32, alignment: .leading)
                .padding(.horizontal, GravitySpacing.space16)
                .padding(.top, 120)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(width: width, height: 640)
        .clipped()
    }

    private var merchantRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle("Top merchants")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(relatedMerchants) { merchant in
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(.store(merchantId: merchant.id))
                        } label: {
                            MerchantAvatarView(
                                merchant: merchant,
                                size: 72,
                                borderColor: .white.opacity(0.18)
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .accessibilityLabel(merchant.displayName)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollClipDisabled()
        }
    }

    private var dealRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle("Related deals")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(relatedDeals) { deal in
                        RelatedDealCard(deal: deal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollClipDisabled()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(GravityFont.expressiveBold.fixedFont(size: 24))
            .tracking(-0.5)
            .foregroundStyle(.white)
            .gravityShadow(GravityShadows.feedText)
    }

    private var closeButton: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.showNavBar = true
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.leading, GravitySpacing.space16)
        .accessibilityLabel("Close")
    }
}

private struct RelatedDeal: Identifiable {
    let merchant: SampleMerchant
    let products: [SampleMerchant.Product]

    var id: String { merchant.id }
}

private struct RelatedDealCard: View {
    let deal: RelatedDeal
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.store(merchantId: deal.merchant.id))
        } label: {
            ZStack {
                MerchantCoverImage(merchant: deal.merchant)
                    .frame(width: 266, height: 260)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.04), location: 0),
                        .init(color: deal.merchant.brandColor.opacity(0.72), location: 0.52),
                        .init(color: deal.merchant.brandColor, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: GravitySpacing.space10) {
                    merchantIdentity.frame(height: 88)
                    productRow

                    Text("Shop all")
                        .font(GravityFont.semiBold.fixedFont(size: 14))
                        .tracking(GravityLetterSpacing.cozy)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                .padding(GravitySpacing.space12)
            }
            .frame(width: 266, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Shop all from \(deal.merchant.displayName)")
    }

    private var merchantIdentity: some View {
        VStack(spacing: GravitySpacing.space8) {
            if MerchantBrandAssets.hasVerifiedBundledWordmark(for: deal.merchant.id) {
                MerchantWordmarkImage(
                    merchant: deal.merchant,
                    maxHeight: 48,
                    maxWidth: 132,
                    bundledAssetName: MerchantBrandAssets.wordmarkName(for: deal.merchant.id)
                )
                .gravityShadow(GravityShadows.feedText)
            } else {
                MerchantLogoImage(merchant: deal.merchant, size: 56)
            }

            if deal.merchant.totalRatings > 0 {
                HStack(spacing: 3) {
                    Text(String(format: "%.1f", deal.merchant.rating))
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("(\(compactRatingCount(deal.merchant.totalRatings)))")
                }
                .font(GravityFont.medium.fixedFont(size: 12))
                .foregroundStyle(.white)
                .gravityShadow(GravityShadows.feedText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var productRow: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(deal.products) { product in
                ProductImageView(product: product, merchant: deal.merchant)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                            .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    }
            }
        }
        .frame(height: 72)
    }

    private func compactRatingCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return String(count)
    }
}
