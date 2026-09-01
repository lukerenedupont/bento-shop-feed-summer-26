import SwiftUI

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

extension FeedStory {
    var rendersAsMerchantCard: Bool {
        id != "kyle-argizari-lighting"
            && MerchantCollectionCatalog.presentation(for: id) != nil
    }
}

extension FeedEntry {
    var usesBottomAnchoredWorldChrome: Bool {
        guard case .story(let story) = self, story.format == .world else { return false }
        return !story.rendersAsMerchantCard
    }
}

enum FeedCompositionFilter {
    @MainActor
    static func apply(
        to entries: [FeedEntry],
        feedID: String,
        enabledWorldIDs: Set<String>
    ) -> [FeedEntry] {
        let preferences = FeedCompositionPreferences.shared
        return entries.filter { entry in
            switch entry {
            case .post:
                preferences.isEnabled(.posts, in: feedID)
            case .story(let story):
                enabledWorldIDs.contains(story.id)
                    || preferences.isEnabled(
                        story.rendersAsMerchantCard ? .merchantCards : .recommendations,
                        in: feedID
                    )
            case .tryOn:
                enabledWorldIDs.contains(WorldPrototypeCatalog.tryOnID)
                    || preferences.isEnabled(.recommendations, in: feedID)
            case .seasonalSavings:
                true
            }
        }
    }
}

private struct FeedFeedbackPositionModifier: ViewModifier {
    let entry: FeedEntry
    let layout: FeedViewportLayout
    let showsAnchoredControls: Bool
    @State private var reservesExploreSpace = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if entry.usesBottomAnchoredWorldChrome {
            let railHeight = max((layout.cardWidth - 64) / 2, 144)
            content
                .padding(.bottom, railHeight + 32 + (reservesExploreSpace ? 56 : 0))
                .padding(.trailing, GravitySpacing.space12)
                .frame(maxHeight: .infinity, alignment: .bottomTrailing)
                .opacity(showsAnchoredControls ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: showsAnchoredControls)
                .task(id: "\(entry.id)-\(showsAnchoredControls)") {
                    reservesExploreSpace = false
                    guard showsAnchoredControls else { return }
                    try? await Task.sleep(for: .milliseconds(750))
                    guard !Task.isCancelled, showsAnchoredControls else { return }
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        reservesExploreSpace = true
                    }
                }
        } else {
            content
                .padding(.top, layout.pinnedTitleTop)
                .padding(.trailing, GravitySpacing.space12)
                .visualEffect { actions, geometry in
                    let distance = max(geometry.frame(in: .scrollView).minY - layout.pinnedTitleTop, 0)
                    let progress = min(max(1 - distance / 100, 0), 1)
                    return actions.opacity(progress)
                }
        }
    }
}

extension View {
    func positionedFeedFeedback(
        for entry: FeedEntry,
        layout: FeedViewportLayout,
        showsAnchoredControls: Bool
    ) -> some View {
        modifier(FeedFeedbackPositionModifier(
            entry: entry,
            layout: layout,
            showsAnchoredControls: showsAnchoredControls
        ))
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
