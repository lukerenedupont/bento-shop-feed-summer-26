import os
import SwiftUI

/// Interactive harness for `ShopCollectionList` refresh + pagination behavior.
///
/// It deliberately mirrors how the Orders root ViewModel wires the list so it
/// exercises the same trigger paths: the end-reached handler is gated by `canLoadNextPage`
/// so it flips nil <-> non-nil across every load, exactly like Orders.
///
/// **What it surfaces:** every `onRefresh` and `onEndReached` callback is logged to the
/// `os.Logger` console *and* an on-screen timeline. No-scroll end-reached events are visible
/// because React Native VirtualizedList/FlashList can fire from layout/content-size updates,
/// not only from scroll events.
private struct ShopCollectionListPreviewHost: View {
    private let title: String
    private let description: String

    @State private var itemCount: Int
    @State private var sectionCount = 2
    @State private var showsHeaders = true
    @State private var showsIndicators = true
    @State private var usesSystemInsets = false
    @State private var usesShopRefreshIndicator = true
    @State private var hasNextPage = true
    @State private var isRefreshing = false
    @State private var isFetchingNextPage = false
    @State private var refreshCount = 0
    @State private var endReachedCount = 0
    @State private var viewportFillEndReachedCount = 0
    @State private var autoEndReachedCount = 0
    @State private var endReachedChainCount = 0
    @StateObject private var scrollProbe = ShopCollectionListPreviewScrollProbe()
    @State private var pageCursor = 0
    @State private var eventSequence = 0
    @State private var eventLog: [ShopCollectionListPreviewEvent] = []

    private let logger = Logger(
        subsystem: "com.shopify.shop.gravity.collectionlist",
        category: "Playground"
    )

    init(
        title: String = "ShopCollectionList playground",
        description: String = "Mirrors Orders' refresh + cursor pagination wiring. Watch the timeline to see whether onEndReached came from scroll movement or from layout/content-size evaluation.",
        initialItemCount: Int = 30
    ) {
        self.title = title
        self.description = description
        _itemCount = State(initialValue: initialItemCount)
    }

    var body: some View {
        VStack(spacing: .zero) {
            controls
                .padding(GravitySpacing.screenMargin)
                .background(GravityColor.bg)

            collectionList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GravityColor.bg)
    }

    // Ternaries are pulled into typed locals; inlining them inside this 8-generic-parameter
    // initializer overwhelms the Swift type-checker (mirrors how `ShopOrdersCollectionView`
    // precomputes its handler/inset values).
    private var collectionList: some View {
        // Wrap the method in an explicit closure and branch with if/else: a bare method
        // reference inside a ternary unified against `nil` crashes the Swift type-checker.
        let endReachedHandler: (() -> Void)?
        if canLoadNextPage {
            endReachedHandler = { loadNextPage() }
        } else {
            endReachedHandler = nil
        }
        let insetBehavior: ShopCollectionListContentInsetAdjustmentBehavior = usesSystemInsets ? .automatic : .never

        return ShopCollectionList(
            state: .content,
            sections: sections,
            layout: .vertical(
                rowSpacing: GravitySpacing.space8,
                estimatedRowHeight: 96,
                estimatedHeaderHeight: GravitySpacing.space44
            ),
            contentInsets: listContentInsets,
            contentInsetAdjustmentBehavior: insetBehavior,
            showsIndicators: showsIndicators,
            isRefreshing: isRefreshing,
            isPaginating: isFetchingNextPage,
            paginationLoadingPlaceholderCount: 1,
            endReachedLeadDistance: 320,
            onRefresh: refresh,
            onEndReached: endReachedHandler,
            onScrollOffsetChange: updateScrollOffset,
            empty: { EmptyView() },
            error: { EmptyView() },
            header: { section in
                ShopCollectionListPreviewHeader(title: "Section \(section.id)")
            },
            row: { item in
                ShopCollectionListPreviewRow(item: item)
            }
        )
        .refreshStyle(usesShopRefreshIndicator ? .shopIndicator : .system)
    }

    private var listContentInsets: ShopCollectionListContentInsets {
        ShopCollectionListContentInsets(
            top: GravitySpacing.space8,
            leading: GravitySpacing.screenMargin,
            bottom: GravitySpacing.space48,
            trailing: GravitySpacing.screenMargin
        )
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            HStack(alignment: .firstTextBaseline, spacing: GravitySpacing.space8) {
                ShopText(title, style: .bodyTitleSmall)
                    .lineLimit(1)
                Spacer(minLength: 0)
                ShopButton("Clear", variant: .text, size: .small, isFullWidth: false) {
                    resetMetrics()
                }
            }

            ShopText("end \(endReachedCount) · chain \(endReachedChainCount) · fill \(viewportFillEndReachedCount) · y \(Int(scrollProbe.offset.rounded()))", style: .caption, color: endReachedChainCount > 1 ? GravityColor.textCritical : GravityColor.textSecondary)
                .lineLimit(1)

            chainWarning

            HStack(spacing: GravitySpacing.space8) {
                ForEach([0, 5, 30, 100], id: \.self) { count in
                    ShopButton(
                        "\(count)",
                        variant: itemCount == count ? .primary : .secondary,
                        size: .small,
                        isFullWidth: false
                    ) {
                        resetData(to: count)
                    }
                }
            }

            eventTimeline
        }
        .padding(.horizontal, GravitySpacing.screenMargin)
        .padding(.top, GravitySpacing.space8)
        .padding(.bottom, GravitySpacing.space8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GravityColor.bg)
    }

    @ViewBuilder
    private var chainWarning: some View {
        if endReachedChainCount > 1 {
            HStack(spacing: GravitySpacing.space6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                ShopText("chain: \(endReachedChainCount) endReached fires at the bottom", style: .caption, color: GravityColor.textCritical)
                    .lineLimit(1)
            }
            .foregroundStyle(GravityColor.textCritical)
            .padding(.vertical, GravitySpacing.space4)
            .padding(.horizontal, GravitySpacing.space8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GravityColor.bgFillCriticalSecondary)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.radius8))
        }
    }

    @ViewBuilder
    private var eventTimeline: some View {
        let endReachedEvents = eventLog.filter(\.kind.isEndReached).prefix(3)
        if endReachedEvents.isEmpty == false {
            HStack(spacing: GravitySpacing.space6) {
                ShopText("ER log", style: .caption, color: GravityColor.textTertiary)
                ForEach(Array(endReachedEvents)) { event in
                    ShopText("#\(event.sequence) y=\(event.offset)", style: .caption, color: event.kind.color)
                        .lineLimit(1)
                        .padding(.vertical, GravitySpacing.space4)
                        .padding(.horizontal, GravitySpacing.space6)
                        .background(GravityColor.bgFillPlaceholder)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var canLoadNextPage: Bool {
        hasNextPage && isFetchingNextPage == false && isRefreshing == false
    }

    private var lastItemID: String? {
        sections.last?.items.last?.id
    }

    private var sections: [ShopCollectionListSection<Int, ShopCollectionListPreviewItem>] {
        if sectionCount > 1 {
            let firstCount = itemCount / 2
            let secondCount = itemCount - firstCount
            return [
                ShopCollectionListSection(
                    id: 1,
                    items: items(start: 0, count: firstCount),
                    showsHeader: showsHeaders
                ),
                ShopCollectionListSection(
                    id: 2,
                    items: items(start: firstCount, count: secondCount),
                    showsHeader: showsHeaders
                ),
            ]
        }

        return [
            ShopCollectionListSection(
                id: 1,
                items: items(start: 0, count: itemCount),
                showsHeader: showsHeaders
            ),
        ]
    }

    private func items(start: Int, count: Int) -> [ShopCollectionListPreviewItem] {
        guard count > 0 else {
            return []
        }

        return (start ..< start + count).map { index in
            ShopCollectionListPreviewItem(
                id: "item-\(index)",
                title: "Reusable row \(index + 1)",
                detail: detail(for: index)
            )
        }
    }

    private func detail(for index: Int) -> String {
        if index.isMultiple(of: 7) {
            return "A taller row with extra text to exercise self-sizing hosted SwiftUI content inside a reusable collection view cell."
        }

        return "Short row detail."
    }

    @MainActor
    private func refresh() async {
        logEvent(.refresh)
        // Mirror Orders: a refetch keeps the same first-page identities and leaves the cursor
        // untouched, so the handler flips nil -> non-nil as `canLoadNextPage` recovers.
        scrollProbe.didScrollSinceLastLoad = false
        isRefreshing = true
        refreshCount += 1
        try? await Task.sleep(nanoseconds: 600_000_000)
        isRefreshing = false
    }

    @MainActor
    private func loadNextPage() {
        guard isFetchingNextPage == false, hasNextPage else {
            return
        }

        if scrollProbe.movedAwaySinceLastEndReached {
            endReachedChainCount = 0
        }

        let firedWithoutScroll = scrollProbe.didScrollSinceLastLoad == false
        let eventKind: ShopCollectionListPreviewEvent.Kind
        if firedWithoutScroll, expectsViewportFillEndReached {
            eventKind = .endReachedViewportFill
            viewportFillEndReachedCount += 1
        } else if firedWithoutScroll {
            eventKind = .endReachedAuto
            autoEndReachedCount += 1
        } else {
            eventKind = .endReachedScroll
        }

        endReachedChainCount += 1
        scrollProbe.recordEndReached()
        logEvent(eventKind)
        endReachedCount += 1
        scrollProbe.didScrollSinceLastLoad = false
        isFetchingNextPage = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            itemCount += 10
            pageCursor += 1
            isFetchingNextPage = false
            logEvent(.pageLoaded)
        }
    }

    @MainActor
    private func updateScrollOffset(_ offset: CGFloat) {
        scrollProbe.update(offset: offset)
    }

    @MainActor
    private func resetData(to count: Int) {
        itemCount = count
        pageCursor = 0
        isFetchingNextPage = false
        isRefreshing = false
        scrollProbe.reset()
        resetMetrics()
    }

    @MainActor
    private func resetMetrics() {
        refreshCount = 0
        endReachedCount = 0
        viewportFillEndReachedCount = 0
        autoEndReachedCount = 0
        endReachedChainCount = 0
        scrollProbe.reset()
        eventSequence = 0
        eventLog.removeAll()
    }

    @MainActor
    private func logEvent(_ kind: ShopCollectionListPreviewEvent.Kind) {
        eventSequence += 1
        let offset = Int(scrollProbe.offset.rounded())
        eventLog.insert(
            ShopCollectionListPreviewEvent(sequence: eventSequence, kind: kind, offset: offset),
            at: 0
        )
        if eventLog.count > 6 {
            eventLog.removeLast(eventLog.count - 6)
        }
        logger.log(
            "[\(eventSequence, privacy: .public)] \(kind.logLabel, privacy: .public) chain=\(self.endReachedChainCount, privacy: .public) offset=\(offset, privacy: .public) items=\(self.itemCount, privacy: .public) cursor=\(self.pageCursor, privacy: .public)"
        )
    }

    private var expectsViewportFillEndReached: Bool {
        itemCount <= 5
    }
}

@MainActor
private final class ShopCollectionListPreviewScrollProbe: ObservableObject {
    private enum Metrics {
        static let scrollDelta: CGFloat = 0.5
        static let movedAwayDistance: CGFloat = 120
    }

    var offset: CGFloat = 0
    var didScrollSinceLastLoad = false
    var movedAwaySinceLastEndReached = false

    private var lastEndReachedOffset: CGFloat?

    func update(offset: CGFloat) {
        if offset > self.offset + Metrics.scrollDelta {
            didScrollSinceLastLoad = true
        }
        if let lastEndReachedOffset,
           offset < lastEndReachedOffset - Metrics.movedAwayDistance {
            movedAwaySinceLastEndReached = true
        }

        self.offset = (offset / 8).rounded() * 8
    }

    func recordEndReached() {
        lastEndReachedOffset = offset
        movedAwaySinceLastEndReached = false
    }

    func reset() {
        offset = 0
        didScrollSinceLastLoad = false
        movedAwaySinceLastEndReached = false
        lastEndReachedOffset = nil
    }
}

private struct ShopCollectionListPreviewEvent: Identifiable {
    enum Kind {
        case refresh
        case endReachedScroll
        case endReachedViewportFill
        case endReachedAuto
        case pageLoaded

        var displayLabel: String {
            switch self {
            case .refresh: "refresh"
            case .endReachedScroll: "endReached (scroll)"
            case .endReachedViewportFill: "endReached (viewport fill)"
            case .endReachedAuto: "endReached — NO SCROLL"
            case .pageLoaded: "page appended"
            }
        }

        var logLabel: String {
            displayLabel
        }

        var color: Color {
            switch self {
            case .refresh: GravityColor.textSecondary
            case .endReachedScroll: GravityColor.textSuccess
            case .endReachedViewportFill: GravityColor.textSecondary
            case .endReachedAuto: GravityColor.textSecondary
            case .pageLoaded: GravityColor.textTertiary
            }
        }

        var symbol: String {
            switch self {
            case .refresh: "arrow.clockwise"
            case .endReachedScroll: "arrow.down.circle"
            case .endReachedViewportFill: "arrow.down.to.line.circle"
            case .endReachedAuto: "exclamationmark.triangle.fill"
            case .pageLoaded: "plus.circle"
            }
        }

        var isEndReached: Bool {
            switch self {
            case .endReachedScroll, .endReachedViewportFill, .endReachedAuto:
                true
            case .refresh, .pageLoaded:
                false
            }
        }
    }

    let id = UUID()
    let sequence: Int
    let kind: Kind
    let offset: Int
}

private struct ShopCollectionListNavigationEdgePreview: View {
    var body: some View {
        NavigationStack {
            ShopCollectionList(
                sections: sections,
                layout: .vertical(
                    rowSpacing: GravitySpacing.space8,
                    estimatedRowHeight: 96,
                    estimatedHeaderHeight: GravitySpacing.space44
                ),
                contentInsets: ShopCollectionListContentInsets(
                    top: GravitySpacing.space8,
                    leading: GravitySpacing.screenMargin,
                    bottom: GravitySpacing.space48,
                    trailing: GravitySpacing.screenMargin
                ),
                contentInsetAdjustmentBehavior: .automatic,
                showsIndicators: true,
                header: { section in
                    ShopCollectionListPreviewHeader(title: "Section \(section.id)")
                },
                row: { item in
                    ShopCollectionListPreviewRow(item: item)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GravityColor.bg.ignoresSafeArea())
            .ignoresSafeArea(.container, edges: [.top, .bottom])
            .navigationTitle("Collection list")
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    private var sections: [ShopCollectionListSection<Int, ShopCollectionListPreviewItem>] {
        [
            ShopCollectionListSection(
                id: 1,
                items: items(start: 0, count: 20),
                showsHeader: true
            ),
            ShopCollectionListSection(
                id: 2,
                items: items(start: 20, count: 20),
                showsHeader: true
            ),
        ]
    }

    private func items(start: Int, count: Int) -> [ShopCollectionListPreviewItem] {
        (start ..< start + count).map { index in
            ShopCollectionListPreviewItem(
                id: "navigation-item-\(index)",
                title: "Navigation row \(index + 1)",
                detail: index.isMultiple(of: 5) ? "Taller row used to validate self-sizing while the large title collapses." : "Scroll to validate the iOS 26 soft scroll-edge effect."
            )
        }
    }
}

private struct ShopCollectionListPreviewItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
}

private struct ShopCollectionListPreviewHeader: View {
    let title: String

    var body: some View {
        ShopText(title, style: .subtitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, GravitySpacing.space8)
            .background(GravityColor.bg)
    }
}

private struct ShopCollectionListPreviewRow: View {
    let item: ShopCollectionListPreviewItem

    var body: some View {
        ShopCard(shadow: .none) {
            VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                ShopText(item.title, style: .bodyTitleSmall)
                ShopText(item.detail, style: .bodySmall, color: GravityColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ShopCollectionListStatePreview: View {
    @State private var state: ShopCollectionListContentState = .empty

    var body: some View {
        VStack(spacing: .zero) {
            HStack(spacing: GravitySpacing.space8) {
                stateButton(.content, "Content")
                stateButton(.empty, "Empty")
                stateButton(.error, "Error")
                stateButton(.loading, "Loading")
            }
            .padding(GravitySpacing.screenMargin)
            .background(GravityColor.bg)

            ShopCollectionList(
                state: state,
                sections: sections,
                layout: .vertical(
                    rowSpacing: GravitySpacing.space8,
                    estimatedRowHeight: 96,
                    estimatedHeaderHeight: GravitySpacing.space44
                ),
                contentInsets: ShopCollectionListContentInsets(
                    top: GravitySpacing.space8,
                    leading: GravitySpacing.screenMargin,
                    bottom: GravitySpacing.space48,
                    trailing: GravitySpacing.screenMargin
                ),
                showsIndicators: true,
                initialLoadingPlaceholderCount: 6,
                empty: {
                    ShopStateCard(
                        icon: .box,
                        title: "Nothing here yet",
                        message: "Shared ShopStateCard rendered in ShopCollectionList's empty slot.",
                        contentSpacing: GravitySpacing.space16
                    )
                },
                error: {
                    ShopStateCard(
                        icon: .alertTriangleFilled,
                        iconColor: GravityColor.textCritical,
                        iconSize: .large,
                        title: "Couldn't load",
                        message: "Shared ShopStateCard rendered in ShopCollectionList's error slot.",
                        messageStyle: .bodySmall,
                        messageLineLimit: 4,
                        actions: [
                            ShopStateCardAction(title: "Try again", variant: .secondary, size: .medium, action: {}),
                        ]
                    )
                },
                header: { section in
                    ShopCollectionListPreviewHeader(title: "Section \(section.id)")
                },
                row: { item in
                    ShopCollectionListPreviewRow(item: item)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GravityColor.bg)
        }
    }

    private func stateButton(_ option: ShopCollectionListContentState, _ title: String) -> some View {
        ShopButton(
            title,
            variant: state == option ? .primary : .secondary,
            size: .small,
            isFullWidth: false
        ) {
            state = option
        }
    }

    private var sections: [ShopCollectionListSection<Int, ShopCollectionListPreviewItem>] {
        [
            ShopCollectionListSection(
                id: 1,
                items: (0 ..< 8).map { index in
                    ShopCollectionListPreviewItem(
                        id: "state-\(index)",
                        title: "Reusable row \(index + 1)",
                        detail: "Content-state row."
                    )
                },
                showsHeader: true
            ),
        ]
    }
}

#Preview("ShopCollectionList playground") {
    ShopTheme {
        ShopCollectionListPreviewHost()
    }
}

#Preview("ShopCollectionList end reached — taller than viewport") {
    ShopTheme {
        ShopCollectionListPreviewHost(
            title: "ShopCollectionList — taller than viewport",
            description: "30 rows should not fire onEndReached until the trailing edge is within the 600pt lead distance. The trigger can come from scroll or from content/layout updates.",
            initialItemCount: 30
        )
    }
}

#Preview("ShopCollectionList end reached — shorter than viewport") {
    ShopTheme {
        ShopCollectionListPreviewHost(
            title: "ShopCollectionList — shorter than viewport",
            description: "5 rows cannot fill the viewport, so apply-time onEndReached is expected and logged as viewport-fill.",
            initialItemCount: 5
        )
    }
}

#Preview("ShopCollectionList states (empty/error via ShopStateCard)") {
    ShopTheme {
        ShopCollectionListStatePreview()
    }
}

#Preview("ShopCollectionList navigation edges") {
    ShopTheme {
        ShopCollectionListNavigationEdgePreview()
    }
}
