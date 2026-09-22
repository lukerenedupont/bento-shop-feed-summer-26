import SwiftUI

public struct ShopCollectionListScreen<SectionID: Hashable & Sendable, Item: Identifiable & Hashable & Sendable, RowContent: View, HeaderContent: View>: View where Item.ID: Hashable & Sendable {
    public typealias Section = ShopCollectionListSection<SectionID, Item>

    private let title: String?
    private let titleDisplayMode: ToolbarTitleDisplayMode
    private let sections: [Section]
    private let layout: ShopCollectionListLayout
    private let contentInsets: ShopCollectionListContentInsets
    private let contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior
    private let showsIndicators: Bool
    private let isRefreshing: Bool
    private let endReachedLeadDistance: CGFloat
    private let onRefresh: (() async -> Void)?
    private let onEndReached: (() -> Void)?
    private let onScrollOffsetChange: ((CGFloat) -> Void)?
    private let rowContent: (Item) -> RowContent
    private let headerContent: (Section) -> HeaderContent

    public init(
        _ title: String? = nil,
        titleDisplayMode: ToolbarTitleDisplayMode = .large,
        sections: [Section],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = ShopCollectionListContentInsets(
            top: GravitySpacing.space24,
            bottom: GravitySpacing.space48
        ),
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .automatic,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        endReachedLeadDistance: CGFloat = 600,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder header: @escaping (Section) -> HeaderContent,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.title = title
        self.titleDisplayMode = titleDisplayMode
        self.sections = sections
        self.layout = layout
        self.contentInsets = contentInsets
        self.contentInsetAdjustmentBehavior = contentInsetAdjustmentBehavior
        self.showsIndicators = showsIndicators
        self.isRefreshing = isRefreshing
        self.endReachedLeadDistance = endReachedLeadDistance
        self.onRefresh = onRefresh
        self.onEndReached = onEndReached
        self.onScrollOffsetChange = onScrollOffsetChange
        self.headerContent = header
        self.rowContent = row
    }

    public var body: some View {
        ShopCollectionList(
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
            header: headerContent,
            row: rowContent
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GravityColor.bg.ignoresSafeArea())
        .ignoresSafeArea(.container, edges: ignoredContainerSafeAreaEdges)
        .modifier(ShopCollectionListScreenNavigationTitle(title: title, titleDisplayMode: titleDisplayMode))
    }

    var ignoredContainerSafeAreaEdges: Edge.Set {
        switch contentInsetAdjustmentBehavior {
        case .automatic:
            [.top, .bottom]
        case .never:
            []
        }
    }
}

public extension ShopCollectionListScreen where HeaderContent == EmptyView {
    init(
        _ title: String? = nil,
        titleDisplayMode: ToolbarTitleDisplayMode = .large,
        sections: [ShopCollectionListSection<SectionID, Item>],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = ShopCollectionListContentInsets(
            top: GravitySpacing.space24,
            bottom: GravitySpacing.space48
        ),
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .automatic,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        endReachedLeadDistance: CGFloat = 600,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.init(
            title,
            titleDisplayMode: titleDisplayMode,
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
            header: { _ in EmptyView() },
            row: row
        )
    }
}

public extension ShopCollectionListScreen where SectionID == String, HeaderContent == EmptyView {
    init(
        _ title: String? = nil,
        titleDisplayMode: ToolbarTitleDisplayMode = .large,
        items: [Item],
        layout: ShopCollectionListLayout = .vertical(),
        contentInsets: ShopCollectionListContentInsets = ShopCollectionListContentInsets(
            top: GravitySpacing.space24,
            bottom: GravitySpacing.space48
        ),
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior = .automatic,
        showsIndicators: Bool = false,
        isRefreshing: Bool = false,
        endReachedLeadDistance: CGFloat = 600,
        onRefresh: (() async -> Void)? = nil,
        onEndReached: (() -> Void)? = nil,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder row: @escaping (Item) -> RowContent
    ) {
        self.init(
            title,
            titleDisplayMode: titleDisplayMode,
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
            row: row
        )
    }
}

private struct ShopCollectionListScreenNavigationTitle: ViewModifier {
    let title: String?
    let titleDisplayMode: ToolbarTitleDisplayMode

    func body(content: Content) -> some View {
        if let title {
            content
                .navigationTitle(title)
                .toolbarTitleDisplayMode(titleDisplayMode)
        } else {
            content
        }
    }
}

#Preview("ShopCollectionListScreen") {
    NavigationStack {
        ShopCollectionListScreen(
            "Collection list",
            titleDisplayMode: .large,
            items: (0 ..< 20).map { ShopCollectionListScreenPreviewItem(id: "item-\($0)") }
        ) { item in
            ShopCard(shadow: .none) {
                ShopText("Row \(item.id)", style: .bodyTitleSmall)
            }
            .padding(.horizontal, GravitySpacing.screenMargin)
        }
    }
}

private struct ShopCollectionListScreenPreviewItem: Identifiable, Hashable, Sendable {
    let id: String
}
