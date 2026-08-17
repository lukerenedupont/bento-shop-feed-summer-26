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

    @State private var showsExpandedControls = false
    @State private var focusedProductID: String?
    @State private var verticalScrollOffset: CGFloat = 0
    @State private var selectedSubtopicID: String?
    @Namespace private var topicNavigationNamespace

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

    private var selectedSubtopicStory: FeedStory? {
        guard let selectedSubtopicID else { return nil }
        return PersonalizedFeedCatalog.bundled.stories.first { $0.id == selectedSubtopicID }
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

                if let selectedSubtopicStory {
                    TopicLandingView(
                        topic: FeedTopic(
                            id: selectedSubtopicStory.id,
                            label: selectedSubtopicStory.title,
                            storyTopicKey: nil,
                            storyIDs: [selectedSubtopicStory.id],
                            subtopics: nil,
                            relatedMerchantIDs: nil,
                            merchandisingBlocks: nil
                        ),
                        stories: [selectedSubtopicStory],
                        merchants: LegacyFeedArchive.merchants,
                        headerCoverImageName: sourceStory?.coverImageName,
                        surfaceAccentHex: sourceStory?.accentHex,
                        headerEyebrow: legacyTopic?.label,
                        compactHeader: true
                    )
                    .transition(.opacity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            heroContent(containerWidth: geometry.size.width)
                            // Reveal the beginning of the next card at rest so
                            // the vertical continuation is immediately clear.
                            .frame(
                                width: geometry.size.width,
                                height: max(geometry.size.height - 118, 620)
                            )

                            categorySection(containerWidth: geometry.size.width)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y
                    } action: { _, offset in
                        verticalScrollOffset = max(0, offset)
                    }
                }

                topicNavigation
                    .padding(.top, windowSafeAreaTopInset + GravitySpacing.space4)
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
            showsExpandedControls = false
            // Let the system's shared navigation zoom settle before adding
            // foreground content. Competing effects here cause dropped frames.
            try? await Task.sleep(for: .milliseconds(360))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.24)) {
                showsExpandedControls = true
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

    /// Keeps the editorial title and its products in one layout and animation
    /// group so the expanded card reads as a single shared surface.
    private func heroContent(containerWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            if let sourceStory {
                Text(sourceStory.title)
                    .font(.system(size: 40, weight: .heavy).leading(.tight))
                    .tracking(-1.2)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, GravitySpacing.space20)
                    .accessibilityAddTraits(.isHeader)
            }

            if !sourceProducts.isEmpty {
                productPager(containerWidth: containerWidth)
            }

            Spacer(minLength: GravitySpacing.space16)
        }
        .padding(.top, windowSafeAreaTopInset + 98)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(showsExpandedControls ? 1 : 0)
        .offset(y: showsExpandedControls ? 0 : 10)
        .allowsHitTesting(showsExpandedControls)
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
            .padding(.vertical, GravitySpacing.space20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5)
            }
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.top, GravitySpacing.space8)
            .padding(.bottom, GravitySpacing.space20)

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
                        .id(item.id)
                        .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                            card
                                .scaleEffect(1 - min(abs(phase.value), 1) * 0.055)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .frame(height: cardWidth + 92)
            .contentMargins(.horizontal, (containerWidth - cardWidth) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $focusedProductID, anchor: .center)

        }
    }

    private func expandedProductCard(
        _ item: ResolvedStoryProduct,
        width: CGFloat
    ) -> some View {
        ProductCard(
            image: nil,
            imageURL: item.product.imageURL,
            merchantName: item.merchant.displayName,
            productName: item.product.title,
            rating: item.merchant.totalRatings > 0 ? item.merchant.rating : nil,
            ratingCount: item.merchant.totalRatings > 0 ? item.merchant.totalRatings : nil,
            priceBadge: formatPrice(item.product.price),
            showFavoriteButton: true
        )
        .frame(width: width, alignment: .topLeading)
    }

    private var navigationSubtopics: [FeedTopic.Subtopic] {
        if let curated = legacyTopic?.subtopics, !curated.isEmpty { return curated }
        return legacyStories.map { story in
            let label = story.title.split(separator: " ").prefix(3).joined(separator: " ")
            return FeedTopic.Subtopic(label: label, storyID: story.id)
        }
    }

    private var topicNavigation: some View {
        ZStack(alignment: .leading) {
            if !navigationSubtopics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FeedNavigationStyle.itemSpacing) {
                        ForEach(navigationSubtopics, id: \.storyID) { subtopic in
                            Button {
                                HapticFeedback.light.fire()
                                withAnimation(.smooth(duration: 0.36)) {
                                    selectedSubtopicID = subtopic.storyID
                                }
                            } label: {
                                Text(subtopic.label)
                                    .font(FeedNavigationStyle.labelFont)
                                    .foregroundStyle(
                                        selectedSubtopicID == subtopic.storyID ? .black : .white
                                    )
                                    .lineLimit(1)
                                    .padding(.horizontal, FeedNavigationStyle.pillHorizontalPadding)
                                    .frame(height: FeedNavigationStyle.controlSize)
                                    .background {
                                        if selectedSubtopicID == subtopic.storyID {
                                            Capsule()
                                                .fill(FeedNavigationStyle.selectedFill)
                                                .matchedGeometryEffect(
                                                    id: "selected-subtopic",
                                                    in: topicNavigationNamespace
                                                )
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.leading, FeedNavigationStyle.railLeadingInset, for: .scrollContent)
                .contentMargins(.trailing, FeedNavigationStyle.railTrailingInset, for: .scrollContent)
            }

            Button {
                HapticFeedback.light.fire()
                if selectedSubtopicID != nil {
                    withAnimation(.smooth(duration: 0.36)) {
                        selectedSubtopicID = nil
                    }
                } else {
                    coordinator.showNavBar = true
                    dismiss()
                }
            } label: {
                Image(systemName: selectedSubtopicID == nil ? "xmark" : "chevron.left")
                    .font(FeedNavigationStyle.iconFont)
                    .foregroundStyle(.black)
                    .frame(width: FeedNavigationStyle.controlSize, height: FeedNavigationStyle.controlSize)
                    .background(FeedNavigationStyle.selectedFill, in: Circle())
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .contentShape(Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.leading, GravitySpacing.space16)
            .accessibilityLabel(selectedSubtopicID == nil ? "Close" : "Back")
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, minHeight: FeedNavigationStyle.controlSize, alignment: .leading)
    }

}
