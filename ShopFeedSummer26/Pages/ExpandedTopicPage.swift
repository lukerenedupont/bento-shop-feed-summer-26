import SwiftUI
import UIKit

/// The first transition primitive: the tapped feed card expands edge-to-edge.
/// Topic content can be layered in later, after this motion is fully dialed in.
struct ExpandedTopicPage: View {
    let topicID: String
    let sourceStoryID: String
    let namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsExpandedControls = false
    @State private var focusedProductID: String?
    @State private var revealedProductIDs = Set<String>()
    @State private var verticalScrollOffset: CGFloat = 0

    private var sourceStory: FeedStory? {
        PersonalizedFeedStories.all.first { $0.id == sourceStoryID }
    }

    private var sourceProducts: [ResolvedStoryProduct] {
        sourceStory?.resolvedProducts(from: SampleMerchant.all) ?? []
    }

    private var sourceTopic: FeedTopic? {
        PersonalizedFeedCatalog.current.topics.first { $0.id == topicID }
    }

    /// Curated bridge from each new dossier card to the richer topic catalog
    /// that previously lived in Home's pill rail.
    private var legacyTopicID: String {
        switch topicID {
        case "type-and-print", "sound-tools": "type-and-transit"
        case "lighting-and-living": "material-study-topic"
        case "daily-care": "scalp-care-topic"
        case "everyday-carry": "keep-shopping-topic"
        default: topicID
        }
    }

    private var legacyTopic: FeedTopic? {
        LegacyFeedArchive.topic(id: legacyTopicID)
    }

    private var legacyStories: [FeedStory] {
        legacyTopic.map(LegacyFeedArchive.stories(for:)) ?? []
    }

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
            let blurProgress = min(max(verticalScrollOffset / 360, 0), 1)

            ZStack(alignment: .topLeading) {
                if let sourceStory {
                    // One persistent film remains pinned behind the complete
                    // expanded feed. Only its foreground content scrolls.
                    StoryFeedCard(
                        story: sourceStory,
                        merchants: SampleMerchant.all,
                        width: geometry.size.width,
                        height: geometry.size.height,
                        isActive: true,
                        showsForegroundContent: false,
                        showsFooterArrow: false,
                        backgroundBlurRadius: blurProgress * 30,
                        backgroundPlaybackEnabled: blurProgress < 0.98,
                        cornerRadius: 0,
                        freezesParallax: true,
                        scrollViewportHeight: geometry.size.height
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                } else {
                    Color.black
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            if let sourceStory {
                                // Transparent copy carries the title and CTA,
                                // leaving the persistent film visible beneath.
                                StoryFeedCard(
                                    story: sourceStory,
                                    merchants: SampleMerchant.all,
                                    width: geometry.size.width,
                                    height: geometry.size.height,
                                    isActive: true,
                                    showsBackground: false,
                                    showsFooterArrow: false,
                                    foregroundBottomPadding: 48,
                                    cornerRadius: 0,
                                    freezesParallax: true,
                                    scrollViewportHeight: geometry.size.height
                                )
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            }

                            if !sourceProducts.isEmpty {
                                VStack(spacing: 0) {
                                    Spacer()
                                    productPager(containerWidth: geometry.size.width)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(showsExpandedControls ? 1 : 0)
                                .allowsHitTesting(showsExpandedControls)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)

                        categorySection(containerWidth: geometry.size.width)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    verticalScrollOffset = max(0, offset)
                }

                backButton
                    .padding(.top, windowSafeAreaTopInset + GravitySpacing.space12)
                    .opacity(showsExpandedControls ? 1 : 0)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .navigationTransition(.zoom(sourceID: sourceStoryID, in: namespace))
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .task(id: sourceStoryID) {
            focusedProductID = sourceProducts.first?.id
            revealedProductIDs = []
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.22)) {
                showsExpandedControls = true
            }

            if reduceMotion {
                revealedProductIDs = Set(sourceProducts.map(\.id))
            } else {
                for item in sourceProducts {
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        _ = revealedProductIDs.insert(item.id)
                    }
                    try? await Task.sleep(for: .milliseconds(90))
                }
            }
        }
        .onAppear {
            coordinator.showNavBar = false
        }
        .onDisappear {
            coordinator.resetScrollState()
            coordinator.showNavBar = true
        }
    }

    private func categorySection(containerWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: GravitySpacing.space16) {
                Text("Inside this edit")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.58))

                Text(sourceTopic?.label ?? "More to explore")
                    .font(.system(size: 38, weight: .heavy))
                    .tracking(-1.2)
                    .foregroundStyle(.white)

                if let subtitle = sourceStory?.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, GravitySpacing.space20)
            .padding(.top, 34)
            .padding(.bottom, 10)

            if let legacyTopic {
                // Restore the complete, pre-dossier pill destination beneath
                // the related new hero: its different stories, shops, product
                // rails, media carousel, and deep mixed masonry inventory.
                TopicLandingView(
                    topic: legacyTopic,
                    stories: legacyStories,
                    merchants: LegacyFeedArchive.merchants,
                    surfaceAccentHex: sourceStory?.accentHex,
                    usesAmbientBackdrop: true,
                    embeddedContainerWidth: containerWidth
                )
            }
        }
        .frame(width: containerWidth, alignment: .leading)
        .background(.clear)
    }

    private func productPager(containerWidth: CGFloat) -> some View {
        let cardWidth = min(containerWidth * 0.82, 330)

        return VStack(spacing: GravitySpacing.space12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space12) {
                    ForEach(sourceProducts) { item in
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(
                                .product(
                                    merchantId: item.merchant.id,
                                    productId: item.product.id
                                )
                            )
                        } label: {
                            expandedProductCard(item, width: cardWidth)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .accessibilityLabel("\(item.product.title), \(item.product.price)")
                        .opacity(revealedProductIDs.contains(item.id) ? 1 : 0)
                        .blur(radius: revealedProductIDs.contains(item.id) ? 0 : 4)
                        .offset(y: revealedProductIDs.contains(item.id) ? 0 : 18)
                        .scaleEffect(revealedProductIDs.contains(item.id) ? 1 : 0.96)
                        .id(item.id)
                        .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                            card
                                .scaleEffect(1 - min(abs(phase.value), 1) * 0.055)
                                .opacity(1 - min(abs(phase.value), 1) * 0.30)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: cardWidth * 1.06 + 130)
            .contentMargins(.horizontal, (containerWidth - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $focusedProductID, anchor: .center)

            HStack(spacing: 6) {
                ForEach(sourceProducts) { item in
                    Capsule()
                        .fill(.white.opacity(focusedProductID == item.id ? 0.95 : 0.34))
                        .frame(width: focusedProductID == item.id ? 18 : 6, height: 6)
                        .animation(.easeOut(duration: 0.18), value: focusedProductID)
                }
            }
            .frame(height: 8)
        }
    }

    private func expandedProductCard(
        _ item: ResolvedStoryProduct,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ProductImageView(product: item.product, merchant: item.merchant)
                .frame(width: width, height: width * 1.06)
                .background(Color(white: 0.965))
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.035)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 44)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.merchant.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.7)
                    .foregroundStyle(.black.opacity(0.48))
                    .lineLimit(1)

                Text(item.product.title)
                    .font(.system(size: 19, weight: .semibold))
                    .tracking(-0.35)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                Text(item.product.price)
                    .font(.system(size: 17, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .frame(width: width)
        .background(Color(white: 0.985))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.62), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .shadow(color: .black.opacity(0.24), radius: 24, y: 14)
    }

    private var backButton: some View {
        Button {
            coordinator.showNavBar = true
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.94), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.leading, GravitySpacing.space16)
        .accessibilityLabel("Back")
    }

}
