import Foundation

/// A broad, shopper-facing channel in Home's primary navigation. Categories
/// are intentionally separate from `FeedTopic`: a category owns a feed of
/// editorial cards, while a topic remains the deeper destination opened by a
/// card. Keeping that distinction explicit prevents specific destinations
/// such as "Coffee counter" from drifting back into the primary tab rail.
struct FeedCategory: Identifiable, Hashable {
    let id: String
    let label: String
    fileprivate let candidateStoryIDs: [String]
    fileprivate let productLayouts: [FeedCardProductLayout]
}

/// The product treatment used inside a full-screen story card. Categories own
/// a repeating recipe instead of letting the view choose a style at random,
/// keeping the feed varied while the merchandising remains predictable.
enum FeedCardProductLayout: String, Hashable {
    case stackedDeck
    case bottomCarousel
    case compactGrid
}

/// The one authoritative Home information architecture. Each category lists
/// both dossier-bundle story IDs and their bundled fallback equivalents, so
/// switching feed sources does not change the navigation model.
enum FeedInformationArchitecture {
    static let categories: [FeedCategory] = [
        FeedCategory(
            id: "for-you",
            label: "For you",
            candidateStoryIDs: [],
            productLayouts: [.stackedDeck, .bottomCarousel, .compactGrid]
        ),
        FeedCategory(
            id: "living",
            label: "Living",
            candidateStoryIDs: [
                "edit-stay-a-while", "edit-mirrors-with-presence",
                "edit-table-as-a-scene", "sculptural-mirror-hunt",
                "table-stranger", "mirrors-floor-presence"
            ],
            productLayouts: [.bottomCarousel, .compactGrid, .stackedDeck]
        ),
        FeedCategory(
            id: "design",
            label: "Design",
            candidateStoryIDs: [
                "edit-design-shelf", "edit-grow-with-them",
                "edit-studio-in-a-bag", "edit-zero-beige-energy",
                "type-systems", "nursery-grown-up-room",
                "new-york-graphics", "type-making-now"
            ],
            productLayouts: [.compactGrid, .stackedDeck, .bottomCarousel]
        ),
        FeedCategory(
            id: "style",
            label: "Style",
            candidateStoryIDs: [
                "edit-salomons-to-know", "edit-zero-beige-energy",
                "edit-studio-in-a-bag", "trail-to-street",
                "black-silver-signal", "trail-light-neutrals"
            ],
            productLayouts: [.bottomCarousel, .stackedDeck, .compactGrid]
        ),
        FeedCategory(
            id: "wellness",
            label: "Wellness",
            candidateStoryIDs: [
                "edit-wash-day-reset", "edit-stay-a-while",
                "scalp-reset", "coffee-cup-ritual"
            ],
            productLayouts: [.stackedDeck, .bottomCarousel, .compactGrid]
        ),
        FeedCategory(
            id: "morning",
            label: "Morning",
            candidateStoryIDs: [
                "edit-coffee-worth-waking-for", "edit-table-as-a-scene",
                "edit-stay-a-while", "coffee-counter",
                "coffee-fellow-workflow", "coffee-kinto-serve",
                "coffee-cup-ritual"
            ],
            productLayouts: [.bottomCarousel, .compactGrid, .stackedDeck]
        ),
        FeedCategory(
            id: "outdoors",
            label: "Outdoors",
            candidateStoryIDs: [
                "edit-gloriously-lost", "edit-salomons-to-know",
                "city-to-trail-birding", "birding-optics-sizes",
                "birding-wet-weather", "trail-weatherproof"
            ],
            productLayouts: [.compactGrid, .bottomCarousel, .stackedDeck]
        )
    ]

    static func stories(
        for category: FeedCategory,
        in catalog: PersonalizedFeedCatalog
    ) -> [FeedStory] {
        let storiesByID = Dictionary(uniqueKeysWithValues: catalog.stories.map { ($0.id, $0) })

        if category.id == "for-you" {
            guard let storyIDs = catalog.topics.first(where: { $0.id == "for-you" })?.storyIDs else {
                return catalog.stories
            }
            return storyIDs.compactMap { storiesByID[$0] }
        }

        return category.candidateStoryIDs.compactMap { storiesByID[$0] }
    }

    static func productLayout(
        for story: FeedStory,
        in category: FeedCategory,
        visibleStoryIndex: Int? = nil
    ) -> FeedCardProductLayout {
        guard !category.productLayouts.isEmpty else {
            return .stackedDeck
        }

        let storyIndex: Int
        if category.id == "for-you" {
            // For You is ordered by the active catalog rather than a fixed ID
            // list. Its visible position keeps the recipe stable while still
            // supporting newly generated stories from the remote feed.
            storyIndex = visibleStoryIndex ?? 0
        } else if let visibleStoryIndex {
            // Profile-authored shelves can introduce canonical stories that
            // are not part of the global category candidate list. Their live
            // position still participates in the same stable layout rhythm.
            storyIndex = visibleStoryIndex
        } else if let candidateIndex = category.candidateStoryIDs.firstIndex(of: story.id) {
            storyIndex = candidateIndex
        } else {
            return .stackedDeck
        }

        return category.productLayouts[storyIndex % category.productLayouts.count]
    }
}

/// A server/data-defined channel in the personalized feed header.
struct FeedTopic: Identifiable, Hashable, Codable {
    /// A curated slice of the topic, phrased as a shopping category rather
    /// than a truncated story title. Tapping opens the referenced story.
    struct Subtopic: Hashable, Codable {
        let label: String
        let storyID: String
        /// Optional anchor product whose real catalog image renders as the
        /// subtopic chip visual. Generated atmosphere stays exclusive to the
        /// topic level; subtopic visuals are always honest product imagery.
        var anchorMerchantID: String? = nil
        var anchorProductID: Int? = nil
    }

    /// Ordered merchandising recipe for a topic destination. The view renders
    /// these blocks in data order instead of imposing one global page template.
    struct MerchandisingBlock: Identifiable, Hashable, Codable {
        enum Kind: String, Hashable, Codable {
            case mediaCarousel
            case merchantRail
            case productRail
            case masonry
            /// A packed box of role-based compartments. Items carry a `role`
            /// ("See", "Wear", "Keep shopping") and an optional `size`;
            /// unsized compartments are sized by shopper signal strength.
            case bento
        }

        struct Item: Hashable, Codable {
            enum Kind: String, Hashable, Codable {
                case story
                case merchant
                case product
                /// Bento only: tall brand card — the merchant's cover as the
                /// surface, identity header up top, two shoppable product
                /// chips floating at the bottom. Wants a tall cell (author it
                /// first in a run of standards so it anchors the trio).
                case merchantSpotlight
                /// Bento only: a loose grid of circular shop avatars floating
                /// chrome-free on the topic surface. Each disc opens a store.
                case avatarCluster
                /// Bento only: portrait generated film paired with every
                /// product referenced by the same story in a compact mosaic.
                case videoProductMosaic
            }

            let kind: Kind
            let storyID: String?
            let merchantID: String?
            let productID: Int?
            /// merchantSpotlight only: the two products for the chips.
            var productIDs: [Int]? = nil
            /// avatarCluster only: the shops in the cluster (4 for a square
            /// cell, 6 for a tall one).
            var merchantIDs: [String]? = nil
            /// Bento only: the compartment's stated purpose. Every bento
            /// compartment must explain why it exists.
            var role: String? = nil
            /// Bento only: explicit cell size (`hero`, `wide`, `standard`).
            /// Omit to let signal strength decide.
            var size: String? = nil
        }

        let id: String
        let kind: Kind
        let title: String?
        let items: [Item]?
    }

    let id: String
    let label: String
    let storyTopicKey: String?
    /// Optional explicit ordering. When present, this is authoritative over
    /// topic-key filtering and lets each channel be curated independently.
    let storyIDs: [String]?
    /// Optional editorial subtopic pills shown in the topic header.
    let subtopics: [Subtopic]?
    /// Curated merchants related to the topic beyond the ones its stories
    /// already reference. Appended after product-derived merchants.
    let relatedMerchantIDs: [String]?
    /// Optional ordered page composition. Older/single-story destinations
    /// fall back to the standard merchant + masonry structure.
    let merchandisingBlocks: [MerchandisingBlock]?
}
