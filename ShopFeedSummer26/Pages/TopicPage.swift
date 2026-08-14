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

    var body: some View {
        if let topic {
            let accent = Color(hex: stories.first?.accentHex ?? "#171717")
            TopicLandingView(topic: topic, stories: stories, merchants: merchants)
                .environment(\.colorScheme, .dark)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaBar(edge: .top) {
                    HStack {
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
                        Spacer()
                    }
                    .padding(.horizontal, GravitySpacing.space16)
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
