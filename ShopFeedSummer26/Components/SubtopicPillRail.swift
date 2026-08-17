import SwiftUI

/// Single source of truth for the floating feed/topic navigation chrome.
/// Keep these values centralized so home, topic, and drill-in rails never
/// drift as the navigation evolves.
enum FeedNavigationStyle {
    static let avatarSize: CGFloat = 40
    static let controlSize: CGFloat = 40
    static let iconSize: CGFloat = 15
    static let labelSize: CGFloat = 17
    static let pillHorizontalPadding: CGFloat = GravitySpacing.space16
    static let itemSpacing: CGFloat = GravitySpacing.space4
    static let railLeadingInset: CGFloat = 64
    static let railTrailingInset: CGFloat = GravitySpacing.space20
    static let selectedFill = Color.white.opacity(0.94)

    static let labelFont = Font.system(size: labelSize, weight: .semibold)
    static let iconFont = Font.system(size: iconSize, weight: .semibold)
}

/// Horizontal rail of subtopic pills that shares the top bar with the
/// floating back chip on topic pages — chrome, not scrolled content, so it
/// stays crisp above the scroll-edge blur and fills what was dead
/// atmosphere at the top of the cover.
struct SubtopicPillRail: View {
    let topic: FeedTopic
    let stories: [FeedStory]
    let merchants: [SampleMerchant]

    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        if showsRail {
            // The rail spans the full bar width and slides beneath the back
            // chip; the mask fades pills out as they pass behind it instead
            // of clipping them on a hard edge.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FeedNavigationStyle.itemSpacing) {
                    ForEach(pills, id: \.storyID) { subtopic in
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(.story(storyId: subtopic.storyID))
                        } label: {
                            Text(subtopic.label)
                                .font(FeedNavigationStyle.labelFont)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, FeedNavigationStyle.pillHorizontalPadding)
                                .frame(height: FeedNavigationStyle.controlSize)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Rest position clears the 44pt back chip (16 + 44 + 8).
                .padding(.leading, FeedNavigationStyle.railLeadingInset)
                .padding(.trailing, FeedNavigationStyle.railTrailingInset)
            }
        }
    }

    /// A single-story landing (a drilled-in subcategory) hides pills that
    /// would only link back to itself.
    private var showsRail: Bool {
        !(stories.count == 1 && topic.subtopics == nil)
    }

    /// Curated subtopic pills; falls back to story titles for topics that
    /// have not been given editorial subtopics yet.
    private var pills: [FeedTopic.Subtopic] {
        if let subtopics = topic.subtopics, !subtopics.isEmpty { return subtopics }
        return stories.map { .init(label: shortLabel(for: $0), storyID: $0.id) }
    }

    /// Resolves a subtopic's anchor SKU for the chip visual. Returns nil for
    /// subtopics without anchors, which render as text-only pills.
    private func anchorProduct(for subtopic: FeedTopic.Subtopic) -> ResolvedStoryProduct? {
        guard let merchantID = subtopic.anchorMerchantID,
              let productID = subtopic.anchorProductID,
              let merchant = merchants.first(where: { $0.id == merchantID }),
              let product = merchant.products.first(where: { $0.id == productID }) else { return nil }
        return ResolvedStoryProduct(merchant: merchant, product: product)
    }

    private func shortLabel(for story: FeedStory) -> String {
        let words = story.title.split(separator: " ")
        return words.prefix(3).joined(separator: " ")
    }
}

#Preview("Subtopic pill rail") {
    let topic = PersonalizedFeedCatalog.current.topics.first { $0.id == "birding-gear" }!
    let stories = PersonalizedFeedStories.all.filter { story in
        topic.storyIDs?.contains(story.id) ?? story.topicKeys.contains(topic.storyTopicKey ?? "")
    }

    HStack(spacing: 8) {
        FloatingBackButton {}
        SubtopicPillRail(topic: topic, stories: stories, merchants: SampleMerchant.previews)
    }
    .padding(.leading, 16)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
    .background(Color(hex: "#4A4432"))
    .environment(NavigationCoordinator())
}
