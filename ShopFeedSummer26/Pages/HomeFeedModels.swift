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

enum WorldPrototypeFeedOrdering {
    static func prioritizeTryOn(
        in entries: [FeedEntry],
        enabledWorldIDs: Set<String>
    ) -> [FeedEntry] {
        guard enabledWorldIDs.contains(WorldPrototypeCatalog.tryOnID) else { return entries }
        var result = entries.filter {
            if case .tryOn = $0 { return false }
            return true
        }
        let worldsBeforeTryOn = WorldPrototypeCatalog.topLevelWorldIDs
            .prefix { $0 != WorldPrototypeCatalog.tryOnID }
            .filter(enabledWorldIDs.contains)
            .count
        result.insert(.tryOn, at: min(worldsBeforeTryOn, result.count))
        return result
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
