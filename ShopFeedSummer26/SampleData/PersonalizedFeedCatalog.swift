import Foundation
import SwiftUI

struct PersonalizedFeedCatalog: Codable {
    let version: Int
    let topics: [FeedTopic]
    let stories: [FeedStory]
    /// Authored shopper-intent fixtures (cart, owned, viewed, searches).
    var signals: ShopperSignals? = nil

    static let current: PersonalizedFeedCatalog = {
        guard let asset = NSDataAsset(name: "personalized-feed"),
              let catalog = try? JSONDecoder().decode(PersonalizedFeedCatalog.self, from: asset.data) else {
            assertionFailure("personalized-feed.json is missing or invalid")
            return .fallback
        }
        return catalog
    }()

    /// Keeps previews and development builds renderable if the data asset is
    /// temporarily malformed while editing the feed schema.
    private static let fallback = PersonalizedFeedCatalog(
        version: 1,
        topics: [FeedTopic(id: "for-you", label: "For you", storyTopicKey: nil, storyIDs: ["fallback-story"], subtopics: nil, relatedMerchantIDs: nil, merchandisingBlocks: nil)],
        stories: [
            FeedStory(
                id: "fallback-story",
                eyebrow: "",
                title: "Personalized picks",
                subtitle: "",
                format: .shortlist,
                topicKeys: [],
                accentHex: "#244D3A",
                coverImageName: nil,
                destinationLabel: "Explore",
                products: []
            )
        ]
    )
}

/// Compatibility namespace used by views while the eventual feed source may
/// move from a bundled catalog to a generated response.
enum PersonalizedFeedStories {
    static var all: [FeedStory] { PersonalizedFeedCatalog.current.stories }
}
