import Foundation

enum FeedEntry: Identifiable {
    case tryOn
    case seasonalSavings
    case story(FeedStory)
    case post(ShopPost)

    var id: String {
        switch self {
        case .tryOn: TryOnExperience.cardID
        case .seasonalSavings: "seasonal-savings"
        case let .story(story): story.id
        case let .post(post): "shop-post-\(post.id)"
        }
    }
}

enum SeasonalPlacement: String, CaseIterable, Identifiable {
    case off
    case header
    case feedCard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .header: "Header"
        case .feedCard: "Feed card"
        }
    }
}

enum ForYouUtilityPresentation {
    case carouselOnly
    case carouselAndFullHeight
}
