# ShopCollectionList

`ShopCollectionList` is Gravity's UIKit-backed vertical list foundation for SwiftUI screens that need real cell recycling.

It exists alongside, not instead of, `ShopScrollScreen`:

- Use `ShopScrollScreen` for static/detail/form screens and simple page composition.
- Use `ShopCollectionListScreen` or `ShopCollectionList` for long, dynamic, repeated, refreshable, or paginated vertical content.

Call sites should choose the primitive intentionally. Do not hide `ScrollView` and `UICollectionView` behind a wrapper that switches automatically; the performance and layout tradeoffs are different.

## Gravity boundary

This component is UI-only. It must not import Apollo, `ShopGraphQL`, `ShopAPI`, Orders, Feed, analytics, or feature/business logic.

`ShopCollectionList` emits UI signals only:

- pull-to-refresh through `onRefresh`,
- distance-from-end pagination through `onEndReached`,
- optional scroll offset updates through `onScrollOffsetChange`.

`ShopCollectionList` can render generic screen states (`loading`, `error`, `empty`, `content`) by inserting internal synthetic rows. Callers provide empty/error views and may override the default spinner with initial or pagination loading placeholders. Feature stores still own queries, cursors, error copy, retry semantics, dedupe, analytics, impression tracking, and whether pagination is available.

## When to use it

Use `ShopCollectionListScreen`/`ShopCollectionList` when a screen has one or more of these properties:

- repeated rows that can grow beyond a short static screen,
- pull-to-refresh over row content,
- pagination or infinite scroll,
- multiple logical sections,
- loading/error/empty/content phases that should preserve one stable scroll view,
- expensive row content where recycling matters,
- a future need for UIKit collection layout control.

Stay on `ShopScrollScreen` when the screen is mostly static composition: settings, login forms, detail pages, support/about pages, or short account surfaces.

## Public vs internal files

The source files intentionally stay in a flat `CollectionList/` folder so Xcode's filesystem-synchronized groups pick them up without project-file churn. Use file names and access control to distinguish layers:

- Public SwiftUI API: `ShopCollectionList.swift`, `ShopCollectionListScreen.swift`, `ShopCollectionListSection.swift`, `ShopCollectionListLayout.swift`, `ShopCollectionListContentInsets.swift`, `ShopCollectionListCustomLayout.swift`.
- Internal UIKit bridge/infrastructure: `ShopCollectionListRepresentable.swift`, `ShopCollectionListView.swift`, `ShopCollectionListHostedContent.swift`, `ShopCollectionListHostingCell.swift`, `ShopCollectionListHostingSupplementaryView.swift`.
- Local playground: `ShopCollectionListPreview.swift`.

## `ShopCollectionListScreen`

`ShopCollectionListScreen` is the full-screen equivalent to `ShopScrollScreen` for collection-list-backed screens. It wraps `ShopCollectionList`, applies the Gravity background, fills available space, and can apply a system navigation title/title display mode. It defaults to `.automatic` inset adjustment so system-navigation screens behave like native scroll views; callers still own any surface-specific overlay inset math.

Use it when the collection list is the screen root:

```swift
ShopCollectionListScreen(
    "Orders",
    titleDisplayMode: .large,
    sections: sections,
    layout: .vertical(rowSpacing: 0, estimatedRowHeight: 96),
    contentInsets: ShopCollectionListContentInsets(
        top: GravitySpacing.space8,
        bottom: GravitySpacing.space48 + bottomInset
    ),
    isRefreshing: store.isRefreshing,
    endReachedLeadDistance: 600,
    onRefresh: {
        await store.refresh()
    },
    onEndReached: {
        Task {
            await store.loadNextPageIfNeeded(trigger: "scroll-threshold")
        }
    },
    header: { section in
        headerView(for: section)
    },
    row: { item in
        rowView(for: item)
    }
)
```

If another parent already owns the navigation title or toolbar, do not nest `ShopCollectionListScreen` inside that screen. Use `ShopCollectionList` directly so there is only one screen-level owner of navigation chrome.

## Root-screen implementation checklist

When migrating a screen from `ScrollView + LazyVStack` or a large eager `ForEach`, keep these decisions explicit:

1. **Pick the owner of screen chrome.**
   - Use `ShopCollectionListScreen` when the list wrapper can own background, frame, and navigation title.
   - Use `ShopCollectionList` directly when the feature screen already owns phases, overlays, title, toolbar, or custom chrome.
2. **Model real content as sections.** Use `ShopCollectionListSection` and supplementary headers. Do not flatten headers into rows unless row semantics are intentional.
3. **Keep feature semantics feature-owned.** Domain row adaptation, row tap routing, analytics payloads, retry actions, and positional chrome such as `isFirst`/`isLast` belong in the feature. The list owns only generic state-row plumbing.
4. **Use stable row identities and content-aware equality.** Item IDs should be stable across refreshes and pagination, while `Equatable`/content comparison must include rendered state that changes a same-ID row's visible UI or height. See “Stable identity, equality, and dynamic-height rows” below.
5. **Use the list's pagination state slots.** Pass `isPaginating`, `paginationLoadingPlaceholderCount`, and `loadingPlaceholder` for load-more UI instead of adding a fake footer row to the feature item enum, unless the footer is truly feature content.
6. **Gate pagination in the feature.** Pass `onEndReached: nil` or otherwise disable the callback while there is no next page. Setting `isPaginating` disables the callback while a fetch-more request is already active.
7. **Use list callbacks instead of row lifecycle.** Use `onRefresh` and `onEndReached`; do not paginate from row `.onAppear`.
8. **Choose inset behavior intentionally.** System navigation/tab chrome and custom chrome use different settings; see below.

## Stable identity, equality, and dynamic-height rows

`ShopCollectionList` separates two concepts that feature adapters often accidentally collapse:

- **Row identity** answers “is this the same logical row?” and should stay stable across refreshes, pagination, and content updates. For example: `history:\(order.id)`, not `history:\(order.id):\(status):\(index)`.
- **Rendered-content equality** answers “can the existing visible cell keep rendering without being reconfigured/remeasured?” It must change when same-ID content changes visible UI or height.

This matters most for dynamic-height SwiftUI rows hosted in `UICollectionView` cells. UIKit can self-size the cells correctly only if the list reconfigures and remeasures rows whose content actually changed, while avoiding broad reconfiguration/invalidation for rows that did not change.

`ShopCollectionList` always uses targeted visible-row reconfiguration. Same-ID rows are reconfigured only when their rendered content changes according to `Item ==`. Include every value that can affect the visible row or its height, such as:

- conditional CTAs or badges,
- status/subtitle/title copy,
- price/count/refund text,
- image/collage membership or aspect-ratio-affecting data,
- divider/first/last/index chrome,
- feature flags or presentation fields that alter layout.

Good pattern when `Item ==` is already rendered-content equality:

```swift
enum OrderHistoryRow: Identifiable, Hashable {
    case history(item: OrderItem, index: Int, showsDivider: Bool)

    var id: String {
        switch self {
        case let .history(item, _, _): "history:\(item.id)"
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.history(lhsItem, lhsIndex, lhsDivider), .history(rhsItem, rhsIndex, rhsDivider)):
            lhsItem == rhsItem && lhsIndex == rhsIndex && lhsDivider == rhsDivider
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

When durable row state must stay outside the value item, use a lightweight item whose identity and row kind stay stable while the row view observes a stable model. This avoids rebuilding unchanged cells during refresh/inset/state applies:

```swift
struct OrderHistoryRow: Identifiable, Hashable, ShopCollectionListReusableItem {
    let id: String
    let model: OrderHistoryRowModel

    var collectionListReuseKind: ShopCollectionListRowReuseKind {
        ShopCollectionListRowReuseKind("orders.history")
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.collectionListReuseKind == rhs.collectionListReuseKind
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(collectionListReuseKind)
    }
}
```

### Dynamic-height self-sizing guidance

For self-sizing rows:

- choose a realistic `estimatedRowHeight`; a large mismatch between estimated and final row height causes scroll-position corrections as UIKit measures cells,
- keep row content full-width and vertically intrinsic (`frame(maxWidth: .infinity, alignment: ...)`, no greedy `GeometryReader`/`Spacer`/`maxHeight: .infinity` at the hosted root),
- avoid unnecessary global layout invalidation; let changed-item reconfiguration target only rows whose content changed,
- use `alwaysSuppressesSelfSizingAnimations` when dynamic-height changes must resize the row and reposition neighboring cells immediately, including while the list is idle,
- model pagination footers through `isPaginating`/`loadingPlaceholder` instead of feature rows so load-more state does not perturb feature row identity.

`ShopFeedCollectionView` is a useful behavior reference for pagination semantics, but it does **not** use the same dynamic self-sizing strategy: Feed owns a custom fixed layout with measured/cached section heights. `ShopCollectionList` uses compositional-layout estimated heights plus hosted SwiftUI self-sizing, so feature item identity/equality is part of the contract.

## Feature-caller row-performance contract

These rules apply to every long/repeated/paginated `ShopCollectionList`, not just one feature. The failure mode to avoid: a paginated append should add new content below the current viewport without making already-visible content jump, remeasure globally, or refetch because self-sizing corrected `contentSize`.

- Treat collection snapshot identity as stable row ID plus semantic row kind. Do not put mutable status/title/badge/image/index/divider content in `id` to force refreshes; change `collectionListReuseKind` only when the row's reusable view shape changes.
- For value rows, `Item ==` is the rendered-content comparison. It must include every same-ID value that can affect visible UI or height: review CTA, subtitle/status, price/badge/refund text, image/collage membership, divider/first/last/index chrome, feature flags, presentation fields, and layout-affecting formatting.
- For high-churn rows that should update without cell reconfiguration, keep durable row state in stable observable models and pass lightweight items conforming to `ShopCollectionListReusableItem`. Those items may compare by identity/kind while the hosted row observes the model directly.
- Use `isPaginating` plus `paginationLoadingPlaceholderCount`/`loadingPlaceholder` for load-more UI instead of adding a fake footer row to the feature item enum unless the footer is truly feature content. `ShopCollectionList` uses scroll geometry to decide whether the end threshold is eligible and a re-arm token to decide whether that eligible state already fired. Tokenless callers use controller-owned content-length progress, re-arming only on meaningful content-height growth; callers may pass semantic pagination progress such as a cursor, query generation, or explicit retry counter when content height can stay unchanged. Do **not** pass item IDs, visible/current item IDs, raw `contentSize.height`, row `.onAppear`, or values that change every render as pagination state.
- For hot self-sizing rows, precompute presentation in the store/viewmodel/renderable layer and make row `body` mostly read already-formatted strings/images/flags. Do not repeatedly scan GraphQL models, format money/date strings, derive collage arrays, or find CTA targets inside every row body/layout pass.
- When modifying shared `ShopCollectionListView` internals, never replace the `UICollectionViewLayout` for a pagination append/removal unless a real layout-affecting property changed. In particular, adding/removing a no-header pagination section must **not** call `setCollectionViewLayout`; compare visible header indexes, not raw header-visibility array length.
- Concrete row-kind callers: `Shop/Sources/Features/Orders/ShopOrderHistoryCollectionView.swift` and `Shop/Sources/Features/Orders/ShopOrdersCollectionView.swift`; row-kind regression coverage: `Shop/Tests/ShopCollectionListViewTests.swift`.

Canonical caller pattern:

```swift
struct RowItem: Identifiable, Hashable, ShopCollectionListReusableItem, Sendable {
    static let reuseKind = ShopCollectionListRowReuseKind("feature.row")

    let id: String                    // stable logical row identity
    let source: DomainModel           // for tap/event payloads
    let presentation: RowPresentation // precomputed rendered content

    var collectionListReuseKind: ShopCollectionListRowReuseKind { Self.reuseKind }

    // Rendered-content equality used by ShopCollectionList's targeted reconfigure path.
    static func == (lhs: RowItem, rhs: RowItem) -> Bool {
        lhs.id == rhs.id &&
            lhs.collectionListReuseKind == rhs.collectionListReuseKind &&
            lhs.presentation == rhs.presentation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(collectionListReuseKind)
    }
}

struct RowPresentation: Hashable, Sendable {
    let title: String
    let subtitle: String?
    let badgeText: String?
    let images: [ImageModel]
    let cta: CTA?
}

ShopCollectionList(
    state: state.phase == .loading ? .loading : .content,
    sections: [ShopCollectionListSection(id: "main", items: state.items)],
    layout: .vertical(estimatedRowHeight: 104),
    contentInsetAdjustmentBehavior: .automatic,
    isPaginating: state.isFetchingNextPage,
    paginationLoadingPlaceholderCount: state.showsPaginationFooter ? 1 : 0,
    onEndReached: state.canLoadNextPage ? { loadNextPage(state.items.last?.id) } : nil,
    loadingPlaceholder: { _ in PaginationFooter() },
    empty: { EmptyState() },
    error: { ErrorState() },
    header: { _ in EmptyView() },
    row: { item in RowView(item: item) }
)
```

Presentation precompute pattern:

```swift
@MainActor
struct FeaturePresentationBuilder {
    static func makeRenderable(from model: DomainModel) -> RowItem {
        RowItem(
            id: model.id,
            source: model,
            presentation: RowPresentation(
                title: model.title,
                subtitle: formatSubtitle(model),
                badgeText: formatBadge(model.price),
                images: Array(model.images.prefix(3)),
                cta: makeCTA(model)
            )
        )
    }
}

private struct RenderableItemsCache {
    private var sourceByID: [String: DomainModel] = [:]
    private var renderedByID: [String: RowItem] = [:]

    @MainActor
    mutating func renderableItems(from models: [DomainModel]) -> [RowItem] {
        models.map { model in
            if sourceByID[model.id] == model, let cached = renderedByID[model.id] {
                return cached
            }
            let rendered = FeaturePresentationBuilder.makeRenderable(from: model)
            sourceByID[model.id] = model
            renderedByID[model.id] = rendered
            return rendered
        }
    }
}
```

Shared `ShopCollectionListView` layout rule:

```swift
// Bad: pagination adds a no-header section, [false] -> [false, false], and this
// unnecessarily replaces the whole compositional layout, making visible content jump.
if previousHeaderVisibility != lastHeaderVisibility {
    setCollectionViewLayout(makeLayout(), animated: false)
}

// Good: only a real visible-header slot change replaces the layout.
let visibleHeaderIndexesChanged = visibleHeaderIndexes(previousHeaderVisibility) !=
    visibleHeaderIndexes(lastHeaderVisibility)
if nextLayoutIdentity != layoutIdentity || visibleHeaderIndexesChanged {
    setCollectionViewLayout(makeLayout(), animated: false)
}
```

## Insets, safe areas, and navigation bars

For a root collection list under a SwiftUI `NavigationStack` that should use native large-title and toolbar behavior:

```swift
// On the screen that owns navigation chrome:
.navigationTitle("Title")
.toolbarTitleDisplayMode(.inlineLarge)
.toolbar { ... }

ShopCollectionList(
    state: .content,
    sections: sections,
    contentInsets: ShopCollectionListContentInsets(
        top: GravitySpacing.space8,
        bottom: GravitySpacing.space48 + bottomOverlayInset
    ),
    contentInsetAdjustmentBehavior: .automatic,
    empty: { EmptyView() },
    error: { EmptyView() },
    row: rowView(for:)
)
.frame(maxWidth: .infinity, maxHeight: .infinity)
.ignoresSafeArea(.container, edges: [.top, .bottom])
```

For content-only call sites, use the convenience initializer and omit `state`, `loadingPlaceholder`, `empty`, and `error`.

Why this shape matters:

- `.automatic` lets UIKit add navigation/tab safe-area adjustments.
- `.ignoresSafeArea(.container, edges: [.top, .bottom])` prevents SwiftUI from also reserving top/bottom space around the UIKit scroll view.
- The internal collection view registers itself with the nearest hosting view controller via `setContentScrollView(_:for:)`, which lets UIKit navigation/tab bars observe the real scroll view for large-title collapse, toolbar placement, and adjusted insets.
- Keeping loading/error/empty/content inside one `ShopCollectionList` preserves one observed scroll view and avoids native title flashes during phase changes.
- On iOS 26+, `.automatic` list inset behavior also enables the collection view's top/bottom `UIScrollEdgeEffect` with the `.soft` style. This is the Liquid Glass edge blur/gradient used by native scroll views under navigation and tab chrome.
- Avoid forcing custom navigation backgrounds such as `.toolbarBackground(.visible, for: .navigationBar)` unless the design explicitly wants to opt out of the scroll edge effect. Opaque or forced toolbar backgrounds can mask the native edge material.
- Caller-supplied `contentInsets` should represent list spacing and app overlays only; do not bake the navigation bar height into them.
- **Horizontal `contentInsets` (`leading`/`trailing`) for the `.vertical` layout are applied as the compositional layout's section insets, not the scroll view's `contentInset`.** `.fractionalWidth(1)` is relative to the collection view bounds (not bounds minus `contentInset`), so a horizontal scroll-view inset would make the content wider than the viewport and scroll sideways. A vertical list never scrolls horizontally. Either pass horizontal `contentInsets` (handled correctly) or pad rows yourself — but not both. (`.custom` layouts own their own horizontal sizing, so their horizontal insets stay on the scroll view.) Mirrors `ShopFeedCollectionView`, which keeps horizontal margins in its section insets.

For custom chrome such as Feed-style screens, use `.never` and manage every inset manually in the feature.

## Content-only usage

For surfaces that do not need loading/error/empty list rows, use the content-only convenience initializer:

```swift
ShopCollectionList(
    sections: [
        ShopCollectionListSection(
            id: "ongoing",
            items: ongoingItems,
            showsHeader: true
        ),
        ShopCollectionListSection(
            id: "past",
            items: pastItems,
            showsHeader: true
        ),
    ],
    layout: .vertical(rowSpacing: 0, estimatedRowHeight: 96),
    contentInsets: ShopCollectionListContentInsets(
        top: GravitySpacing.space8,
        bottom: GravitySpacing.space48 + bottomInset
    ),
    isRefreshing: store.isRefreshing,
    endReachedLeadDistance: 600,
    onRefresh: {
        await store.refresh()
    },
    onEndReached: {
        Task {
            await store.loadNextPageIfNeeded(trigger: "scroll-threshold")
        }
    },
    header: { section in
        headerView(for: section)
    },
    row: { item in
        rowView(for: item)
    }
)
```

For a single section with no header, use the `items:` convenience initializer.

## Stateful usage

For screens that need stable loading/error/empty/content transitions, use `state` and provide caller-owned state views:

```swift
ShopCollectionList(
    state: phase,
    sections: sections,
    isRefreshing: store.isRefreshing,
    isPaginating: store.isFetchingNextPage,
    initialLoadingPlaceholderCount: 4,
    paginationLoadingPlaceholderCount: 1,
    onRefresh: {
        await store.refresh()
    },
    onEndReached: canLoadNextPage ? loadNextPage : nil,
    initialLoadingPlaceholder: { context in
        OrdersInitialSkeletonRow(index: context.index)
    },
    loadingPlaceholder: { _ in
        OrdersPaginationLoadingRow()
    },
    empty: {
        OrdersEmptyState(onConnect: connectAccount)
    },
    error: {
        OrdersErrorState(message: store.errorMessage, retry: retry)
    },
    header: { section in
        headerView(for: section)
    },
    row: { item in
        rowView(for: item)
    }
)
```

`ShopCollectionList` inserts synthetic rows for loading, empty, error, and pagination placeholders internally. The feature does not need to add placeholder cases to its item enum unless it has a truly custom mixed-content requirement.

## Retained-list accessibility

A `ShopCollectionList` intentionally retained behind another surface must hide its represented UIKit accessibility subtree while occluded:

```swift
ShopCollectionList(/* ... */)
    .accessibilityElementsHidden(isOccluded)
```

A SwiftUI ancestor's `accessibilityHidden(_:)` does not reliably cross the `UIViewRepresentable` boundary into hosted collection rows. This modifier sets `accessibilityElementsHidden` on the backing `UICollectionView` without unmounting it or discarding scroll and data state. The owner of the visibility contract must restore accessibility when the list becomes visible.

## Pagination model

Pagination is intentionally a signal, not a data source.

`ShopCollectionList` uses the same shared distance-from-end controller as `ShopFeedCollectionView`:

```swift
distanceFromEnd = contentLength - visibleLength - offset
fires when distanceFromEnd <= thresholdDistance
```

For `ShopCollectionList`, `thresholdDistance` is the absolute `endReachedLeadDistance` in points. The calculation reads UIKit metrics directly from the collection view (`bounds.height`, `contentSize.height`, `contentOffset.y`). It is **not** driven by SwiftUI scroll state.

The trigger is evaluated from both scroll events and post-apply/layout updates. This intentionally mirrors React Native VirtualizedList/FlashList semantics:

- no downward-scroll requirement,
- short content can fire after layout even if the user cannot scroll,
- content already inside the lead distance can fire after an apply,
- the callback is latched once per re-arm token while inside the threshold.

The re-arm token is the duplicate-fetch guard at the list layer. Tokenless callers use controller-owned content-length progress as the default token, so the same scroll position can fire again when appended content meaningfully grows the content length; replacement/layout passes that shrink or preserve height do not re-arm. Callers that need to re-arm without a rendered height change may pass a semantic pagination token such as a cursor, query generation, or explicit retry counter. Do not use item IDs, visible/current item IDs, raw `contentSize.height`, row `.onAppear`, or a new value per render as a token; those replay pagination for row identity or render churn instead of pagination progress. Leaving and re-entering the threshold does not re-arm by itself. Do not clear this latch just because `onEndReached` flips nil/non-nil or `isPaginating` ends; doing so can replay the same GraphQL variables for the same rendered data.

**The list also suppresses `onEndReached` while `isPaginating` is `true`.** A fetch already in flight cannot trigger another, so callers do **not** need to nil-gate `onEndReached` themselves — just set `isPaginating` while loading (which you already do to render the pagination row). Nil-gating remains valid and is harmless if you prefer it, but it must not be the only duplicate-request guard.

Feature stores or shared app helpers still own:

- cursors and page info,
- network fetches,
- duplicate in-flight guards,
- retry/error state,
- stale response handling,
- whether `onEndReached` is enabled when there is no next page.

For lists using `state`, pass `isPaginating` to show a bottom loading row while fetch-more is in flight. If `loadingPlaceholder` is omitted, Gravity renders a centered `ShopSpinner` that matches the previous hand-rolled pagination footer. Pass `loadingPlaceholder` and, optionally, `paginationLoadingPlaceholderCount` when a feature needs custom pagination placeholders. Initial `.loading` uses the same default spinner unless the feature passes `initialLoadingPlaceholder` and, optionally, `initialLoadingPlaceholderCount`.

For new app query-backed screens, keep pagination state in the app data layer via `ShopQuery` with `ShopGraphQLConnection` (see `packages/shop-native-swiftui/docs/query-associated-store-howto.md`). Legacy stores may still use helpers in `Shop/Sources/Shared/Pagination/` while they await migration, but do not start new SwiftUI query-backed stores there. The Gravity list should not know about Apollo, GraphQL operations, or cache policies.

### How the trigger is detected

`ShopCollectionList` evaluates distance-from-end inside the UIKit collection view and shared `ShopCollectionEndReachedController`. **It does not require the caller to wire `onScrollOffsetChange` for pagination** — that callback is an unrelated reporting hook (for example, header fade progress or preview diagnostics). Do not round-trip scroll offset through SwiftUI `@State` to decide pagination.

Distance-from-end is one of three standard iOS pagination approaches, alongside `UICollectionViewDataSourcePrefetching` (Apple's recommended default for loading the next page before the end) and a `willDisplay` last-cell trigger. It is used here because it gives explicit control over `endReachedLeadDistance` and matches the native Feed pagination contract. If a future surface needs earlier data prefetch decoupled from scroll position, prefetching is the natural upgrade — keep the same `onEndReached`/`canFetchMore` contract and preserve the same-data duplicate guard.

## Refresh model

`onRefresh` is backed by `UIRefreshControl` and accepts an async callback. The feature store owns refresh semantics and state; the shared list starts the native refresh control and reflects the `isRefreshing` prop.

The `isRefreshing` prop is the single source of truth for the refresh lifecycle. The list begins the control when `isRefreshing` becomes `true` and ends it when `isRefreshing` becomes `false`; it never ends the control just because the `onRefresh` callback returned. `onRefresh` is a pure user-intent signal ("the user pulled") — callers commonly submit fire-and-forget work that returns long before the real refresh completes, so completion is not a reliable end signal. This matches the Home Feed collection view and removes the begin/end churn of a completion-driven end.

Callers therefore must project an `isRefreshing` that truthfully spans the whole refresh window: `true` from the moment work is submitted until it finishes. `ShopQuery` stores should project this from `ShopGraphQLQueryState`; legacy `ShopPaginatedConnection` stores get it from `connection.isRefreshing`; the cart models it with a local `isManualRefreshing` flag toggled around its awaited work. The per-store-type projection rules are the single source of truth in **`Shop/Sources/Shared/Pagination/README.md` -> "Pull-to-refresh contract"** — follow it for every refreshable list so all surfaces behave identically.

### Indicator style

The refresh indicator **defaults to the branded Shop spinner** (`.shopIndicator`). To opt out to the native iOS spinner, apply `.refreshStyle(.system)`:

```swift
ShopCollectionList(state: phase, sections: sections, isRefreshing: store.isRefreshing, onRefresh: { await store.refresh() }, empty: { ... }, error: { ... }, row: rowView)
    .refreshStyle(.system) // opt out of the branded indicator
```

- `.shopIndicator` (default) installs Gravity's branded UIKit spinner inside `ShopRefreshControl` and hides UIKit's system activity indicator. The underlying `UIRefreshControl` still owns the pull gesture, threshold, refreshing inset, and begin/end semantics.
- `.system` uses the native `UIRefreshControl` spinner.

## Impression and visibility tracking

`ShopCollectionList` does **not** include a generic visibility or impression API.

Features with analytics requirements should keep their own visibility trackers and event pipelines. Home Feed already has specialized impression/media visibility requirements, so those should not be generalized into this primitive until a concrete design requires it.

## Implementation walkthrough

The component is split into a public SwiftUI API layer and internal UIKit infrastructure:

```text
SwiftUI screen
└── ShopCollectionList / ShopCollectionListScreen
    └── ShopCollectionListRepresentable (internal UIViewRepresentable)
        └── ShopCollectionListView (internal UICollectionView)
            ├── UICollectionViewDiffableDataSource<Section, Item>
            ├── ShopCollectionListHostingCell<ShopCollectionListHostedContent<Row>>
            └── ShopCollectionListHostingSupplementaryView<ShopCollectionListHostedContent<Header>>
```

Update flow:

1. A feature maps domain models into `[ShopCollectionListSection<SectionID, Item>]`.
2. `ShopCollectionList` maps public content/state into internal sections and rows.
3. `ShopCollectionListRepresentable` passes layout, insets, callbacks, and SwiftUI row/header builders into `ShopCollectionListView`.
4. `ShopCollectionListView` builds a diffable snapshot and applies it without animation.
5. Cells and supplementary headers host SwiftUI content through `UIHostingConfiguration` by default. Row reuse kinds can opt into a persistent `UIHostingController` when stable hosted identity is required. Persistent hosts survive same-item reconfiguration, reset when a cell changes item IDs, and detach from their parent controller when destroyed.
6. If item IDs are unchanged, visible cells are reconfigured so row chrome can update without forcing a full list rebuild.
7. Refresh state is mirrored onto the native refresh control after the current configuration is applied.
8. Scroll delegate callbacks drive `onScrollOffsetChange`, `onEndReached`, and UIKit scroll-view registration.

## File-by-file guide

### `ShopCollectionList.swift`

Public SwiftUI-facing API.

Responsibilities:

- stores public configuration (`state`, `sections`, `layout`, `contentInsets`, inset behavior, indicators, refresh, pagination, scroll offset),
- creates internal synthetic rows for loading, error, empty, and pagination placeholders,
- forwards content-only lists through convenience initializers,
- passes the resulting internal sections/rows to `ShopCollectionListRepresentable`.

### `ShopCollectionListRepresentable.swift`

Internal direct `UIViewRepresentable` bridge. The represented root UIKit view is the internal `UICollectionView` subclass, not a wrapper controller. This keeps UIKit's navigation/tab-bar scroll-view discovery path as direct as possible.

Responsibilities:

- creates `ShopCollectionListView` in `makeUIView`,
- forwards SwiftUI updates to the existing collection view in `updateUIView`,
- keeps UIKit-specific bridge mechanics out of the public API file.

### `ShopCollectionListScreen.swift`

Full-screen convenience wrapper, equivalent in spirit to `ShopScrollScreen` but backed by `ShopCollectionList`.

Responsibilities:

- fills available space,
- applies the Gravity background,
- optionally sets `navigationTitle` / `navigationBarTitleDisplayMode`,
- defaults to `.automatic` inset adjustment for normal system-navigation screens,
- leaves screen-specific row data, overlays, footer rows, and pagination state to the caller.

Use this only when the wrapper should own screen-level chrome. If a feature screen already owns phases, overlays, title, or toolbar, use `ShopCollectionList` directly.

### `ShopCollectionListSection.swift`

Public section model used by diffable snapshots.

Responsibilities:

- gives each logical section a stable `id`,
- carries row `items`,
- controls whether a supplementary header should be requested through `showsHeader`,
- keys `Hashable` identity on `id` only — `items` and `showsHeader` are intentionally excluded so the diffable snapshot tracks a section by identity while row-level changes flow through item identifiers and cell reconfiguration, not section equality.

Use sections even when the first implementation has one section; it keeps future headers/pagination boundaries explicit.

### `ShopCollectionListLayout.swift`

Public layout strategy enum.

Responsibilities:

- exposes `.vertical(rowSpacing:estimatedRowHeight:estimatedHeaderHeight:)` for standard screens,
- exposes `.custom(ShopCollectionListCustomLayout)` as the escape hatch for specialized UI-only `UICollectionViewLayout` factories,
- carries a layout identity string so `ShopCollectionListView` can swap layouts only when needed.

Most screens should start with `.vertical(...)`.

### `ShopCollectionListCustomLayout.swift`

Public wrapper around a `UICollectionViewLayout` factory.

Responsibilities:

- allows specialized screens to provide a custom layout without moving feature logic into Gravity,
- keeps custom layout creation lazy and UIKit-owned.

Use only when `.vertical(...)` cannot express the UI. Feed may eventually use this style of hook after its business-specific snapping/media/impression behavior is separated from collection plumbing.

### `ShopCollectionListContentInsets.swift`

Public typed inset model and inset-adjustment behavior enum.

Responsibilities:

- stores explicit top/leading/bottom/trailing list spacing,
- maps `.automatic` / `.never` to UIKit `UIScrollView.ContentInsetAdjustmentBehavior`,
- documents the split between system-navigation screens and custom-chrome/manual-inset screens.

Use Gravity spacing tokens when constructing values. Do not include navigation-bar height in explicit insets; UIKit owns that for `.automatic` lists.

### `ShopCollectionListView.swift`

Internal `UICollectionView` subclass and the core implementation.

Responsibilities:

- owns the diffable data source and supplementary-view provider,
- registers reusable hosting cells and supplementary headers,
- creates/switches `UICollectionViewCompositionalLayout` instances,
- applies snapshots and avoids unnecessary visible-cell reconfiguration on pagination appends,
- manages explicit and adjusted content insets,
- attaches `UIRefreshControl`/`ShopRefreshControl` and reflects the projected `isRefreshing` value,
- computes distance-from-end pagination without row `.onAppear`,
- forwards scroll offsets,
- registers itself with the nearest hosting view controller using `setContentScrollView(_:for:)`,
- enables iOS 26 `.soft` `UIScrollEdgeEffect` for `.automatic` lists and hides it for `.never` lists.

This file should remain UI infrastructure only. Do not add Orders, Feed, GraphQL, analytics, or domain-specific pagination logic here.

### `ShopCollectionListHostingCell.swift`

Internal reusable collection-view cell for SwiftUI row content.

Responsibilities:

- hosts row views with `UIHostingConfiguration` and zero margins by default,
- retains a reusable `UIHostingController` for row reuse kinds that explicitly opt into persistent hosting,
- preserves local SwiftUI state for same-item reconfiguration while resetting it when the hosted item ID changes,
- removes persistent hosting controllers from UIKit containment during teardown,
- keeps cell/background clear so feature rows own their own surfaces,
- uses `systemLayoutSizeFitting` in `preferredLayoutAttributesFitting` for variable-height rows.

### `ShopCollectionListHostingSupplementaryView.swift`

Internal reusable supplementary header view for SwiftUI section headers.

Responsibilities:

- hosts header views using `UIHostingConfiguration.makeContentView()`,
- pins the hosted content to all edges,
- recreates the hosted content view on reuse instead of assigning a different generic `UIHostingConfiguration` type to an existing content view,
- uses `systemLayoutSizeFitting` for variable-height headers.

### `ShopCollectionListHostedContent.swift`

Internal wrapper around row/header SwiftUI content.

Responsibilities:

- provides a stable hosted root view type for cells and headers,
- expands hosted content to the full available width,
- keeps row/header builders simple while preserving self-sizing behavior.

### `ShopCollectionListPreview.swift`

Isolated playground and regression surface.

It currently demonstrates:

- 0 / 5 / 30 / 100 rows,
- one or two sections,
- supplementary headers on/off,
- variable-height SwiftUI rows,
- explicit content insets,
- scroll indicators on/off,
- pull-to-refresh,
- distance-based pagination,
- scroll offset callback metrics,
- `.never` vs `.automatic` inset behavior,
- a dedicated `NavigationStack` preview for native large-title collapse and iOS 26 soft scroll-edge effects.

The playground host mirrors how Orders wires the list (`onEndReached` gated by a
`canLoadNextPage` flag so it flips nil ↔ non-nil across every load). It logs every `onRefresh`/`onEndReached` callback to an `os.Logger`
(category `Playground`, subsystem `com.shopify.shop.gravity.collectionlist`) and an on-screen
timeline. An end-reached that fires without an intervening downward scroll is flagged red as
"NO SCROLL" and counted by the detector banner — that is the signature of the apply-time
double-fetch (an unsolicited second fetch after a refresh or an appended page). Run it on a
simulator (timing-sensitive callbacks don't fire in the static canvas), keep ≥30 rows so the
list is taller than the screen, then pull-to-refresh and scroll to the bottom: the banner
must stay green. A no-scroll fire is only legitimate when the content is shorter than the
viewport (use the 0/5-row buttons to see that allowed case).

## Related docs

- `packages/shop-native-swiftui/docs/shared-collection-list-plan.md`
- `packages/shop-native-swiftui/docs/query-backed-paginated-screens.md`
- `packages/shop-native-swiftui/Shop/Sources/Shared/Pagination/README.md`
- `docs/native-toolkit/platforms/ios.md`
