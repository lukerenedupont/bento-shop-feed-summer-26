import Foundation

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
