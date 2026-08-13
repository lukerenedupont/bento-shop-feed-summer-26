import SwiftUI

/// A pushed destination that renders a single story with the same landing
/// grammar as a topic feed — cover/accent header, merchants, and masonry —
/// so drilling into a subcategory feels identical to opening its topic.
struct StoryTopicPage: View {
    let storyID: String

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var previousNavBarTint: Color?

    private var merchants: [SampleMerchant] { SampleMerchant.all }
    private var story: FeedStory? {
        PersonalizedFeedStories.all.first { $0.id == storyID }
    }

    /// The parent topic whose feed contains this story — its cover and
    /// sampled accent carry through so drill-ins stay in the same world.
    private var parentTopic: FeedTopic? {
        PersonalizedFeedCatalog.current.topics.first {
            $0.id != "for-you" && ($0.storyIDs?.contains(storyID) ?? false)
        }
    }

    private var parentLeadStory: FeedStory? {
        guard let leadID = parentTopic?.storyIDs?.first else { return nil }
        return PersonalizedFeedStories.all.first { $0.id == leadID }
    }

    var body: some View {
        if let story {
            TopicLandingView(
                topic: FeedTopic(
                    id: story.id,
                    label: story.title,
                    storyTopicKey: nil,
                    storyIDs: [story.id],
                    subtopics: nil,
                    relatedMerchantIDs: nil,
                    merchandisingBlocks: nil
                ),
                stories: [story],
                merchants: merchants,
                headerCoverImageName: parentLeadStory?.coverImageName,
                surfaceAccentHex: parentLeadStory?.accentHex ?? story.accentHex
            )
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
                    coordinator.navBarBlurTint = Color(hex: parentLeadStory?.accentHex ?? story.accentHex)
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
        StoryTopicPage(storyID: FeedStory.preview.id)
    }
    .environment(NavigationCoordinator())
}
