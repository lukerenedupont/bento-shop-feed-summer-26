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
                        FloatingBackButton { coordinator.popCurrentPage() }
                        Spacer()
                    }
                    .padding(.horizontal, GravitySpacing.space16)
                    .padding(.vertical, GravitySpacing.space4)
                }
                .onAppear {
                    coordinator.bottomBackSuppressed = true
                    previousNavBarTint = coordinator.navBarBlurTint
                    withAnimation(.easeOut(duration: 0.22)) {
                        coordinator.navBarBlurTint = accent
                    }
                }
                .onDisappear {
                    coordinator.bottomBackSuppressed = false
                    if let previousNavBarTint {
                        withAnimation(.easeOut(duration: 0.22)) {
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
