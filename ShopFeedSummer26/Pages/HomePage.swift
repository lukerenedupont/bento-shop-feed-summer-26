import Combine
import SwiftUI

/// Home feed — scrollable merchant feed cards with focused topic feeds.
struct HomePage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    @ObservedObject private var merchantService = RemoteMerchantService.shared
    @Namespace private var heroNamespace
    @Namespace private var topicSelectionNamespace

    /// Buyer-profile-curated products bundled from official merchant catalogs.
    @State private var merchants: [SampleMerchant] = LocalMerchantService.loadMerchants()
    @State private var selectedTopicID = "for-you"
    /// A drilled-in subcategory story rendered inline so the top bar stays.
    @State private var focusedStoryID: String?

    private var topics: [FeedTopic] { PersonalizedFeedCatalog.current.topics }
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

    var body: some View {
        Group {
            if let focusedStoryID {
                StoryTopicPage(storyID: focusedStoryID)
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
        .environment(\.colorScheme, selectedTopicID == "for-you" && focusedStoryID == nil ? .light : .dark)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            // Keep the curated assortment authoritative for this prototype and
            // expose it to PDP/store lookups through SampleMerchant.all.
            merchantService.merchants = merchants
            merchantService.usingFallbackData = true
            coordinator.navBarBlurTint = pageBackgroundColor
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

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(focusedStories) { story in
                        StoryFeedCard(
                            story: story,
                            merchants: merchants,
                            width: cardWidth,
                            height: cardHeight,
                            onTap: { openTopic(for: story) }
                        )
                        .matchedTransitionSource(id: story.id, in: heroNamespace)
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

        coordinator.resetScrollState()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            focusedStoryID = nil
            selectedTopicID = destination.id
        }
    }

    // MARK: - Top Bar (Quick Links)

    @State private var avatarPressed = false

    private var topBar: some View {
        HStack(spacing: 0) {
            avatar

            // Topic feeds
            topicRail
        }
        .padding(.horizontal, PurlTune.token("Pages/HomePage.swift:padding:_:164:31", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
        .padding(.vertical, PurlTune.token("Pages/HomePage.swift:padding:_:165:29", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        // Topic pages bleed their cover image behind the pills; For You keeps
        // an opaque header so cards never collide with the controls.
        .background(selectedTopicID == "for-you" && focusedStoryID == nil ? pageBackgroundColor : Color.clear)
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
                .frame(width: PurlTune.value("Pages/HomePage.swift:frame:width:131:31", default: 40), height: PurlTune.value("Pages/HomePage.swift:frame:height:131:111", default: 40))
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
                .onChange(of: selectedTopicID) { _, topicID in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        proxy.scrollTo(topicID, anchor: .leading)
                    }
                }
            }
    }

    private func topicButton(_ topic: FeedTopic) -> some View {
        Button {
            guard selectedTopicID != topic.id || focusedStoryID != nil else { return }
            HapticFeedback.light.fire()
            coordinator.resetScrollState()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                focusedStoryID = nil
                selectedTopicID = topic.id
            }
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
            .gravityTextStyle(GravityTypography.bodyTitleSmall)
            .foregroundStyle(topicLabelColor(topic))
            .padding(.horizontal, PurlTune.token("Pages/HomePage.swift:padding:_:181:37", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.vertical, PurlTune.token("Pages/HomePage.swift:padding:_:182:37", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
            .contentShape(Capsule())
    }

    private func topicLabelColor(_ topic: FeedTopic) -> Color {
        guard selectedTopicID != "for-you" else { return GravityColors.textFixedDark }
        return selectedTopicID == topic.id ? GravityColors.textFixedDark : GravityColors.textFixedLight
    }

}

#Preview {
    NavigationStack {
        HomePage()
    }
    .environment(NavigationCoordinator())
}
