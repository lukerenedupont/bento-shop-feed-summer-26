import Foundation

/// Navigation routes used by all pages that push store or product destinations.
enum HomeRoute: Hashable {
    case product(merchantId: String, productId: Int)
    case store(merchantId: String)
    case story(storyId: String)
    /// Opens the original topic page through its source feed card.
    case topicExpanded(topicId: String, sourceStoryId: String)
    case deliveries
    case deliveryDetail(deliveryId: String)
    case account
    case explore
}
