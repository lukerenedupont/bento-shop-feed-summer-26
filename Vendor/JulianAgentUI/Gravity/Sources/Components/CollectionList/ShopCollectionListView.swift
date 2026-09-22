import SwiftUI
import UIKit

private enum ShopCollectionListViewMetrics {
    static let scrollOffsetReportingThreshold: CGFloat = 1
    // Membership insert/remove animation timing for opt-in callers (e.g. the cart). Matches the
    // pre-migration SwiftUI transition: 320 ms on the timingCurve(0.33, 1, 0.68, 1) cubic.
    static let membershipChangeAnimationDuration: TimeInterval = 0.32
    static let membershipChangeAnimationTimingControlPoints: (Float, Float, Float, Float) = (0.33, 1.0, 0.68, 1.0)
}

private enum ShopCollectionListSnapshotItem<ItemID: Hashable & Sendable>: Hashable, Sendable {
    case content(id: ItemID, reuseKind: ShopCollectionListRowReuseKind)

    var reuseKind: ShopCollectionListRowReuseKind {
        switch self {
        case let .content(_, reuseKind):
            reuseKind
        }
    }
}

private enum UserRefreshIntent {
    case none
    case awaitingProjection
    case settledWithoutProjection
}

private struct ShopCollectionListRefreshOnlyIdentity<SectionID: Hashable, ItemID: Hashable & Sendable>: Equatable {
    let sectionIDs: [SectionID]
    let itemIDs: [ShopCollectionListSnapshotItem<ItemID>]
    let headerVisibility: [Bool]
    // Raw layout identity (insets-agnostic); horizontal insets are tracked separately via
    // `contentInsets` below. Distinct from the view's combined `layoutIdentity` (which folds in
    // horizontal insets to drive relayout).
    let baseLayoutIdentity: String
    let contentInsets: ShopCollectionListContentInsets
    let insetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior
    let showsIndicators: Bool
    let endReachedLeadDistance: CGFloat
    let endReachedRearmToken: AnyHashable?
    let hasRefreshHandler: Bool
    let hasEndReachedHandler: Bool
    let hasScrollOffsetHandler: Bool
    let hasUserScrollHandler: Bool
}

private struct ShopCollectionListEndReachedTriggerKey: Hashable {
    let rearmToken: AnyHashable
}

@MainActor
final class ShopCollectionListView<SectionID: Hashable & Sendable, Item: Identifiable & Hashable & Sendable, RowContent: View, HeaderContent: View>: UICollectionView, UICollectionViewDelegate, ShopScrollViewItemScrolling where Item.ID: Hashable & Sendable {
    typealias Section = ShopCollectionListSection<SectionID, Item>
    private typealias SnapshotItem = ShopCollectionListSnapshotItem<Item.ID>
    private typealias HostedRowContent = ShopCollectionListHostedContent<RowContent>
    private typealias HostedHeaderContent = ShopCollectionListHostedContent<HeaderContent>
    private typealias RowCell = ShopCollectionListHostingCell<HostedRowContent>
    private typealias HeaderView = ShopCollectionListHostingSupplementaryView<HostedHeaderContent>

    private var sections: [Section]
    private var layout: ShopCollectionListLayout
    private var layoutIdentity: String
    private var contentInsets: ShopCollectionListContentInsets
    private var insetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior
    private var itemsHaveEqualContent: (Item, Item) -> Bool
    private var animatesMembershipChanges: Bool
    // Opt-in for callers (e.g. the cart) that settle initial data over several applies — a
    // loading/placeholder snapshot, then real content, then async follow-up inserts (notices,
    // saved-for-later). Across those, UICollectionView can preserve a stale `contentOffset` or shift
    // it on a late insert, opening the list scrolled away from the top. When `true`, the resting top
    // is restored after every content apply until the user first scrolls; afterwards their scroll
    // position is never overridden.
    private var pinsToTopUntilUserScrolls: Bool
    // Opt-in for callers whose opening and scrolling self-sizing corrections must land without
    // UIKit animation.
    private var suppressesSelfSizingAnimations: Bool
    // Stronger opt-in for dynamic content that can resize while the collection view is idle.
    private var alwaysSuppressesSelfSizingAnimations: Bool
    // Whether the most recently applied snapshot is real content (not a loading/empty/error
    // placeholder). Drives content-only layout behaviour (resting-top hold, membership animation,
    // first-content latch) — distinct from `publishesContentSize`, which gates height reporting.
    private var isContentState: Bool
    // Whether the current state's laid-out height should be published via `onContentSizeChange`.
    // True for settled states (content/empty/error), false only for the transient loading
    // placeholder: publishing the placeholder height then snapping it on the loading→content
    // correction is the cart's first-open downward lurch. Empty/error are terminal states with
    // real measurable heights, so a height-sizing caller (the under-cart reveal) must size to them
    // rather than fall back to an oversized default.
    private var publishesContentSize: Bool
    private var showsIndicators: Bool
    private var isRefreshing: Bool
    private var endReachedLeadDistance: CGFloat
    private var endReachedRearmToken: AnyHashable?
    private var onRefresh: (() async -> Void)?
    private var onEndReached: (() -> Void)?
    private var onScrollOffsetChange: ((CGFloat) -> Void)?
    private var onUserScroll: (() -> Void)?
    private var onScrollPhaseChange: ((ShopCollectionListScrollPhase) -> Void)?
    private var lastReportedScrollPhase: ShopCollectionListScrollPhase = .idle
    private var onContentSizeChange: ((CGFloat) -> Void)?
    private var usesShopRefreshIndicator: Bool
    private var usesAutomaticTopScrollEdgeEffect: Bool
    private var rowReuseKind: (Item) -> ShopCollectionListRowReuseKind
    private var rowContent: (Item) -> RowContent
    private var headerContent: (Section) -> HeaderContent
    private var endReachedController = ShopCollectionEndReachedController()
    private var suppressesEndReachedEvaluation = false
    private var lastReportedScrollOffset: CGFloat?
    private var lastReportedContentSizeHeight: CGFloat?
    private weak var scrollViewProxy: ShopScrollViewProxy?
    private weak var registeredContentScrollViewController: UIViewController?
    private var appliedContentInsetAdjustmentBehavior: UIScrollView.ContentInsetAdjustmentBehavior?
    private var appliedContentInset: UIEdgeInsets?
    private var appliedVerticalScrollIndicatorInsets: UIEdgeInsets?
    private var registeredRowReuseKinds: Set<ShopCollectionListRowReuseKind> = []
    private var itemsBySnapshotItem: [SnapshotItem: Item]
    private var lastItemIDs: [SnapshotItem]
    private var lastHeaderVisibility: [Bool]
    private var totalItemCount: Int
    // Snapshot of the items applied on the previous `apply`, keyed by snapshot identity, so visible
    // reconfiguration can skip rows whose content did not change.
    private var lastItemsBySnapshotItem: [SnapshotItem: Item]
    // Records whether the most recent apply animated a membership change. Internal so unit tests can
    // assert the animated-apply path is taken on an ID-set change and skipped for content-only edits,
    // without depending on UIKit's private animation timing.
    private(set) var didAnimateLastApply = false
    // Records whether the most recent apply pinned the list to its resting top. Internal so unit tests
    // can assert the pin fires on content applies before the first user scroll (with the opt-in on)
    // and stops afterwards — without depending on a window/layout pass to observe `contentOffset`.
    private(set) var didPinToTopOnLastApply = false
    // Records whether the most recent public `apply` reached the diffable snapshot/inset path.
    // Internal so refresh lifecycle tests can prove refresh-only updates stay control-only and do
    // not touch collection-view snapshot/layout state.
    private(set) var didApplyCurrentConfigurationOnLastApply = false
    // Records whether the most recent public `apply` rewrote the scroll view's configured insets.
    // When UIKit is animating a `UIRefreshControl`, unchanged app-level insets must not be re-applied
    // over UIKit's temporary refresh inset.
    private(set) var didUpdateInsetsOnLastApply = false
    private(set) var didSuppressAnimationsOnLastLayout = false
    private var isScrollInFlight = false
    // The cart renders loading/empty/error placeholder snapshots before real data, and each is a
    // membership change. Animating the transition INTO `.content` from any of those (or from the
    // empty initial snapshot) is the first-open "jump". Only animate membership changes that happen
    // once real content has already been shown — gate on this having flipped true, set only after a
    // content apply.
    private var hasShownContentOnce = false
    // Flips true the first time the user drags the scroll view. Until then, an opt-in caller's list is
    // held at its resting top across data-settling applies; afterwards the user's scroll position is
    // never overridden.
    private var hasUserScrolled = false
    private var userRefreshIntent = UserRefreshIntent.none
    private var hasCompletedInitialSelfSizingAnimationSuppression = false
    private var initialSelfSizingAnimationSuppressionReleaseScheduled = false

    private lazy var refreshControlView: UIRefreshControl = {
        let control: UIRefreshControl = usesShopRefreshIndicator ? ShopRefreshControl() : UIRefreshControl()
        control.addAction(
            UIAction { [weak self] _ in
                self?.handleRefreshIntent()
            },
            for: .valueChanged
        )
        return control
    }()

    private lazy var diffableDataSource: UICollectionViewDiffableDataSource<Section, SnapshotItem> = {
        let dataSource = UICollectionViewDiffableDataSource<Section, SnapshotItem>(collectionView: self) { [weak self] collectionView, indexPath, snapshotItem in
            guard let self else {
                return nil
            }

            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: RowCell.reuseIdentifier(for: snapshotItem.reuseKind),
                for: indexPath
            )

            guard let hostingCell = cell as? RowCell else {
                return cell
            }

            guard let item = self.itemsBySnapshotItem[snapshotItem] else {
                return hostingCell
            }

            self.configure(
                hostingCell,
                with: item
            )
            return hostingCell
        }

        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self,
                  kind == UICollectionView.elementKindSectionHeader,
                  let section = self.section(at: indexPath.section) else {
                return nil
            }

            let supplementaryView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: HeaderView.reuseIdentifier,
                for: indexPath
            )

            guard let hostingView = supplementaryView as? HeaderView else {
                return supplementaryView
            }

            self.configure(hostingView, with: section)
            return hostingView
        }

        return dataSource
    }()

    init(
        sections: [Section],
        layout: ShopCollectionListLayout,
        contentInsets: ShopCollectionListContentInsets,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior,
        itemsHaveEqualContent: @escaping (Item, Item) -> Bool = (==),
        animatesMembershipChanges: Bool = false,
        pinsToTopUntilUserScrolls: Bool = false,
        suppressesSelfSizingAnimations: Bool = false,
        alwaysSuppressesSelfSizingAnimations: Bool = false,
        isContentState: Bool = true,
        publishesContentSize: Bool = true,
        showsIndicators: Bool,
        isRefreshing: Bool,
        endReachedLeadDistance: CGFloat,
        endReachedRearmToken: AnyHashable? = nil,
        onRefresh: (() async -> Void)?,
        onEndReached: (() -> Void)?,
        onScrollOffsetChange: ((CGFloat) -> Void)?,
        onUserScroll: (() -> Void)? = nil,
        onScrollPhaseChange: ((ShopCollectionListScrollPhase) -> Void)? = nil,
        onContentSizeChange: ((CGFloat) -> Void)? = nil,
        usesShopRefreshIndicator: Bool = false,
        usesAutomaticTopScrollEdgeEffect: Bool = false,
        rowReuseKind: @escaping (Item) -> ShopCollectionListRowReuseKind = { item in
            (item as? any ShopCollectionListReusableItem)?.collectionListReuseKind ?? .default
        },
        rowContent: @escaping (Item) -> RowContent,
        headerContent: @escaping (Section) -> HeaderContent
    ) {
        let headerVisibility = sections.map(\.showsHeader)
        let snapshotItems = Self.snapshotItems(in: sections, rowReuseKind: rowReuseKind)
        let itemsBySnapshotItem = Self.itemsBySnapshotItem(in: sections, rowReuseKind: rowReuseKind)
        let collectionViewLayout = Self.makeCollectionViewLayout(
            layout: layout,
            contentInsets: contentInsets,
            headerVisibility: headerVisibility
        )

        self.sections = sections
        self.layout = layout
        self.layoutIdentity = Self.layoutIdentity(for: layout, contentInsets: contentInsets)
        self.contentInsets = contentInsets
        self.insetAdjustmentBehavior = contentInsetAdjustmentBehavior
        self.itemsHaveEqualContent = itemsHaveEqualContent
        self.animatesMembershipChanges = animatesMembershipChanges
        self.pinsToTopUntilUserScrolls = pinsToTopUntilUserScrolls
        self.suppressesSelfSizingAnimations = suppressesSelfSizingAnimations
        self.alwaysSuppressesSelfSizingAnimations = alwaysSuppressesSelfSizingAnimations
        self.isContentState = isContentState
        self.publishesContentSize = publishesContentSize
        self.showsIndicators = showsIndicators
        self.isRefreshing = isRefreshing
        self.endReachedLeadDistance = endReachedLeadDistance
        self.endReachedRearmToken = endReachedRearmToken
        self.onRefresh = onRefresh
        self.onEndReached = onEndReached
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onUserScroll = onUserScroll
        self.onScrollPhaseChange = onScrollPhaseChange
        self.onContentSizeChange = onContentSizeChange
        self.usesShopRefreshIndicator = usesShopRefreshIndicator
        self.usesAutomaticTopScrollEdgeEffect = usesAutomaticTopScrollEdgeEffect
        self.rowReuseKind = rowReuseKind
        self.rowContent = rowContent
        self.headerContent = headerContent
        self.itemsBySnapshotItem = itemsBySnapshotItem
        self.lastItemIDs = snapshotItems
        self.lastHeaderVisibility = headerVisibility
        self.totalItemCount = Self.totalItemCount(in: sections)
        self.lastItemsBySnapshotItem = itemsBySnapshotItem
        super.init(
            frame: .zero,
            collectionViewLayout: collectionViewLayout
        )

        setUpCollectionView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        MainActor.assumeIsolated {
            scrollViewProxy?.detach(self)
            registeredContentScrollViewController = ShopScrollViewNavigationBridge.unregister(from: registeredContentScrollViewController)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateRegisteredContentScrollView()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        updateRegisteredContentScrollView()
    }

    override func layoutSubviews() {
        let isOpeningSelfSizingPass = hasCompletedInitialSelfSizingAnimationSuppression == false
        let suppressesAnimations = isContentState
            && (alwaysSuppressesSelfSizingAnimations || (
                suppressesSelfSizingAnimations && (isOpeningSelfSizingPass || isScrollingContent)
            ))
        didSuppressAnimationsOnLastLayout = suppressesAnimations

        if suppressesAnimations {
            performWithoutImplicitAnimations {
                self.layoutCollectionViewSubviews()
            }
            if suppressesSelfSizingAnimations && isOpeningSelfSizingPass {
                scheduleInitialSelfSizingAnimationSuppressionRelease()
            }
        } else {
            layoutCollectionViewSubviews()
        }

        publishContentSize()
    }

    private var isScrollingContent: Bool {
        isScrollInFlight || isTracking || isDragging || isDecelerating
    }

    private func layoutCollectionViewSubviews() {
        super.layoutSubviews()
    }

    private func scheduleInitialSelfSizingAnimationSuppressionRelease() {
        guard initialSelfSizingAnimationSuppressionReleaseScheduled == false else { return }
        initialSelfSizingAnimationSuppressionReleaseScheduled = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.initialSelfSizingAnimationSuppressionReleaseScheduled = false
            self.hasCompletedInitialSelfSizingAnimationSuppression = true
        }
    }

    func apply(
        sections: [Section],
        layout: ShopCollectionListLayout,
        contentInsets: ShopCollectionListContentInsets,
        contentInsetAdjustmentBehavior: ShopCollectionListContentInsetAdjustmentBehavior,
        itemsHaveEqualContent: @escaping (Item, Item) -> Bool = (==),
        animatesMembershipChanges: Bool = false,
        pinsToTopUntilUserScrolls: Bool = false,
        suppressesSelfSizingAnimations: Bool = false,
        alwaysSuppressesSelfSizingAnimations: Bool = false,
        isContentState: Bool = true,
        publishesContentSize: Bool = true,
        showsIndicators: Bool,
        isRefreshing: Bool,
        endReachedLeadDistance: CGFloat,
        endReachedRearmToken: AnyHashable? = nil,
        onRefresh: (() async -> Void)?,
        onEndReached: (() -> Void)?,
        onScrollOffsetChange: ((CGFloat) -> Void)?,
        onUserScroll: (() -> Void)? = nil,
        onScrollPhaseChange: ((ShopCollectionListScrollPhase) -> Void)? = nil,
        onContentSizeChange: ((CGFloat) -> Void)? = nil,
        usesShopRefreshIndicator: Bool = false,
        usesAutomaticTopScrollEdgeEffect: Bool = false,
        rowReuseKind: @escaping (Item) -> ShopCollectionListRowReuseKind = { item in
            (item as? any ShopCollectionListReusableItem)?.collectionListReuseKind ?? .default
        },
        rowContent: @escaping (Item) -> RowContent,
        headerContent: @escaping (Section) -> HeaderContent
    ) {
        let previousRefreshOnlyIdentity = refreshOnlyIdentity
        let previousHeaderVisibility = lastHeaderVisibility
        let wasRefreshing = self.isRefreshing
        let automaticTopScrollEdgeEffectChanged =
            self.usesAutomaticTopScrollEdgeEffect != usesAutomaticTopScrollEdgeEffect
        didApplyCurrentConfigurationOnLastApply = false
        didUpdateInsetsOnLastApply = false
        // Captured before reassigning state so visible reconfiguration can compare each visible
        // cell's new item against the one it last rendered.
        let previousItemsBySnapshotItem = lastItemsBySnapshotItem
        let nextSnapshotItems = Self.snapshotItems(in: sections, rowReuseKind: rowReuseKind)
        let nextItemsBySnapshotItem = Self.itemsBySnapshotItem(in: sections, rowReuseKind: rowReuseKind)

        self.sections = sections
        self.layout = layout
        self.contentInsets = contentInsets
        self.insetAdjustmentBehavior = contentInsetAdjustmentBehavior
        self.itemsHaveEqualContent = itemsHaveEqualContent
        self.animatesMembershipChanges = animatesMembershipChanges
        self.pinsToTopUntilUserScrolls = pinsToTopUntilUserScrolls
        if self.suppressesSelfSizingAnimations == false,
           suppressesSelfSizingAnimations {
            hasCompletedInitialSelfSizingAnimationSuppression = false
        }
        self.suppressesSelfSizingAnimations = suppressesSelfSizingAnimations
        self.alwaysSuppressesSelfSizingAnimations = alwaysSuppressesSelfSizingAnimations
        self.isContentState = isContentState
        self.publishesContentSize = publishesContentSize
        self.showsIndicators = showsIndicators
        self.isRefreshing = isRefreshing
        self.endReachedLeadDistance = endReachedLeadDistance
        self.endReachedRearmToken = endReachedRearmToken
        self.onRefresh = onRefresh
        self.onEndReached = onEndReached
        self.onScrollOffsetChange = onScrollOffsetChange
        self.onUserScroll = onUserScroll
        self.onScrollPhaseChange = onScrollPhaseChange
        self.onContentSizeChange = onContentSizeChange
        self.usesShopRefreshIndicator = usesShopRefreshIndicator
        self.usesAutomaticTopScrollEdgeEffect = usesAutomaticTopScrollEdgeEffect
        self.rowReuseKind = rowReuseKind
        self.rowContent = rowContent
        self.headerContent = headerContent
        self.itemsBySnapshotItem = nextItemsBySnapshotItem
        self.lastItemIDs = nextSnapshotItems
        self.lastHeaderVisibility = sections.map(\.showsHeader)
        self.totalItemCount = Self.totalItemCount(in: sections)
        self.lastItemsBySnapshotItem = nextItemsBySnapshotItem

        if automaticTopScrollEdgeEffectChanged {
            updateScrollEdgeEffects()
        }

        // End-reached re-arming is owned by `endReachedController`: geometry decides whether the
        // end is eligible, and tokenless callers use content-length growth as re-arm progress.

        // While refresh is active, an identity-stable update must not re-apply the snapshot or touch
        // the scroll offset — the native UIRefreshControl owns the pull/hold/collapse. Take the
        // control-only path whenever the *rendered* content and layout are unchanged, even if
        // refresh-incidental bits changed. The store typically gates `onEndReached` off when refresh
        // begins, and may continue publishing content updates while refreshing; applying an identical
        // snapshot during either case reconciles active overscroll back to the refresh resting offset.
        // Visible rows and headers are reconfigured in place so stable-ID content changes still render.
        // Handler closures were already reassigned above.
        let renderIdentityUnchanged = previousRefreshOnlyIdentity.sectionIDs == refreshOnlyIdentity.sectionIDs
            && previousRefreshOnlyIdentity.itemIDs == refreshOnlyIdentity.itemIDs
            && previousRefreshOnlyIdentity.headerVisibility == refreshOnlyIdentity.headerVisibility
            && previousRefreshOnlyIdentity.baseLayoutIdentity == refreshOnlyIdentity.baseLayoutIdentity
            && previousRefreshOnlyIdentity.contentInsets == refreshOnlyIdentity.contentInsets
            && previousRefreshOnlyIdentity.insetAdjustmentBehavior == refreshOnlyIdentity.insetAdjustmentBehavior
            && previousRefreshOnlyIdentity.showsIndicators == refreshOnlyIdentity.showsIndicators

        // A completed refresh replaces the pagination session even when the refreshed first page
        // has the same cursor and rendered identity. Re-arm directly without applying a snapshot or
        // touching insets so the next threshold crossing can paginate while UIKit owns the collapse.
        let didFinishRefresh = wasRefreshing && isRefreshing == false
        if didFinishRefresh {
            endReachedController.rearm()
        }

        if (wasRefreshing || isRefreshing),
           renderIdentityUnchanged {
            syncRefreshControl()
            reconfigureChangedVisibleContent(previousItemsBySnapshotItem: previousItemsBySnapshotItem)
            if didFinishRefresh {
                evaluateEndReachedInCurrentScrollPosition()
            }
            updateRegisteredContentScrollView()
            return
        }

        // A membership change adds or removes a row/section (the item-ID set changed). Opt-in callers
        // animate those inserts/removals via the diffable apply; content-only mutations (stable IDs)
        // stay on the non-animated reconfigure path.
        let isMembershipChange = previousRefreshOnlyIdentity.itemIDs != lastItemIDs
        // While an opt-in caller hasn't been scrolled yet, hold the list at its resting top across
        // every content apply: a freshly-opened list settles its initial data over several applies
        // (loading→content, then async notices / saved-for-later / follow-up loads inserting more
        // rows), and each insert would otherwise leave the list scrolled away from the top.
        let holdsRestingTop = pinsToTopUntilUserScrolls && isContentState && hasUserScrolled == false
        // Never animate the transition into `.content` from a non-content state, and never animate
        // the pre-scroll settling inserts: an animated batch insert while sitting at the resting top
        // makes UICollectionView yank `contentOffset` downward (the first-open jump). Those applies
        // land instantly and get pinned back to the resting top below. Once the user has scrolled,
        // content→content membership changes animate as the opt-in intends.
        let animatesThisApply = animatesMembershipChanges
            && isMembershipChange
            && isContentState
            && hasShownContentOnce
            && holdsRestingTop == false
        didAnimateLastApply = animatesThisApply
        updateLayoutIfNeeded(previousHeaderVisibility: previousHeaderVisibility, pinsToTop: holdsRestingTop)
        applyCurrentConfiguration(
            animatingDifferences: animatesThisApply,
            reconfiguringVisibleContent: true,
            previousItemsBySnapshotItem: previousItemsBySnapshotItem,
            pinsToTop: holdsRestingTop
        )
        if isContentState {
            hasShownContentOnce = true
        }
        updateRegisteredContentScrollView()
    }

    func attachScrollViewProxy(_ proxy: ShopScrollViewProxy?) {
        guard scrollViewProxy !== proxy else {
            return
        }

        scrollViewProxy?.detach(self)
        scrollViewProxy = proxy
        proxy?.attach(self)
    }

    func shopScrollToItem(
        id: AnyHashable,
        position: UICollectionView.ScrollPosition,
        animated: Bool
    ) -> Bool {
        guard let indexPath = indexPath(forItemID: id) else {
            return false
        }

        scrollToItem(at: indexPath, at: position, animated: animated)
        return true
    }

    private func indexPath(forItemID id: AnyHashable) -> IndexPath? {
        for (sectionIndex, section) in sections.enumerated() {
            if let itemIndex = section.items.firstIndex(where: { item in
                AnyHashable(item.id) == id || (item as? any ShopScrollViewProxyIdentifiable)?.shopScrollViewProxyID == id
            }) {
                return IndexPath(item: itemIndex, section: sectionIndex)
            }
        }

        return nil
    }

    private var refreshOnlyIdentity: ShopCollectionListRefreshOnlyIdentity<SectionID, Item.ID> {
        ShopCollectionListRefreshOnlyIdentity(
            sectionIDs: sections.map(\.id),
            itemIDs: lastItemIDs,
            headerVisibility: lastHeaderVisibility,
            baseLayoutIdentity: layout.identity,
            contentInsets: contentInsets,
            insetAdjustmentBehavior: insetAdjustmentBehavior,
            showsIndicators: showsIndicators,
            endReachedLeadDistance: endReachedLeadDistance,
            endReachedRearmToken: endReachedRearmToken,
            hasRefreshHandler: onRefresh != nil,
            hasEndReachedHandler: onEndReached != nil,
            hasScrollOffsetHandler: onScrollOffsetChange != nil,
            hasUserScrollHandler: onUserScroll != nil
        )
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let scrollOffset = scrollView.contentOffset.y
        if shouldReportScrollOffset(scrollOffset) {
            onScrollOffsetChange?(scrollOffset)
        }
        evaluateEndReached(in: scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        hasUserScrolled = true
        isScrollInFlight = true
        onUserScroll?()
        reportScrollPhaseIfChanged(.interacting)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == false {
            isScrollInFlight = false
        }
        reportScrollPhaseIfChanged(decelerate ? .decelerating : .idle)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isScrollInFlight = false
        reportScrollPhaseIfChanged(.idle)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isScrollInFlight = false
        reportScrollPhaseIfChanged(.idle)
    }

    private func reportScrollPhaseIfChanged(_ phase: ShopCollectionListScrollPhase) {
        guard let onScrollPhaseChange else { return }
        guard phase != lastReportedScrollPhase else { return }
        lastReportedScrollPhase = phase
        onScrollPhaseChange(phase)
    }

    private func publishContentSize() {
        guard let onContentSizeChange else {
            return
        }

        // Publish heights for settled states (content/empty/error) but never the transient loading
        // placeholder: seeding a height-sizing container (the under-cart reveal) with the loading
        // height, then snapping it on the loading→content correction, is the cart's first-open
        // downward lurch. Empty/error are terminal states with real measurable heights, so the
        // reveal sizes to them instead of falling back to an oversized default.
        guard publishesContentSize else {
            return
        }

        // Report the total laid-out content height (rows + caller-configured top/bottom insets) so
        // callers that size a surrounding container to the list's intrinsic height (e.g. the
        // under-cart reveal) can react. Do not use the live scroll-view `contentInset`: UIKit
        // temporarily changes it while a refresh control is active, and publishing that transient
        // inset as content height moves height-driven containers during refresh. Throttled to
        // whole-point changes to avoid redundant callbacks.
        let height = contentSize.height + contentInsets.top + contentInsets.bottom
        guard height > 0 else {
            return
        }

        if let lastReportedContentSizeHeight, abs(lastReportedContentSizeHeight - height) < 1 {
            return
        }

        lastReportedContentSizeHeight = height
        onContentSizeChange(height)
    }

    private func handleRefreshIntent() {
        // Fire-and-forget, exactly like the Home Feed collection view: kick off the caller's
        // refresh work and never consult its completion. The visible refresh lifecycle (begin/end)
        // is driven solely by the projected `isRefreshing` prop via `syncRefreshControl`.
        guard let onRefresh else {
            return
        }
        userRefreshIntent = .awaitingProjection
        Task { @MainActor in
            await onRefresh()
            if self.userRefreshIntent == .awaitingProjection {
                self.userRefreshIntent = .settledWithoutProjection
            }
        }
    }

    private func updateRegisteredContentScrollView() {
        guard insetAdjustmentBehavior.participatesInSystemNavigationChrome else {
            registeredContentScrollViewController = ShopScrollViewNavigationBridge.unregister(
                from: registeredContentScrollViewController
            )
            return
        }

        let previousViewController = registeredContentScrollViewController
        registeredContentScrollViewController = ShopScrollViewNavigationBridge.register(
            scrollView: self,
            replacing: registeredContentScrollViewController
        )

        guard let registeredContentScrollViewController,
              previousViewController !== registeredContentScrollViewController,
              Self.rowReuseKinds(in: sections, rowReuseKind: rowReuseKind).contains(where: { reuseKind in
                  reuseKind.hostingMode == .persistentHostingController
              }) else {
            return
        }

        reconfigureChangedVisibleContent(previousItemsBySnapshotItem: [:])
    }

    private func setUpCollectionView() {
        backgroundColor = .clear
        alwaysBounceVertical = true
        // A vertical list must never scroll horizontally; horizontal margins live in the
        // compositional layout's section insets, not the scroll view's contentInset.
        alwaysBounceHorizontal = false
        contentInsetAdjustmentBehavior = insetAdjustmentBehavior.uiKitValue
        updateScrollEdgeEffects()
        showsVerticalScrollIndicator = showsIndicators
        showsHorizontalScrollIndicator = false
        delaysContentTouches = false
        delegate = self
        registerRowReuseKinds(in: sections)
        register(
            HeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: HeaderView.reuseIdentifier
        )

        _ = diffableDataSource
        applyCurrentConfiguration(
            animatingDifferences: false,
            reconfiguringVisibleContent: false,
            previousItemsBySnapshotItem: [:]
        )
    }

    private func applyCurrentConfiguration(
        animatingDifferences: Bool,
        reconfiguringVisibleContent: Bool,
        previousItemsBySnapshotItem: [SnapshotItem: Item],
        pinsToTop: Bool = false
    ) {
        didApplyCurrentConfigurationOnLastApply = true
        didPinToTopOnLastApply = pinsToTop
        didUpdateInsetsOnLastApply = updateInsets()
        showsVerticalScrollIndicator = showsIndicators
        if pinsToTop {
            pinToRestingTop(layoutFirst: false, suppressingEndReachedEvaluation: true)
        }

        registerRowReuseKinds(in: sections)

        var snapshot = NSDiffableDataSourceSnapshot<Section, SnapshotItem>()
        snapshot.appendSections(sections)
        for section in sections {
            snapshot.appendItems(
                section.items.map(snapshotItem(for:)),
                toSection: section
            )
        }

        let completion: () -> Void = { [weak self] in
            guard let self else {
                return
            }

            if reconfiguringVisibleContent {
                // Touch only visible cells whose item changed vs. the previously-applied item, and
                // skip the global layout invalidation. Each reconfigured cell re-measures itself via
                // `invalidateHostedContentSize()`.
                reconfigureChangedVisibleContent(previousItemsBySnapshotItem: previousItemsBySnapshotItem)
            }
            // For callers that size a container to the list (the under-cart reveal), force a layout
            // pass so cells self-size and then publish the settled content height — so the first
            // published height is the true self-sized value, not the `estimatedRowHeight × N` estimate
            // an interim `layoutSubviews` would otherwise report. Gated on `onContentSizeChange` so
            // every other consumer keeps its existing post-apply behavior unchanged.
            if onContentSizeChange != nil {
                layoutIfNeeded()
                publishContentSize()
            }
            // Restore the resting top for opt-in callers on every content apply until the user first
            // scrolls (see `apply`). Each settling snapshot replaces a prior one whose `contentOffset`
            // UICollectionView would otherwise preserve — or, for a late insert, shifts downward —
            // leaving the list opened scrolled away from the top. Lay out first so the offset isn't
            // clobbered by post-apply layout, then set the resting top non-animated. Once the user has
            // scrolled, `pinsToTop` is false, so their scroll position is never overridden.
            if pinsToTop {
                pinToRestingTop()
            }
            evaluateEndReachedInCurrentScrollPosition()
        }

        if animatingDifferences {
            // Retime the animated insert/delete onto the pre-migration cubic curve (320 ms,
            // timingCurve(0.33, 1, 0.68, 1)). `apply(animatingDifferences: true)` animates via the
            // collection view's batch-update Core Animation transaction, which honours an enclosing
            // explicit CATransaction's duration and timing function — so this block sets both around
            // the apply. The fade is the standard collection-view membership animation; the curve
            // and duration match the dropped SwiftUI opacity transition.
            let controlPoints = ShopCollectionListViewMetrics.membershipChangeAnimationTimingControlPoints
            CATransaction.begin()
            CATransaction.setAnimationDuration(ShopCollectionListViewMetrics.membershipChangeAnimationDuration)
            CATransaction.setAnimationTimingFunction(
                CAMediaTimingFunction(controlPoints: controlPoints.0, controlPoints.1, controlPoints.2, controlPoints.3)
            )
            diffableDataSource.apply(snapshot, animatingDifferences: true, completion: completion)
            CATransaction.commit()
        } else if pinsToTop {
            performWithoutImplicitAnimations {
                diffableDataSource.apply(snapshot, animatingDifferences: false, completion: completion)
            }
        } else {
            diffableDataSource.apply(snapshot, animatingDifferences: false, completion: completion)
        }

        syncRefreshControl()
    }

    private func pinToRestingTop(layoutFirst: Bool = true, suppressingEndReachedEvaluation: Bool = false) {
        let updates = {
            self.performWithoutImplicitAnimations {
                if layoutFirst {
                    self.layoutIfNeeded()
                }
                self.setContentOffset(
                    CGPoint(x: -self.adjustedContentInset.left, y: -self.adjustedContentInset.top),
                    animated: false
                )
            }
        }

        if suppressingEndReachedEvaluation {
            withEndReachedEvaluationSuppressed(updates)
        } else {
            updates()
        }
    }

    private func withEndReachedEvaluationSuppressed(_ updates: () -> Void) {
        let wasSuppressingEndReachedEvaluation = suppressesEndReachedEvaluation
        suppressesEndReachedEvaluation = true
        defer { suppressesEndReachedEvaluation = wasSuppressingEndReachedEvaluation }
        updates()
    }

    private func performWithoutImplicitAnimations(_ updates: () -> Void) {
        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            updates()
            CATransaction.commit()
        }
    }

    @discardableResult
    private func updateInsets() -> Bool {
        // For the managed vertical layout, horizontal margins are applied as the compositional
        // layout's section insets (see `ShopCollectionListLayout.appliesHorizontalContentInsetsInLayout`),
        // never as the scroll view's horizontal contentInset — `.fractionalWidth(1)` is relative to the
        // collection view bounds, so a horizontal contentInset would make content wider than the
        // viewport and scroll sideways. Top/bottom stay on the scroll view so `.automatic` nav/safe-area
        // integration and the iOS 26 scroll-edge effect keep working. Custom layouts own their own
        // horizontal sizing, so their leading/trailing insets remain on the scroll view.
        let appliesHorizontalInsetsInLayout = layout.appliesHorizontalContentInsetsInLayout
        let leading = appliesHorizontalInsetsInLayout ? 0 : contentInsets.leading
        let trailing = appliesHorizontalInsetsInLayout ? 0 : contentInsets.trailing
        let insets = UIEdgeInsets(
            top: contentInsets.top,
            left: leading,
            bottom: contentInsets.bottom,
            right: trailing
        )
        let nextAdjustmentBehavior = insetAdjustmentBehavior.uiKitValue
        var didUpdate = false
        if appliedContentInsetAdjustmentBehavior != nextAdjustmentBehavior {
            contentInsetAdjustmentBehavior = nextAdjustmentBehavior
            appliedContentInsetAdjustmentBehavior = nextAdjustmentBehavior
            didUpdate = true
        }
        if appliedContentInset != insets {
            contentInset = insets
            appliedContentInset = insets
            didUpdate = true
        }
        // Match the scroll-indicator insets to the resolved content insets: `.vertical` resolves
        // horizontal to 0 (margins live in the section insets), while `.custom` keeps its caller-
        // supplied leading/trailing so its indicator placement is unchanged by the vertical fix.
        if appliedVerticalScrollIndicatorInsets != insets {
            verticalScrollIndicatorInsets = insets
            appliedVerticalScrollIndicatorInsets = insets
            didUpdate = true
        }
        if didUpdate {
            updateScrollEdgeEffects()
        }
        return didUpdate
    }

    private func updateScrollEdgeEffects() {
        shopUpdateScrollEdgeEffects()
        if #available(iOS 26.0, *), usesAutomaticTopScrollEdgeEffect {
            topEdgeEffect.style = .automatic
        }
    }

    private func syncRefreshControl() {
        guard onRefresh != nil else {
            return
        }

        if refreshControl !== refreshControlView {
            refreshControl = refreshControlView
        }

        if isRefreshing {
            userRefreshIntent = .none
            if refreshControlView.isRefreshing == false {
                refreshControlView.beginRefreshing()
            }
            return
        }

        guard refreshControlView.isRefreshing else {
            return
        }

        switch userRefreshIntent {
        case .none:
            refreshControlView.endRefreshing()
        case .awaitingProjection:
            break
        case .settledWithoutProjection:
            userRefreshIntent = .none
            refreshControlView.endRefreshing()
        }
    }

    private func updateLayoutIfNeeded(previousHeaderVisibility: [Bool], pinsToTop: Bool = false) {
        let nextLayoutIdentity = Self.layoutIdentity(for: layout, contentInsets: contentInsets)
        let visibleHeaderIndexesChanged = Self.visibleHeaderIndexes(in: previousHeaderVisibility) !=
            Self.visibleHeaderIndexes(in: lastHeaderVisibility)
        if nextLayoutIdentity != layoutIdentity || visibleHeaderIndexesChanged {
            layoutIdentity = nextLayoutIdentity
            let updateLayout = {
                self.setCollectionViewLayout(
                    Self.makeCollectionViewLayout(
                        layout: self.layout,
                        contentInsets: self.contentInsets,
                        headerVisibility: self.lastHeaderVisibility
                    ),
                    animated: false
                )
            }

            if pinsToTop {
                withEndReachedEvaluationSuppressed {
                    pinToRestingTop(layoutFirst: false)
                    performWithoutImplicitAnimations(updateLayout)
                    pinToRestingTop(layoutFirst: false)
                }
            } else {
                updateLayout()
            }
        }
    }

    private func registerRowReuseKinds(in sections: [Section]) {
        for kind in Self.rowReuseKinds(in: sections, rowReuseKind: rowReuseKind) where registeredRowReuseKinds.contains(kind) == false {
            registeredRowReuseKinds.insert(kind)
            register(RowCell.self, forCellWithReuseIdentifier: RowCell.reuseIdentifier(for: kind))
        }
    }

    private func snapshotItem(for item: Item) -> SnapshotItem {
        .content(
            id: item.id,
            reuseKind: rowReuseKind(item)
        )
    }

    private func reconfigureChangedVisibleContent(previousItemsBySnapshotItem: [SnapshotItem: Item]) {
        for indexPath in indexPathsForVisibleItems {
            guard let snapshotItem = diffableDataSource.itemIdentifier(for: indexPath),
                  let item = itemsBySnapshotItem[snapshotItem],
                  let cell = cellForItem(at: indexPath) as? RowCell else {
                continue
            }

            // Reconfigure only when the item's content actually changed (or it is newly visible with
            // no prior snapshot entry). Unchanged cards are left untouched, so a single line edit no
            // longer rebuilds and re-measures every visible card's SwiftUI subtree.
            if let previousItem = previousItemsBySnapshotItem[snapshotItem], itemsHaveEqualContent(previousItem, item) {
                continue
            }

            configure(
                cell,
                with: item
            )
        }

        // Headers do not have a separate content-equality hook, so visible headers are reconfigured
        // when an apply reaches the row-content reconfiguration step.
        for indexPath in indexPathsForVisibleSupplementaryElements(ofKind: UICollectionView.elementKindSectionHeader) {
            guard let section = section(at: indexPath.section),
                  let header = supplementaryView(
                      forElementKind: UICollectionView.elementKindSectionHeader,
                      at: indexPath
                  ) as? HeaderView else {
                continue
            }

            configure(header, with: section)
        }
    }

    private func configure(_ cell: RowCell, with item: Item) {
        let reuseKind = rowReuseKind(item)
        cell.configure(
            content: HostedRowContent(content: rowContent(item)),
            itemID: AnyHashable(item.id),
            hostingMode: reuseKind.hostingMode,
            parentViewController: registeredContentScrollViewController
        )
    }

    private func configure(_ supplementaryView: HeaderView, with section: Section) {
        supplementaryView.configure(
            content: HostedHeaderContent(content: headerContent(section))
        )
    }

    // Internal (not private) so unit tests can drive the apply-time evaluation deterministically
    // without depending on async snapshot completions or real layout. Called in production only
    // from the `applyCurrentConfiguration` completion.
    func evaluateEndReachedInCurrentScrollPosition() {
        // Mirrors React Native VirtualizedList/FlashList: edge-reached is evaluated after
        // layout/content changes as well as scroll events, and is latched once per re-arm token
        // while the trailing edge remains inside the threshold.
        evaluateEndReached(in: self)
    }

    private func evaluateEndReached(in scrollView: UIScrollView) {
        guard suppressesEndReachedEvaluation == false else {
            return
        }

        guard endReachedController.evaluate(
            in: scrollView,
            hasEndReachedHandler: onEndReached != nil,
            itemCount: totalItemCount,
            threshold: .absolute(endReachedLeadDistance),
            rearmKey: endReachedRearmToken.map { rearmToken in
                AnyHashable(
                    ShopCollectionListEndReachedTriggerKey(
                        rearmToken: rearmToken
                    )
                )
            }
        ) != nil else {
            return
        }

        onEndReached?()
    }

    private func shouldReportScrollOffset(_ offset: CGFloat) -> Bool {
        guard let previousReportedScrollOffset = lastReportedScrollOffset else {
            lastReportedScrollOffset = offset
            return true
        }

        guard abs(offset - previousReportedScrollOffset) >= ShopCollectionListViewMetrics.scrollOffsetReportingThreshold else {
            return false
        }

        lastReportedScrollOffset = offset
        return true
    }

    private func section(at index: Int) -> Section? {
        guard sections.indices.contains(index) else {
            return nil
        }

        return sections[index]
    }

    private static func layoutIdentity(
        for layout: ShopCollectionListLayout,
        contentInsets: ShopCollectionListContentInsets
    ) -> String {
        // Horizontal insets feed the section insets for vertical layouts, so the layout must be
        // rebuilt when they change. Custom layouts don't consume them, so keep their identity stable.
        guard layout.appliesHorizontalContentInsetsInLayout else {
            return layout.identity
        }

        return "\(layout.identity)|h:\(contentInsets.leading):\(contentInsets.trailing)"
    }

    private static func visibleHeaderIndexes(in headerVisibility: [Bool]) -> [Int] {
        headerVisibility.indices.filter { headerVisibility[$0] }
    }

    private static func makeCollectionViewLayout(
        layout: ShopCollectionListLayout,
        contentInsets: ShopCollectionListContentInsets,
        headerVisibility: [Bool]
    ) -> UICollectionViewLayout {
        switch layout {
        case let .vertical(rowSpacing, estimatedRowHeight, estimatedHeaderHeight):
            makeVerticalLayout(
                rowSpacing: rowSpacing,
                estimatedRowHeight: estimatedRowHeight,
                estimatedHeaderHeight: estimatedHeaderHeight,
                leadingInset: contentInsets.leading,
                trailingInset: contentInsets.trailing,
                headerVisibility: headerVisibility
            )
        case let .custom(customLayout):
            customLayout.makeLayout()
        }
    }

    private static func makeVerticalLayout(
        rowSpacing: CGFloat,
        estimatedRowHeight: CGFloat,
        estimatedHeaderHeight: CGFloat,
        leadingInset: CGFloat,
        trailingInset: CGFloat,
        headerVisibility: [Bool]
    ) -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(estimatedRowHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: itemSize,
                subitems: [item]
            )
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = rowSpacing
            // Horizontal margins live here (not on the scroll view's contentInset) so the section
            // width still matches the collection view bounds and never scrolls sideways. Top/bottom
            // margins stay on the scroll view, so they are intentionally zero here.
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: leadingInset,
                bottom: 0,
                trailing: trailingInset
            )

            if headerVisibility.indices.contains(sectionIndex), headerVisibility[sectionIndex] {
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(estimatedHeaderHeight)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
            }

            return section
        }
    }

    private static func snapshotItems(
        in sections: [Section],
        rowReuseKind: (Item) -> ShopCollectionListRowReuseKind
    ) -> [SnapshotItem] {
        sections.flatMap { section in
            section.items.map { item in
                .content(
                    id: item.id,
                    reuseKind: rowReuseKind(item)
                )
            }
        }
    }

    private static func itemsBySnapshotItem(
        in sections: [Section],
        rowReuseKind: (Item) -> ShopCollectionListRowReuseKind
    ) -> [SnapshotItem: Item] {
        var itemsBySnapshotItem: [SnapshotItem: Item] = [:]
        for section in sections {
            for item in section.items {
                let snapshotItem = SnapshotItem.content(
                    id: item.id,
                    reuseKind: rowReuseKind(item)
                )
                itemsBySnapshotItem[snapshotItem] = item
            }
        }
        return itemsBySnapshotItem
    }

    private static func rowReuseKinds(
        in sections: [Section],
        rowReuseKind: (Item) -> ShopCollectionListRowReuseKind
    ) -> Set<ShopCollectionListRowReuseKind> {
        Set(
            sections.flatMap { section in
                section.items.map(rowReuseKind)
            }
        )
    }

    private static func totalItemCount(in sections: [Section]) -> Int {
        sections.reduce(0) { partialResult, section in
            partialResult + section.items.count
        }
    }
}
