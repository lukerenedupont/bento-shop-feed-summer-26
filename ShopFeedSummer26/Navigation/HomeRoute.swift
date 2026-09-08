import Foundation

/// Navigation routes used by all pages that push store or product destinations.
enum HomeRoute: Hashable {
    case product(merchantId: String, productId: Int)
    case store(merchantId: String)
    /// Opens a story, optionally naming the matched transition source that
    /// initiated the push. Home feed cards provide their own story ID; topic
    /// chrome keeps using the legacy subtopic source when this is nil.
    case story(
        storyId: String,
        sourceId: String? = nil,
        giftRecipientName: String? = nil
    )
    /// A shopper-authored feed creates stories at planning time rather than
    /// storing them in the authored catalog, so the route carries that story.
    case customStory(story: FeedStory, sourceId: String)
    /// Opens the original topic page through its source feed card.
    case topicExpanded(topicId: String, sourceStoryId: String)
    case tryOnStudio
    case tryFavesWorld
    /// Opens a Try Faves garment's product page. Those garments are authored
    /// outside `SampleMerchant`, so they resolve through `TryFavesCatalog`
    /// and render the PDP's agent-product form.
    case tryFavesProduct(variantID: String)
    case deliveries
    case deliveryDetail(deliveryId: String)
    case account
    case explore
}
