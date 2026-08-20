import SwiftUI

/// Pushed topic destination. Opening a world from a feed card zooms in via
/// the system navigation transition (source registered on the card), so the
/// card scales seamlessly into this page's full-bleed header.
struct TopicPage: View {
    let topicId: String

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var previousNavBarTint: Color?

    private var merchants: [SampleMerchant] { SampleMerchant.all }

    private var topic: FeedTopic? {
        PersonalizedFeedCatalog.current.topics.first { $0.id == topicId }
    }

    private var stories: [FeedStory] {
        guard let topic else { return [] }
        let all = PersonalizedFeedStories.all
        if let storyIDs = topic.storyIDs {
            let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
            return storyIDs.compactMap { byID[$0] }
        }
        guard let key = topic.storyTopicKey else { return all }
        return all.filter { $0.topicKeys.contains(key) }
    }

    private var headerImageURL: URL? {
        guard let leadStory = stories.first,
              let presentation = FeedCoverCatalog.presentation(for: leadStory) else {
            return nil
        }
        return presentation.coverURL(from: merchants)
    }

    private var headerVideoURL: URL? {
        guard let leadStory = stories.first else { return nil }
        return FeedCoverCatalog.presentation(for: leadStory)?.source.videoURL
    }

    var body: some View {
        if let topic {
            let accent = Color(hex: stories.first?.accentHex ?? "#171717")
            TopicLandingView(
                topic: topic,
                stories: stories,
                merchants: merchants,
                headerImageURL: headerImageURL,
                headerVideoURL: headerVideoURL
            )
                .environment(\.colorScheme, .dark)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaBar(edge: .top) {
                    // Chip floats over the rail: pills slide beneath it and
                    // fade out via the rail's leading mask.
                    ZStack(alignment: .leading) {
                        // Subtopics share the chip's row — chrome, not
                        // scrolled content, so they stay crisp above the
                        // scroll-edge blur and reclaim dead atmosphere.
                        SubtopicPillRail(topic: topic, stories: stories, merchants: merchants)
                        FloatingBackButton {
                            // Bring the bar back the moment the pop starts —
                            // waiting for onDisappear reads as lag.
                            withAnimation(.easeOut(duration: 0.15)) {
                                coordinator.showNavBar = true
                                if let previousNavBarTint {
                                    coordinator.navBarBlurTint = previousNavBarTint
                                }
                            }
                            coordinator.popCurrentPage()
                        }
                        .padding(.leading, GravitySpacing.space16)
                    }
                    // Keep the chip pinned leading even when the pill rail
                    // is hidden (single-story landings) — otherwise the bar
                    // shrinks to the chip and centers it.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, GravitySpacing.space4)
                }
                .onAppear {
                    previousNavBarTint = coordinator.navBarBlurTint
                    withAnimation(.easeOut(duration: 0.22)) {
                        // Topics are immersive: the top back chip is the only
                        // chrome, so the bottom nav steps out entirely.
                        coordinator.showNavBar = false
                        coordinator.navBarBlurTint = accent
                    }
                }
                .onDisappear {
                    // Fallback for swipe-back pops; idempotent after the chip.
                    withAnimation(.easeOut(duration: 0.15)) {
                        coordinator.showNavBar = true
                        if let previousNavBarTint {
                            coordinator.navBarBlurTint = previousNavBarTint
                        }
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        TopicPage(topicId: "birding-gear")
    }
    .environment(NavigationCoordinator())
}
