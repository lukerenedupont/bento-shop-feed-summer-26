import SwiftUI

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
                HStack(spacing: 8) {
                    ForEach(pills, id: \.storyID) { subtopic in
                        let anchor = anchorProduct(for: subtopic)
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(.story(storyId: subtopic.storyID))
                        } label: {
                            HStack(spacing: 8) {
                                if let anchor {
                                    // Real catalog imagery, never generated:
                                    // the chip visual is the anchor SKU.
                                    ProductImageView(product: anchor.product, merchant: anchor.merchant, fallbackIndex: 0)
                                        .frame(width: 32, height: 32)
                                        .background(.white)
                                        .clipShape(Circle())
                                        .overlay { Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5) }
                                }
                                Text(subtopic.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.leading, anchor != nil ? 6 : 15)
                            .padding(.trailing, 15)
                            .frame(height: 44)
                            .background(.black.opacity(0.28), in: Capsule())
                            .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5) }
                            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Rest position clears the 44pt back chip (16 + 44 + 8).
                .padding(.leading, 68)
                .padding(.trailing, 16)
            }
            .mask {
                HStack(spacing: 0) {
                    // Fully transparent under the chip, easing to opaque
                    // just past its trailing edge.
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .clear, location: 0.62),
                            .init(color: .black, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 84)
                    Color.black
                }
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
