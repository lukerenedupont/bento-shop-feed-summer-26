import Combine
import SwiftUI

/// Home feed — the For You story stream. Topics and subcategories are
/// pushed destinations that zoom in from their cards; this page carries the
/// avatar and topic pills, which only exist here.
struct HomePage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    /// Shared with RootView so pushed topics can zoom from their feed card.
    let namespace: Namespace.ID

    @Environment(NavigationCoordinator.self) private var coordinator
    @ObservedObject private var merchantService = RemoteMerchantService.shared

    /// Buyer-profile-curated products bundled from official merchant catalogs.
    @State private var merchants: [SampleMerchant] = LocalMerchantService.loadMerchants()

    private var topics: [FeedTopic] { PersonalizedFeedCatalog.current.topics }

    private var stories: [FeedStory] { PersonalizedFeedStories.all }

    var body: some View {
        storyFeed
            .background(Color.white.ignoresSafeArea())
            .safeAreaBar(edge: .top) {
                topBar
            }
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                // Keep the curated assortment authoritative for this prototype and
                // expose it to PDP/store lookups through SampleMerchant.all.
                merchantService.merchants = merchants
                merchantService.usingFallbackData = true
                coordinator.navBarBlurTint = .white
            }
            .purlInjectable()
    }

    private var storyFeed: some View {
        GeometryReader { geo in
            let cardWidth = min(geo.size.width - 32, 377)
            let cardHeight = cardWidth * 1.71

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(stories) { story in
                        StoryFeedCard(
                            story: story,
                            merchants: merchants,
                            width: cardWidth,
                            height: cardHeight,
                            onTap: { openTopic(for: story) }
                        )
                        // Source for the system zoom into the pushed topic.
                        .matchedTransitionSource(id: "topic-hero-\(story.id)", in: namespace)
                        .id(story.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.top, max((geo.size.height - cardHeight) / 2 - 40, 8))
                .padding(.bottom, max((geo.size.height - cardHeight) / 2, 8))
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
                coordinator.updateScrollOffset(offset)
            }
        }
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

        // The tapped card is the zoom source; the pushed topic scales out of it.
        coordinator.pushRoute(.topic(topicId: destination.id, sourceStoryId: story.id))
    }

    // MARK: - Top Bar (Quick Links)

    @State private var avatarPressed = false

    /// Pinterest-style navigation: the avatar + topic rail only exist here on
    /// the For You feed. Pushed topic/subcategory pages carry their own back chip.
    private var topBar: some View {
        HStack(spacing: 0) {
            avatar

            // Topic feeds
            topicRail
        }
        .padding(.horizontal, PurlTune.token("Pages/HomePage.swift:padding:_:164:31", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .padding(.vertical, PurlTune.token("Pages/HomePage.swift:padding:_:165:29", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        .background(Color.white)
    }

    private var avatar: some View {
        Image("luke-avatar")
                .resizable()
                .scaledToFill()
                .frame(width: PurlTune.value("Pages/HomePage.swift:frame:width:131:31", default: 40), height: PurlTune.value("Pages/HomePage.swift:frame:height:131:111", default: 40))
                .clipShape(Circle())
                .matchedTransitionSource(id: "account-avatar", in: namespace)
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
                    HStack(spacing: GravitySpacing.space4) {
                        ForEach(topics) { topic in
                            topicButton(topic)
                                .id(topic.id)
                        }

                        // Gives the final topics enough trailing scroll range to
                        // become the first visible pill beside the avatar.
                        Color.clear
                            .frame(width: 280, height: 1)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, PurlTune.value("Pages/HomePage.swift:padding:_:155:37", default: 20))
                }
                .scrollIndicators(.hidden)
                .contentMargins(.leading, 20 / 2 + GravitySpacing.space4)
                .contentMargins(.trailing, GravitySpacing.space16)
                .padding(.vertical, PurlTune.value("Pages/HomePage.swift:padding:_:160:33", default: -20))
                .padding(.leading, -20 / 2)
                .padding(.trailing, -GravitySpacing.space16)
            }
    }

    /// "For you" is this page itself (selected pill); other topics push their
    /// world, zooming from the lead story's card when it's on screen.
    private func topicButton(_ topic: FeedTopic) -> some View {
        Button {
            guard topic.id != "for-you" else { return }
            HapticFeedback.light.fire()
            coordinator.pushRoute(.topic(topicId: topic.id, sourceStoryId: topic.storyIDs?.first))
        } label: {
            topicLabel(topic)
                .background {
                    if topic.id == "for-you" {
                        Capsule()
                            .fill(Color.white.opacity(0.92))
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(topic.id == "for-you" ? .isSelected : [])
    }

    private func topicLabel(_ topic: FeedTopic) -> some View {
        Text(topic.label)
            .gravityTextStyle(GravityTypography.bodyTitleSmall)
            .foregroundStyle(GravityColors.textFixedDark)
            .padding(.horizontal, PurlTune.token("Pages/HomePage.swift:padding:_:181:37", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.vertical, PurlTune.token("Pages/HomePage.swift:padding:_:182:37", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
            .contentShape(Capsule())
    }
}

#Preview {
    @Previewable @Namespace var ns
    NavigationStack {
        HomePage(namespace: ns)
    }
    .environment(NavigationCoordinator())
}
