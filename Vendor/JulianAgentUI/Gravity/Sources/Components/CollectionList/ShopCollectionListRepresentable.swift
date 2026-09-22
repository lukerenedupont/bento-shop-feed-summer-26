import SwiftUI
import UIKit

struct ShopCollectionListRepresentable<SectionID: Hashable & Sendable, Item: Identifiable & Hashable & Sendable, RowContent: View, HeaderContent: View>: UIViewRepresentable where Item.ID: Hashable & Sendable {
    typealias Section = ShopCollectionListSection<SectionID, Item>
    typealias UIViewType = ShopCollectionListView<SectionID, Item, RowContent, HeaderContent>

    private let sections: [Section]
    private let layout: ShopCollectionListLayout
    private let contentInsets: ShopCollectionListContentInsets
    private let contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior
    private let itemsHaveEqualContent: (Item, Item) -> Bool
    private let animatesMembershipChanges: Bool
    private let pinsToTopUntilUserScrolls: Bool
    private let suppressesSelfSizingAnimations: Bool
    private let alwaysSuppressesSelfSizingAnimations: Bool
    private let isContentState: Bool
    private let publishesContentSize: Bool
    private let hidesAccessibilityElements: Bool
    private let showsIndicators: Bool
    private let isRefreshing: Bool
    private let endReachedLeadDistance: CGFloat
    private let endReachedRearmToken: AnyHashable?
    private let scrollViewProxy: ShopScrollViewProxy?
    private let onRefresh: (() async -> Void)?
    private let onEndReached: (() -> Void)?
    private let onScrollOffsetChange: ((CGFloat) -> Void)?
    private let onUserScroll: (() -> Void)?
    private let onScrollPhaseChange: ((ShopCollectionListScrollPhase) -> Void)?
    private let onContentSizeChange: ((CGFloat) -> Void)?
    private let usesShopRefreshIndicator: Bool
    private let usesAutomaticTopScrollEdgeEffect: Bool
    private let rowReuseKind: (Item) -> ShopCollectionListRowReuseKind
    private let rowContent: (Item) -> RowContent
    private let headerContent: (Section) -> HeaderContent

    init(
        sections: [Section],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        itemsHaveEqualContent: @escaping (Item, Item) -> Bool = (==),
        animatesMembershipChanges: Bool = false,
        pinsToTopUntilUserScrolls: Bool = false,
        suppressesSelfSizingAnimations: Bool = false,
        alwaysSuppressesSelfSizingAnimations: Bool = false,
        isContentState: Bool = true,
        publishesContentSize: Bool = true,
        hidesAccessibilityElements: Bool = false,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        endReachedLeadDistance: CGFloat = 600,
        endReachedRearmToken: AnyHashable? = nil,
        scrollViewProxy: ShopScrollViewProxy? = nil,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        onUserScroll: (() -> Void)? = nil,
        onScrollPhaseChange: ((ShopCollectionListScrollPhase) -> Void)? = nil,
        onContentSizeChange: ((CGFloat) -> Void)? = nil,
        usesShopRefreshIndicator: Bool = false,
        usesAutomaticTopScrollEdgeEffect: Bool = false,
        rowReuseKind: @escaping (Item) -> ShopCollectionListRowReuseKind = { item in
            (item as? any ShopCollectionListReusableItem)?.collectionListReuseKind ?? .default
        },
        @ViewBuilder header: @escaping (Section) -> HeaderContent,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.sections = sections
        self.layout = layout
        self.contentInsets = contentInsets
        self.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
        self.itemsHaveEqualContent = itemsHaveEqualContent
        self.animatesMembershipChanges = animatesMembershipChanges
        self.pinsToTopUntilUserScrolls = pinsToTopUntilUserScrolls
        self.suppressesSelfSizingAnimations = suppressesSelfSizingAnimations
        self.alwaysSuppressesSelfSizingAnimations = alwaysSuppressesSelfSizingAnimations
        self.isContentState = isContentState
        self.publishesContentSize = publishesContentSize
        self.hidesAccessibilityElements = hidesAccessibilityElements
        self.showsIndicators = showsIndicators
        self.isRefreshing = isRefreshing
        self.endReachedLeadDistance = endReachedLeadDistance
        self.endReachedRearmToken = endReachedRearmToken
        self.scrollViewProxy = scrollViewProxy
        self.onRefresh = onRefresh
        self.onEndReached = onEndReached
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onUserScroll = onUserScroll
        self.onScrollPhaseChange = onScrollPhaseChange
        self.onContentSizeChange = onContentSizeChange
        self.usesShopRefreshIndicator = usesShopRefreshIndicator
        self.usesAutomaticTopScrollEdgeEffect = usesAutomaticTopScrollEdgeEffect
        self.rowReuseKind = rowReuseKind
        self.headerContent = header
        self.rowContent = row
    }

    func makeUIView(context: Context) -> UIViewType {
        let view = ShopCollectionListView(
            sections: sections,
            layout: layout,
            contentInsets: contentInsets,
            contentInsetAdjustmentBehavior: contentInsetAdjustmentBehavior,
            itemsHaveEqualContent: itemsHaveEqualContent,
            animatesMembershipChanges: animatesMembershipChanges,
            pinsToTopUntilUserScrolls: pinsToTopUntilUserScrolls,
            suppressesSelfSizingAnimations: suppressesSelfSizingAnimations,
            alwaysSuppressesSelfSizingAnimations: alwaysSuppressesSelfSizingAnimations,
            isContentState: isContentState,
            publishesContentSize: publishesContentSize,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            onScrollPhaseChange: onScrollPhaseChange,
            onContentSizeChange: onContentSizeChange,
            usesShopRefreshIndicator: usesShopRefreshIndicator,
            usesAutomaticTopScrollEdgeEffect: usesAutomaticTopScrollEdgeEffect,
            rowReuseKind: rowReuseKind,
            rowContent: rowContent,
            headerContent: headerContent
        )
        view.accessibilityElementsHidden = hidesAccessibilityElements
        view.attachScrollViewProxy(scrollViewProxy)
        return view
    }

    func updateUIView(
        _ view: UIViewType,
        context: Context
    ) {
        if view.accessibilityElementsHidden != hidesAccessibilityElements {
            view.accessibilityElementsHidden = hidesAccessibilityElements
        }
        view.attachScrollViewProxy(scrollViewProxy)
        view.apply(
            sections: sections,
            layout: layout,
            contentInsets: contentInsets,
            contentInsetAdjustmentBehavior: contentInsetAdjustmentBehavior,
            itemsHaveEqualContent: itemsHaveEqualContent,
            animatesMembershipChanges: animatesMembershipChanges,
            pinsToTopUntilUserScrolls: pinsToTopUntilUserScrolls,
            suppressesSelfSizingAnimations: suppressesSelfSizingAnimations,
            alwaysSuppressesSelfSizingAnimations: alwaysSuppressesSelfSizingAnimations,
            isContentState: isContentState,
            publishesContentSize: publishesContentSize,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            onScrollPhaseChange: onScrollPhaseChange,
            onContentSizeChange: onContentSizeChange,
            usesShopRefreshIndicator: usesShopRefreshIndicator,
            usesAutomaticTopScrollEdgeEffect: usesAutomaticTopScrollEdgeEffect,
            rowReuseKind: rowReuseKind,
            rowContent: rowContent,
            headerContent: headerContent
        )
    }
}

extension ShopCollectionListRepresentable where HeaderContent == EmptyView {
    init(
        sections: [ShopCollectionListSection<SectionID, Item>],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        endReachedLeadDistance: CGFloat = 600,
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
            endReachedLeadDistance: endReachedLeadDistance,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            header: { _ in EmptyView() },
            row: row
        )
    }
}

extension ShopCollectionListRepresentable where SectionID == String, HeaderContent == EmptyView {
    init(
        items: [Item],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = .zero,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .never,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        endReachedLeadDistance: CGFloat = 600,
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
            endReachedLeadDistance: endReachedLeadDistance,
            onRefresh: onRefresh,
            onEndReached: onEndReached,
            onScrollOffsetChange: onScrollOffsetChange,
            onUserScroll: onUserScroll,
            row: row
        )
    }
}
