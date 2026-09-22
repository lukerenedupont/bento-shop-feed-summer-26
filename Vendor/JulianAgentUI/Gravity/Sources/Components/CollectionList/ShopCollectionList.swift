import SwiftUI

public enum ShopCollectionListContentState: Equatable, Sendable {
    case loading
    case error
    case empty
    case content
}

public enum ShopCollectionListLoadingPlaceholderKind: Equatable, Sendable {
    case initial
    case pagination
}

public struct ShopCollectionListLoadingPlaceholderContext: Equatable, Sendable {
    public let kind: ShopCollectionListLoadingPlaceholderKind
    public let index: Int
    public let count: Int

    public init(
        kind: ShopCollectionListLoadingPlaceholderKind,
        index: Int,
        count: Int
    ) {
        self.kind = kind
        self.index = index
        self.count = count
    }
}

public struct ShopCollectionListDefaultLoadingPlaceholder: View {
    private let context: ShopCollectionListLoadingPlaceholderContext

    public init(context: ShopCollectionListLoadingPlaceholderContext) {
        self.context = context
    }

    public var body: some View {
        HStack {
            Spacer(minLength: .zero)
            ShopSpinner(size: .medium, color: GravityColor.textTertiary)
            Spacer(minLength: .zero)
        }
        .padding(.vertical, verticalPadding)
        .background(GravityColor.bg)
    }

    private var verticalPadding: CGFloat {
        switch context.kind {
        case .initial:
            GravitySpacing.space48
        case .pagination:
            GravitySpacing.space24
        }
    }
}

/// Scroll activity reported by the underlying collection view.
///
/// `decelerating` covers momentum and programmatic animation: the finger is up but the scroll view
/// is still moving. Consumers that translate an ancestor of the scroll view must not treat it as an
/// interaction, and must not commit a resting position until `idle`.
public enum ShopCollectionListScrollPhase: Equatable, Sendable {
    case interacting
    case decelerating
    case idle
}

public enum ShopCollectionListRefreshStyle: Equatable, Sendable {
    /// System `UIRefreshControl` spinner. Opt in with `.refreshStyle(.system)`.
    case system
    /// Branded Shop spinner (default). The system spinner is hidden; the underlying refresh control
    /// still owns the pull gesture and begin/end semantics.
    case shopIndicator
}

public extension ShopCollectionList {
    /// Attaches an imperative scroll-view handle to this collection list's backing `UICollectionView`.
    func scrollViewProxy(_ proxy: ShopScrollViewProxy?) -> Self {
        var copy = self
        copy.scrollViewProxy = proxy
        return copy
    }

    /// Selects the pull-to-refresh indicator style. Defaults to `.shopIndicator` (the branded Shop
    /// spinner); pass `.system` to opt out to the native `UIRefreshControl` spinner. Only takes
    /// effect when `onRefresh` is set.
    ///
    /// Exposed as a modifier (rather than an initializer parameter) so it does not have to be
    /// threaded through every convenience initializer; presentation-only knobs belong on modifiers,
    /// data stays in `init`.
    func refreshStyle(_ style: ShopCollectionListRefreshStyle) -> Self {
        var copy = self
        copy.refreshStyle = style
        return copy
    }

    /// Hides the represented `UICollectionView` and its hosted rows from accessibility while
    /// preserving the mounted list and its scroll/data state.
    func accessibilityElementsHidden(_ hidden: Bool) -> Self {
        var copy = self
        copy.hidesAccessibilityElements = hidden
        return copy
    }

    func automaticTopScrollEdgeEffect(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.usesAutomaticTopScrollEdgeEffect = enabled
        return copy
    }
}

public struct ShopCollectionList<SectionID: Hashable & Sendable, Item: Identifiable & Hashable & Sendable, RowContent: View, HeaderContent: View, InitialLoadingPlaceholderContent: View, LoadingPlaceholderContent: View, EmptyContent: View, ErrorContent: View>: View where Item.ID: Hashable & Sendable {
    public typealias Section = ShopCollectionListSection<SectionID, Item>

    private let state: ShopCollectionListContentState
    private let sections: [Section]
    private let layout: ShopCollectionListLayout
    private let contentInsets: ShopCollectionListContentInsets
    private let contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior
    private let animatesMembershipChanges: Bool
    private let pinsToTopUntilUserScrolls: Bool
    private let suppressesSelfSizingAnimations: Bool
    private let alwaysSuppressesSelfSizingAnimations: Bool
    private let showsIndicators: Bool
    private let isRefreshing: Bool
    private let isPaginating: Bool
    private let initialLoadingPlaceholderCount: Int
    private let paginationLoadingPlaceholderCount: Int
    private let endReachedLeadDistance: CGFloat
    private let endReachedRearmToken: AnyHashable?
    private let onRefresh: (() async -> Void)?
    private let onEndReached: (() -> Void)?
    private let onScrollOffsetChange: ((CGFloat) -> Void)?
    private let onUserScroll: (() -> Void)?
    private let onScrollPhaseChange: ((ShopCollectionListScrollPhase) -> Void)?
    private let onContentSizeChange: ((CGFloat) -> Void)?
    private let initialLoadingPlaceholderContent: (ShopCollectionListLoadingPlaceholderContext) -> InitialLoadingPlaceholderContent
    private let loadingPlaceholderContent: (ShopCollectionListLoadingPlaceholderContext) -> LoadingPlaceholderContent
    private let emptyContent: () -> EmptyContent
    private let errorContent: () -> ErrorContent
    private let rowContent: (Item) -> RowContent
    private let headerContent: (Section) -> HeaderContent
    private var refreshStyle: ShopCollectionListRefreshStyle = .shopIndicator
    private var hidesAccessibilityElements = false
    private var usesAutomaticTopScrollEdgeEffect = false
    private var scrollViewProxy: ShopScrollViewProxy?
    // Keyboard overlap published by a `tracksKeyboardHeight()` ancestor (0 otherwise, so callers
    // without that ancestor are unaffected). Folded into the bottom content inset below so the last
    // rows scroll clear of the keyboard without resizing the list's frame.
    @Environment(\.shopKeyboardHeight) private var shopKeyboardHeight: CGFloat

    /// `animatesMembershipChanges` opts a caller into animated row/section insert and removal. When
    /// `true` and the item-ID set changes (a true membership change), the snapshot is applied with
    /// `animatingDifferences: true` so UICollectionView animates the insert/delete; content-only
    /// updates (stable IDs) stay non-animated on the reconfigure path. Defaults to `false`, so every
    /// other consumer applies snapshots without animation exactly as before.
    ///
    /// `pinsToTopUntilUserScrolls` opts a caller into holding the list at its resting top across every
    /// content apply until the user first drags. Callers that settle initial data over several applies
    /// (e.g. the cart: loading/placeholder, then content, then async notices / saved-for-later) can
    /// otherwise open scrolled away from the top — UICollectionView preserves the placeholder
    /// snapshot's `contentOffset`, and an animated late insert shifts it downward. Those pre-scroll
    /// applies land non-animated to avoid that shift. Defaults to `false`; once the user scrolls,
    /// their scroll position is never overridden.
    ///
    /// `suppressesSelfSizingAnimations` opts a caller into disabling UIKit animations while opening
    /// and scrolling. `alwaysSuppressesSelfSizingAnimations` extends that suppression to every
    /// content layout pass. Use the always-on option for dynamic-height rows whose size can change
    /// while the list is idle and whose neighboring cells must reposition immediately. Both default
    /// to `false`.
    public init(
        state: ShopCollectionListContentState,
        sections: [Section],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        animatesMembershipChanges: Bool = false,
        pinsToTopUntilUserScrolls: Bool = false,
        suppressesSelfSizingAnimations: Bool = false,
        alwaysSuppressesSelfSizingAnimations: Bool = false,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        isPaginating: Bool = false,
        initialLoadingPlaceholderCount: Int = 1,
        paginationLoadingPlaceholderCount: Int = 1,
        endReachedLeadDistance: CGFloat = 600,
        endReachedRearmToken: AnyHashable? = nil,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        onUserScroll: (() -> Void)? = nil,
        onScrollPhaseChange: ((ShopCollectionListScrollPhase) -> Void)? = nil,
        onContentSizeChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder initialLoadingPlaceholder: @escaping (ShopCollectionListLoadingPlaceholderContext) -> InitialLoadingPlaceholderContent = { context in
            ShopCollectionListDefaultLoadingPlaceholder(context: context)
        },
        @ViewBuilder loadingPlaceholder: @escaping (ShopCollectionListLoadingPlaceholderContext) -> LoadingPlaceholderContent = { context in
            ShopCollectionListDefaultLoadingPlaceholder(context: context)
        },
        @ViewBuilder empty: @escaping () -> EmptyContent,
        @ViewBuilder error: @escaping () -> ErrorContent,
        @ViewBuilder header: @escaping (Section) -> HeaderContent,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.state = state
        self.sections = sections
        self.layout = layout
        self.contentInsets = contentInsets
        self.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
        self.animatesMembershipChanges = animatesMembershipChanges
        self.pinsToTopUntilUserScrolls = pinsToTopUntilUserScrolls
        self.suppressesSelfSizingAnimations = suppressesSelfSizingAnimations
        self.alwaysSuppressesSelfSizingAnimations = alwaysSuppressesSelfSizingAnimations
        self.showsIndicators = showsIndicators
        self.isRefreshing = isRefreshing
        self.isPaginating = isPaginating
        self.initialLoadingPlaceholderCount = initialLoadingPlaceholderCount
        self.paginationLoadingPlaceholderCount = paginationLoadingPlaceholderCount
        self.endReachedLeadDistance = endReachedLeadDistance
        self.endReachedRearmToken = endReachedRearmToken
        self.onRefresh = onRefresh
        self.onEndReached = onEndReached
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onUserScroll = onUserScroll
        self.onScrollPhaseChange = onScrollPhaseChange
        self.onContentSizeChange = onContentSizeChange
        self.initialLoadingPlaceholderContent = initialLoadingPlaceholder
        self.loadingPlaceholderContent = loadingPlaceholder
        self.emptyContent = empty
        self.errorContent = error
        self.headerContent = header
        self.rowContent = row
    }

    private var keyboardAdjustedContentInsets: ShopCollectionListContentInsets {
        guard shopKeyboardHeight > 0 else { return contentInsets }
        var insets = contentInsets
        // `max` (not `+`): when the keyboard is up it already covers the resting bottom chrome
        // (e.g. a floating tab bar), so inset by the larger of the two rather than double-counting.
        insets.bottom = max(insets.bottom, shopKeyboardHeight)
        return insets
    }

    public var body: some View {
        ShopCollectionListRepresentable(
            sections: statefulSections,
            layout: layout,
            contentInsets: keyboardAdjustedContentInsets,
            contentInsetAdjustmentBehavior: contentInsetAdjustmentBehavior,
            itemsHaveEqualContent: stateItemsHaveEqualContent,
            animatesMembershipChanges: animatesMembershipChanges,
            pinsToTopUntilUserScrolls: pinsToTopUntilUserScrolls,
            suppressesSelfSizingAnimations: suppressesSelfSizingAnimations,
            alwaysSuppressesSelfSizingAnimations: alwaysSuppressesSelfSizingAnimations,
            // Only a `.content` apply may animate membership changes. Loading/empty/error placeholder
            // snapshots are membership changes too, so without this the first loading→content
            // transition would animate (the cart's first-open jump).
            isContentState: state == .content,
            // Publish the laid-out height for every settled state; suppress only the transient
            // loading placeholder. Empty/error are terminal states a height-sizing caller must
            // size to, rather than fall back to an oversized default.
            publishesContentSize: state != .loading,
            hidesAccessibilityElements: hidesAccessibilityElements,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            scrollViewProxy: scrollViewProxy,
            onRefresh: onRefresh,
            // Suppress end-reached while a fetch is in flight (`isPaginating`) so the list enforces
            // "one in-flight fetch" itself — callers don't have to nil-gate `onEndReached`, they just
            // set `isPaginating` while loading (which they already do to show the pagination row).
            onEndReached: (state == .content && isPaginating == false) ? onEndReached : nil,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            onScrollPhaseChange: onScrollPhaseChange,
            onContentSizeChange: onContentSizeChange,
            usesShopRefreshIndicator: refreshStyle == .shopIndicator && onRefresh != nil,
            usesAutomaticTopScrollEdgeEffect: usesAutomaticTopScrollEdgeEffect,
            rowReuseKind: stateItemReuseKind,
            header: statefulHeader,
            row: statefulRow
        )
    }

    @ViewBuilder
    private func statefulHeader(for section: ShopCollectionListSection<StateSectionID, StateItem>) -> some View {
        if case let .content(sectionID) = section.id,
           let contentSection = contentSection(for: sectionID) {
            headerContent(contentSection)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func statefulRow(for item: StateItem) -> some View {
        switch item {
        case let .content(contentItem):
            rowContent(contentItem)
        case let .initialLoading(index, count):
            loadingPlaceholder(
                kind: .initial,
                index: index,
                count: count
            )
        case let .paginationLoading(index, count):
            loadingPlaceholder(
                kind: .pagination,
                index: index,
                count: count
            )
        case .empty:
            emptyContent()
        case .error:
            errorContent()
        }
    }

    @ViewBuilder
    private func loadingPlaceholder(
        kind: ShopCollectionListLoadingPlaceholderKind,
        index: Int,
        count: Int
    ) -> some View {
        let context = ShopCollectionListLoadingPlaceholderContext(
            kind: kind,
            index: index,
            count: count
        )

        switch kind {
        case .initial:
            initialLoadingPlaceholderContent(context)
        case .pagination:
            loadingPlaceholderContent(context)
        }
    }

    private var statefulSections: [ShopCollectionListSection<StateSectionID, StateItem>] {
        switch state {
        case .loading:
            return [
                ShopCollectionListSection(
                    id: .initialLoading,
                    items: initialLoadingItems(
                        count: initialLoadingPlaceholderCount
                    )
                ),
            ]
        case .error:
            return [
                ShopCollectionListSection(
                    id: .error,
                    items: [.error]
                ),
            ]
        case .empty:
            return [
                ShopCollectionListSection(
                    id: .empty,
                    items: [.empty]
                ),
            ]
        case .content:
            var contentSections = sections.map { section in
                ShopCollectionListSection(
                    id: StateSectionID.content(section.id),
                    items: section.items.map(StateItem.content),
                    showsHeader: section.showsHeader
                )
            }

            if isPaginating, paginationLoadingPlaceholderCount > 0 {
                contentSections.append(
                    ShopCollectionListSection(
                        id: .paginationLoading,
                        items: paginationLoadingItems(
                            count: paginationLoadingPlaceholderCount
                        )
                    )
                )
            }

            return contentSections
        }
    }

    private func initialLoadingItems(count: Int) -> [StateItem] {
        guard count > 0 else {
            return []
        }

        return (0 ..< count).map { index in
            .initialLoading(index: index, count: count)
        }
    }

    private func paginationLoadingItems(count: Int) -> [StateItem] {
        guard count > 0 else {
            return []
        }

        return (0 ..< count).map { index in
            .paginationLoading(index: index, count: count)
        }
    }

    private func contentSection(for id: SectionID) -> Section? {
        sections.first { section in
            section.id == id
        }
    }

    private func stateItemReuseKind(_ item: StateItem) -> ShopCollectionListRowReuseKind {
        switch item {
        case let .content(contentItem):
            contentItemReuseKind(contentItem)
        case .initialLoading:
            .collectionListInitialLoading
        case .paginationLoading:
            .collectionListPaginationLoading
        case .empty:
            .collectionListEmpty
        case .error:
            .collectionListError
        }
    }

    private func contentItemReuseKind(_ item: Item) -> ShopCollectionListRowReuseKind {
        (item as? any ShopCollectionListReusableItem)?.collectionListReuseKind ?? .default
    }

    private func stateItemsHaveEqualContent(_ lhs: StateItem, _ rhs: StateItem) -> Bool {
        switch (lhs, rhs) {
        case let (.content(lhsItem), .content(rhsItem)):
            lhsItem == rhsItem
        case let (.initialLoading(lhsIndex, lhsCount), .initialLoading(rhsIndex, rhsCount)):
            lhsIndex == rhsIndex && lhsCount == rhsCount
        case let (.paginationLoading(lhsIndex, lhsCount), .paginationLoading(rhsIndex, rhsCount)):
            lhsIndex == rhsIndex && lhsCount == rhsCount
        case (.empty, .empty), (.error, .error):
            false
        default:
            false
        }
    }

    private enum StateSectionID: Hashable, Sendable {
        case content(SectionID)
        case initialLoading
        case paginationLoading
        case empty
        case error
    }

    private enum StateItem: Identifiable, Hashable, Sendable, ShopScrollViewProxyIdentifiable {
        case content(Item)
        case initialLoading(index: Int, count: Int)
        case paginationLoading(index: Int, count: Int)
        case empty
        case error

        var id: ID {
            switch self {
            case let .content(item):
                .content(item.id)
            case let .initialLoading(index, _):
                .initialLoading(index)
            case let .paginationLoading(index, _):
                .paginationLoading(index)
            case .empty:
                .empty
            case .error:
                .error
            }
        }

        var shopScrollViewProxyID: AnyHashable? {
            switch self {
            case let .content(item):
                AnyHashable(item.id)
            case .initialLoading, .paginationLoading, .empty, .error:
                nil
            }
        }

        static func == (lhs: StateItem, rhs: StateItem) -> Bool {
            // Keep diffable snapshot identity stable across content edits. Changed-content detection
            // is handled separately by `stateItemsHaveEqualContent`, so mixed updates (an existing
            // row changes while another row is inserted/removed) remain in-place reconfigures instead
            // of diffable treating the changed stable-id row as delete+insert churn.
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        enum ID: Hashable, Sendable {
            case content(Item.ID)
            case initialLoading(Int)
            case paginationLoading(Int)
            case empty
            case error
        }
    }
}

private extension ShopCollectionListRowReuseKind {
    static let collectionListInitialLoading = ShopCollectionListRowReuseKind("collection-list.initial-loading")
    static let collectionListPaginationLoading = ShopCollectionListRowReuseKind("collection-list.pagination-loading")
    static let collectionListEmpty = ShopCollectionListRowReuseKind("collection-list.empty")
    static let collectionListError = ShopCollectionListRowReuseKind("collection-list.error")
}

public extension ShopCollectionList where HeaderContent == EmptyView {
    init(
        state: ShopCollectionListContentState,
        sections: [ShopCollectionListSection<SectionID, Item>],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        isPaginating: Bool = false,
        initialLoadingPlaceholderCount: Int = 1,
        paginationLoadingPlaceholderCount: Int = 1,
        endReachedLeadDistance: CGFloat = 600,
        endReachedRearmToken: AnyHashable? = nil,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        onUserScroll: (() -> Void)? = nil,
        @ViewBuilder initialLoadingPlaceholder: @escaping (ShopCollectionListLoadingPlaceholderContext) -> InitialLoadingPlaceholderContent = { context in
            ShopCollectionListDefaultLoadingPlaceholder(context: context)
        },
        @ViewBuilder loadingPlaceholder: @escaping (ShopCollectionListLoadingPlaceholderContext) -> LoadingPlaceholderContent = { context in
            ShopCollectionListDefaultLoadingPlaceholder(context: context)
        },
        @ViewBuilder empty: @escaping () -> EmptyContent,
        @ViewBuilder error: @escaping () -> ErrorContent,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.init(
            state: state,
            sections: sections,
            layout: layout,
            contentInsets: contentInsets,
            contentInsetAdjustmentBehavior: contentInsetAdjustmentBehavior,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            isPaginating: isPaginating,
            initialLoadingPlaceholderCount: initialLoadingPlaceholderCount,
            paginationLoadingPlaceholderCount: paginationLoadingPlaceholderCount,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            initialLoadingPlaceholder: initialLoadingPlaceholder,
            loadingPlaceholder: loadingPlaceholder,
            empty: empty,
            error: error,
            header: { _ in EmptyView() },
            row: row
        )
    }
}

public extension ShopCollectionList where InitialLoadingPlaceholderContent == ShopCollectionListDefaultLoadingPlaceholder, LoadingPlaceholderContent == ShopCollectionListDefaultLoadingPlaceholder, EmptyContent == EmptyView, ErrorContent == EmptyView {
    init(
        sections: [ShopCollectionListSection<SectionID, Item>],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        isPaginating: Bool = false,
        paginationLoadingPlaceholderCount: Int = 1,
        endReachedLeadDistance: CGFloat = 600,
        endReachedRearmToken: AnyHashable? = nil,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        onUserScroll: (() -> Void)? = nil,
        @ViewBuilder header: @escaping (ShopCollectionListSection<SectionID, Item>) -> HeaderContent,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.init(
            state: .content,
            sections: sections,
            layout: layout,
            contentInsets: contentInsets,
            contentInsetAdjustmentBehavior: contentInsetAdjustmentBehavior,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            isPaginating: isPaginating,
            initialLoadingPlaceholderCount: 0,
            paginationLoadingPlaceholderCount: paginationLoadingPlaceholderCount,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            empty: { EmptyView() },
            error: { EmptyView() },
            header: header,
            row: row
        )
    }
}

public extension ShopCollectionList where HeaderContent == EmptyView, InitialLoadingPlaceholderContent == ShopCollectionListDefaultLoadingPlaceholder, LoadingPlaceholderContent == ShopCollectionListDefaultLoadingPlaceholder, EmptyContent == EmptyView, ErrorContent == EmptyView {
    init(
        sections: [ShopCollectionListSection<SectionID, Item>],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        isPaginating: Bool = false,
        paginationLoadingPlaceholderCount: Int = 1,
        endReachedLeadDistance: CGFloat = 600,
        endReachedRearmToken: AnyHashable? = nil,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        onUserScroll: (() -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.init(
            sections: sections,
            layout: layout,
            contentInsets: contentInsets,
            contentInsetAdjustmentBehavior: contentInsetAdjustmentBehavior,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            isPaginating: isPaginating,
            paginationLoadingPlaceholderCount: paginationLoadingPlaceholderCount,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            header: { _ in EmptyView() },
            row: row
        )
    }
}

public extension ShopCollectionList where SectionID == String, HeaderContent == EmptyView, InitialLoadingPlaceholderContent == ShopCollectionListDefaultLoadingPlaceholder, LoadingPlaceholderContent == ShopCollectionListDefaultLoadingPlaceholder, EmptyContent == EmptyView, ErrorContent == EmptyView {
    init(
        items: [Item],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        isPaginating: Bool = false,
        paginationLoadingPlaceholderCount: Int = 1,
        endReachedLeadDistance: CGFloat = 600,
        endReachedRearmToken: AnyHashable? = nil,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        onUserScroll: (() -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.init(
            sections: [
                ShopCollectionListSection(
                    id: "main",
                    items: items
                ),
            ],
            layout: layout,
            contentInsets: contentInsets,
            contentInsetAdjustmentBehavior: contentInsetAdjustmentBehavior,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            isPaginating: isPaginating,
            paginationLoadingPlaceholderCount: paginationLoadingPlaceholderCount,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            row: row
        )
    }
}
