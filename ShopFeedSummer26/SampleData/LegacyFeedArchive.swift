import Foundation

/// The richer editorial catalog that powered the topic pills before Home moved
/// to dossier-feed-bundle. It remains separate from the active hero feed so the
/// new cards keep their dossier data while expanded cards can draw from this
/// deeper, complementary browsing graph.
@MainActor
enum LegacyFeedArchive {
    static let catalog = PersonalizedFeedCatalog.bundled
    static let merchants = LocalMerchantService.loadMerchants()

    static func topic(id: String) -> FeedTopic? {
        catalog.topics.first { $0.id == id }
    }

    static func stories(for topic: FeedTopic) -> [FeedStory] {
        guard let storyIDs = topic.storyIDs else {
            guard let key = topic.storyTopicKey else { return catalog.stories }
            return catalog.stories.filter { $0.topicKeys.contains(key) }
        }
        let storiesByID = Dictionary(uniqueKeysWithValues: catalog.stories.map { ($0.id, $0) })
        return storyIDs.compactMap { storiesByID[$0] }
    }
}
