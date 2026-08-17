import Combine
import SwiftUI

/// Home feed — scrollable merchant feed cards with focused topic feeds.
struct HomePage: View {
    /// Shared with `RootView` so a tapped feed card can zoom into the
    /// original full-screen topic content.
    var namespace: Namespace.ID

#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var merchantService = RemoteMerchantService.shared
    @ObservedObject private var feedService = RemoteFeedService.shared
    @Namespace private var heroNamespace
    @Namespace private var topicSelectionNamespace

    /// Buyer-profile-curated products bundled from official merchant catalogs.
    @State private var bundledMerchants: [SampleMerchant] = LocalMerchantService.loadMerchants()

    /// The generated assortment once the dossier-lab feed answers, else the
    /// bundled snapshot. Recomputes when the service publishes, so a feed that
    /// lands after first render swaps in without any manual refresh.
    private var merchants: [SampleMerchant] {
        feedService.merchants.isEmpty ? bundledMerchants : feedService.merchants
    }
    @State private var selectedTopicID = "for-you"
    /// A drilled-in subcategory story rendered inline so the top bar stays.
    @State private var focusedStoryID: String?
    @State private var visibleStoryID: String?
    @State private var isFeedScrolling = false
    @State private var expandingStoryID: String?
    @State private var notificationIndex = 0

    private let retargetingCardHeight: CGFloat = 177

    private var topics: [FeedTopic] { PersonalizedFeedCatalog.current.topics }
    /// Header destinations mirror the For You card order exactly. This keeps
    /// every pill paired with the card that opens the same editorial world.
    private var navigationTopics: [FeedTopic] {
        guard let forYou = topics.first(where: { $0.id == "for-you" }) else { return topics }
        var seen = Set<String>()
        let orderedDestinations = (forYou.storyIDs ?? []).compactMap { storyID -> FeedTopic? in
            guard let topic = topics.first(where: {
                $0.id != "for-you" && $0.storyIDs?.contains(storyID) == true
            }), seen.insert(topic.id).inserted else { return nil }
            return topic
        }
        return [forYou] + orderedDestinations
    }
    private var selectedTopic: FeedTopic {
        topics.first { $0.id == selectedTopicID } ?? topics[0]
    }

    private var pageBackgroundColor: Color {
        guard selectedTopicID != "for-you", let leadStory = focusedStories.first else {
            return .white
        }
        return Color(hex: leadStory.accentHex)
    }

    private var focusedStories: [FeedStory] {
        let stories = PersonalizedFeedStories.all
        if let storyIDs = selectedTopic.storyIDs {
            let storiesByID = Dictionary(uniqueKeysWithValues: stories.map { ($0.id, $0) })
            return storyIDs.compactMap { storiesByID[$0] }
        }
        guard let topicKey = selectedTopic.storyTopicKey else { return stories }
        return stories.filter { $0.topicKeys.contains(topicKey) }
    }

    private var activeFeedStory: FeedStory? {
        if let visibleStoryID,
           let visibleStory = focusedStories.first(where: { $0.id == visibleStoryID }) {
            return visibleStory
        }
        return focusedStories.first
    }

    var body: some View {
        Group {
            if let focusedStoryID {
                StoryTopicPage(storyID: focusedStoryID, namespace: namespace)
                    .id(focusedStoryID)
            } else if selectedTopicID == "for-you" {
                storyFeed
            } else {
                TopicLandingView(topic: selectedTopic, stories: focusedStories, merchants: merchants)
                    .id(selectedTopicID)
            }
        }
        .transaction { transaction in
            // Topic changes replace the content immediately while the
            // selection pill animates independently in the top bar.
            transaction.animation = nil
        }
        .background(pageBackgroundColor.ignoresSafeArea())
        .safeAreaBar(edge: .top) {
            topBar
        }
        // Every Home surface now sits on imagery. Keep status-bar chrome light
        // so the transparent top rail remains legible over the moving backdrop.
        .environment(\.colorScheme, .dark)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // Keep the curated assortment authoritative for this prototype and
            // expose it to PDP/store lookups through SampleMerchant.all.
            merchantService.merchants = merchants
            merchantService.usingFallbackData = !feedService.isLive
            coordinator.navBarBlurTint = pageBackgroundColor
        }
        .onChange(of: feedService.revision) { _, _ in
            // The feed usually lands after first render; re-publish so PDP and
            // store lookups going through SampleMerchant.all see the same
            // assortment the stories reference.
            merchantService.merchants = merchants
            merchantService.usingFallbackData = !feedService.isLive
        }
        .onChange(of: selectedTopicID) { _, _ in
            withAnimation(.easeOut(duration: 0.22)) {
                coordinator.navBarBlurTint = pageBackgroundColor
            }
            syncTopicBackAction()
        }
        .onChange(of: focusedStoryID) { _, _ in
            syncTopicBackAction()
        }
        .onAppear {
            expandingStoryID = nil
            syncTopicBackAction()
            coordinator.inlineStoryHandler = { storyID in
                coordinator.resetScrollState()
                HapticFeedback.light.fire()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    focusedStoryID = storyID
                }
                return true
            }
        }
        .purlInjectable()
    }

    private var storyFeed: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width - 32, 377)
            let cardHeight = cardWidth * 1.71

            ZStack {
                feedAmbientBackdrop

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        feedUtilityShelf(containerWidth: geo.size.width)

                        ForEach(focusedStories) { story in
                            paginatedFeedCard(
                                story,
                                width: cardWidth,
                                height: cardHeight,
                                viewportHeight: geo.size.height
                            )
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.top, 8)
                    .padding(.bottom, max((geo.size.height - cardHeight) / 2, 8))
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $visibleStoryID, anchor: .center)
                .onScrollPhaseChange { _, phase in
                    isFeedScrolling = phase != .idle
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                    coordinator.updateScrollOffset(offset)
                }
            }
            .onChange(of: focusedStories.map(\.id)) { _, storyIDs in
                // A nil position means the shopper is still in the utility
                // shelf above the flick-and-stick feed. Never jump them past it.
                guard let visibleStoryID else { return }
                guard storyIDs.contains(visibleStoryID) else {
                    self.visibleStoryID = nil
                    return
                }
            }
        }
    }

    private var utilityProducts: [ResolvedStoryProduct] {
        var seen = Set<String>()
        return focusedStories
            .flatMap { $0.resolvedProducts(from: merchants) }
            .filter { seen.insert($0.id).inserted }
    }

    private func feedUtilityShelf(containerWidth: CGFloat) -> some View {
        VStack(spacing: 22) {
            feedNotificationStack
            retargetingRailCarousel(containerWidth: containerWidth)
        }
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(width: containerWidth)
    }

    private func retargetingRailCarousel(containerWidth: CGFloat) -> some View {
        let railWidth = min(max(containerWidth - 64, 300), 360)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                utilityProductRail(
                    title: "Buy again",
                    products: Array(utilityProducts.dropFirst(3).prefix(3)),
                    width: railWidth
                )

                if let cartItem = cartSyncItem {
                    cartSyncCard(item: cartItem, width: railWidth)
                }

                utilityProductRail(
                    title: "Recently viewed",
                    products: Array(utilityProducts.prefix(3)),
                    width: railWidth
                )

                utilityProductRail(
                    title: "Saved for later",
                    products: Array(utilityProducts.dropFirst(6).prefix(3)),
                    width: railWidth
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollClipDisabled()
    }

    private var cartSyncItem: ResolvedStoryProduct? {
        utilityProducts.min { lhs, rhs in
            numericPrice(lhs.product.price) < numericPrice(rhs.product.price)
        }
    }

    private func numericPrice(_ price: String) -> Double {
        Double(price.filter { $0.isNumber || $0 == "." }) ?? .greatestFiniteMagnitude
    }

    private func cartSyncCard(item: ResolvedStoryProduct, width: CGFloat) -> some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.navigateToPage(4)
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text(item.merchant.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.76), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.merchant.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                        Text("Subtotal \(formatPrice(item.product.price))")
                            .font(.system(size: 14))
                            .foregroundStyle(.black.opacity(0.58))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    ProductImageView(product: item.product, merchant: item.merchant)
                        .frame(width: 60, height: 60)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Text("1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(.black, in: Circle())
                                .offset(x: -6, y: -6)
                        }
                }

                Spacer(minLength: 10)

                Text("Continue to checkout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(Color.black.opacity(0.05), in: Capsule())
            }
            .padding(16)
            .frame(width: width, height: retargetingCardHeight)
            .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private var feedNotifications: [(title: String, subtitle: String, icon: String)] {
        [
            ("Get up to $100 Shop Cash", "Plus flash deals and exclusive offers", "dollarsign"),
            ("Your order is on the way", "Track your delivery from Design Within Reach", "shippingbox"),
            ("20% off your saved picks", "A limited-time offer from shops you follow", "tag"),
        ]
    }

    private var feedNotificationStack: some View {
        let notification = feedNotifications[notificationIndex % feedNotifications.count]

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
                .frame(height: 72)
                .padding(.horizontal, 12)
                .offset(y: 7)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 7)

            Button {
                HapticFeedback.light.fire()
                withAnimation(.smooth(duration: 0.28)) {
                    notificationIndex = (notificationIndex + 1) % feedNotifications.count
                }
            } label: {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: notification.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)
                                .contentTransition(.symbolEffect(.replace))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .semibold))
                        Text(notification.subtitle)
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.opacity)

                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 14)
                .frame(height: 72)
                .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 12, y: 7)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .frame(height: 79)
        .padding(.horizontal, 16)
    }

    private func utilityProductRail(
        title: String,
        products: [ResolvedStoryProduct],
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.05), in: Circle())
            }

            HStack(spacing: 10) {
                ForEach(products) { item in
                    Button {
                        HapticFeedback.light.fire()
                        coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
                    } label: {
                        ProductCard(
                            image: nil,
                            imageURL: item.product.imageURL,
                            priceBadge: formatPrice(item.product.price),
                            showFavoriteButton: true
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(width: width, height: retargetingCardHeight, alignment: .top)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }

    /// Pulls each card gently back toward the viewport center while it moves.
    /// Native snapping releases that resistance at the end, creating a short,
    /// interruptible rubber catch-up rather than delaying gesture response.
    private func paginatedFeedCard(
        _ story: FeedStory,
        width: CGFloat,
        height: CGFloat,
        viewportHeight: CGFloat
    ) -> some View {
        let motionIsReduced = reduceMotion

        return StoryFeedCard(
            story: story,
            merchants: merchants,
            width: width,
            height: height,
            isActive: story.id == activeFeedStory?.id,
            showsFooterArrow: false,
            titleAtTopLeading: true,
            showsProductCarousel: true,
            backgroundPlaybackEnabled: expandingStoryID != story.id,
            freezesParallax: expandingStoryID == story.id,
            scrollViewportHeight: viewportHeight,
            onTap: { openTopic(for: story) }
        )
        .scrollTransition(
            motionIsReduced ? .identity : .interactive(timingCurve: .circularEaseOut),
            axis: .vertical
        ) { card, phase in
            card
                .offset(y: motionIsReduced ? 0 : -CGFloat(phase.value) * 18)
                .scaleEffect(
                    motionIsReduced
                        ? 1
                        : 1 - CGFloat(min(abs(phase.value), 1)) * 0.015
                )
        }
        .scaleEffect(motionIsReduced || story.id == activeFeedStory?.id ? 1 : 0.992)
        .animation(motionIsReduced ? nil : SpringPreset.responsive, value: activeFeedStory?.id)
        .matchedTransitionSource(id: story.id, in: namespace) { source in
            source
                .background(.black)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: GravityRadius.r28,
                        style: .continuous
                    )
                )
                .shadow(
                    color: .black.opacity(0.24),
                    radius: 18,
                    y: 10
                )
        }
        .id(story.id)
    }

    private var feedAmbientBackdrop: some View {
        ZStack {
            Color.black

            if let story = activeFeedStory,
               let lead = story.resolvedProducts(from: merchants).first {
                AmbientProductVideo(
                    videoURLs: backdropFilmURLs(for: story),
                    posterImageURL: lead.product.imageURL,
                    playbackEnabled: isFeedScrolling
                )
                .id(story.id)
                .scaleEffect(1.18)
                .blur(radius: 34, opaque: true)
                .opacity(isFeedScrolling ? 0.64 : 0.48)
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(.easeOut(duration: isFeedScrolling ? 0.18 : 0.24), value: isFeedScrolling)
        .animation(.easeInOut(duration: 0.24), value: activeFeedStory?.id)
    }

    /// Rotates the story playlist by one item so the blurred backdrop never
    /// mirrors the clip currently beginning inside the foreground card.
    private func backdropFilmURLs(for story: FeedStory) -> [URL] {
        let urls = story.resolvedProducts(from: merchants).flatMap {
            $0.product.ambientFilmURLs(merchantID: $0.merchant.id)
        }
        guard urls.count > 1 else { return urls }
        return Array(urls.dropFirst()) + [urls[0]]
    }

    /// Resolves a For You story to its canonical topic. An exact lead-story
    /// match wins over secondary membership so cards such as New York graphics
    /// can own a destination even when they also appear in Type & transit.
    private func openTopic(for story: FeedStory) {
        let destinations = topics.filter { $0.id != "for-you" }
        let destination = destinations.first { $0.storyIDs?.first == story.id }
            ?? destinations.first { $0.storyIDs?.contains(story.id) == true }
            ?? destinations.first { topic in
                guard let key = topic.storyTopicKey else { return false }
                return story.topicKeys.contains(key)
            }

        guard let destination else {
            coordinator.pushRoute(.story(storyId: story.id))
            return
        }

        coordinator.resetScrollState()
        expandingStoryID = story.id

        // Commit the frozen media geometry before navigation captures the
        // matched source. Otherwise parallax reacts to the zoom's changing
        // coordinate space and the film appears to slide out of the card.
        Task { @MainActor in
            await Task.yield()
            coordinator.pushRoute(
                .topicExpanded(topicId: destination.id, sourceStoryId: story.id)
            )
        }
    }

    // MARK: - Top Bar (Quick Links)

    @State private var avatarPressed = false

    private var topBar: some View {
        ZStack(alignment: .leading) {
            topicRail
            avatar
                .zIndex(1)
        }
        .padding(.leading, GravitySpacing.space16)
        .padding(.vertical, PurlTune.token("Pages/HomePage.swift:padding:_:165:29", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        // Deliberately no bar background: the active feed film or topic cover
        // continues through both the topic rail and the status-bar safe area.
    }

    /// Registers the bottom nav's back behavior for the active topic. Topic
    /// selection is inline state, so the shared back button needs this hook.
    private func syncTopicBackAction() {
        if focusedStoryID != nil {
            // Back from a subcategory returns to its parent topic in place.
            coordinator.topicBackAction = {
                coordinator.resetScrollState()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    focusedStoryID = nil
                }
            }
        } else if selectedTopicID == "for-you" {
            coordinator.topicBackAction = nil
        } else {
            coordinator.topicBackAction = {
                coordinator.resetScrollState()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    selectedTopicID = "for-you"
                }
            }
        }
    }

    private var avatar: some View {
        Image("luke-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: FeedNavigationStyle.avatarSize, height: FeedNavigationStyle.avatarSize)
                .clipShape(Circle())
                .matchedTransitionSource(id: "account-avatar", in: heroNamespace)
                .scaleEffect(avatarPressed ? 0.85 : 1.0)
                .animation(.spring(response: PurlTune.value("Pages/HomePage.swift:spring:response:135:46", default: 0.2), dampingFraction: PurlTune.value("Pages/HomePage.swift:spring:dampingFraction:135:140", default: 0.7)), value: avatarPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in avatarPressed = true }
                        .onEnded { _ in
                            avatarPressed = false
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(.account)
                        }
                )
                .zIndex(1)
    }

    private var topicRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: FeedNavigationStyle.itemSpacing) {
                    ForEach(navigationTopics) { topic in
                        topicButton(topic)
                            .id(topic.id)
                    }

                    // Lets a selected trailing topic settle beside the avatar.
                    Color.clear
                        .frame(width: 240, height: 1)
                        .accessibilityHidden(true)
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.leading, FeedNavigationStyle.avatarSize + GravitySpacing.space8, for: .scrollContent)
            .contentMargins(.trailing, GravitySpacing.space16)
            .mask {
                HStack(spacing: 0) {
                    // Hide content only after it has travelled beneath the
                    // avatar; the hard edge sits behind the circle, never
                    // beside a visible pill.
                    Color.clear.frame(width: 20)
                    Color.black
                }
            }
            .onChange(of: selectedTopicID) { _, topicID in
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    proxy.scrollTo(topicID, anchor: .leading)
                }
            }
        }
    }

    private func topicButton(_ topic: FeedTopic) -> some View {
        Button {
            guard topic.id != "for-you" else {
                guard selectedTopicID != "for-you" || focusedStoryID != nil else { return }
                HapticFeedback.light.fire()
                coordinator.resetScrollState()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    focusedStoryID = nil
                    selectedTopicID = "for-you"
                }
                return
            }

            guard let storyID = topic.storyIDs?.first,
                  let story = PersonalizedFeedStories.all.first(where: { $0.id == storyID }) else {
                return
            }
            HapticFeedback.light.fire()
            coordinator.resetScrollState()
            openTopic(for: story)
        } label: {
            topicLabel(topic)
                .background {
                    if selectedTopicID == topic.id {
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
                            .matchedGeometryEffect(id: "selected-topic", in: topicSelectionNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTopicID == topic.id ? .isSelected : [])
    }

    private func topicLabel(_ topic: FeedTopic) -> some View {
        Text(topic.label)
            .font(FeedNavigationStyle.labelFont)
            .foregroundStyle(topicLabelColor(topic))
            .padding(.horizontal, FeedNavigationStyle.pillHorizontalPadding)
            .frame(height: FeedNavigationStyle.controlSize)
            .contentShape(Capsule())
    }

    private func topicLabelColor(_ topic: FeedTopic) -> Color {
        selectedTopicID == topic.id ? GravityColors.textFixedDark : GravityColors.textFixedLight
    }

}

#Preview {
    @Previewable @Namespace var namespace
    NavigationStack {
        HomePage(namespace: namespace)
    }
    .environment(NavigationCoordinator())
}
