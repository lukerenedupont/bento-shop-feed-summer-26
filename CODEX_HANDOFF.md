# Codex handoff

Updated: 2026-09-08

## Repository state

- Repository: `/Users/lukedupont/bento-shop-feed-summer-26`
- Branch: `feed-interactive-cards`
- Handoff remote: `public` (`lukerenedupont/bento-shop-feed-summer-26`)
- The branch starts from `5936382`; do not merge it into or push it over `main` without explicit instruction.

## Next Generation Feed branch

- The approved editorial language now extends to outfit and comparison. Outfit keeps a compact purchased-jacket row, shared heavy Wear it with title, larger fitted pants photography, and the canonical Buy pants URL. Comparison uses Down to these two, larger studio-margin crops, staggered candidates with inline finishes/prices, a quiet focus check, and a direct View chair arrow. Other candidates moved to the More/Shortlist options menu; focus-retaining comparison logic is unchanged. `GenerativeEditorialProductPhoto.swift` owns verified local presentation crops (no new assets or generated imagery). Build/media checks pass at 181944 KB; UI expectations updated for the heading/menu, but full tests and actual-feed geometry checks are deferred for the user's fast visual-review loop.

- Fast visual review: Standards Manual now uses `GenerativeEditorialMerchantCard.swift`, the existing `feedCardTitleStyle()` heavy topic typography, a paper-toned surface, and overlapping crops of the three canonical book-cover photographs. Tapping a cover focuses it; the product row opens canonical details. Thumbnail picker/Next book are removed from this composition. This was the first visual pass; the outfit/comparison follow-up is recorded above. Build and media validation passed; full UI tests intentionally deferred at the user's request for faster visual iteration. Review with `./Scripts/run_generative_feed.sh gallery 2` before broadening this direction.

- The fisheye experiment (`44c5afe`) was removed at the user's request. Its package, adapter, controls, extra catalog media and tests are removed; Standards Manual is restored to its previous editorial grouping. Jacket, comparison and room refinements remain. Removal validation: Simulator build/launch, 19-image provenance check and personalized-feed validation pass. No new full UI-test run was performed for the removal.

- The current feel test has six signal-driven shopping experiences in Luke's For You. It evolves the four-card scaffold (`cd20f57`); the twenty decorative layouts remain archived at `f5cb6ab`. Other buyers/topics/custom feeds use the pre-existing planner.
- `GenerativeFeedPrototypeFixtures.swift` declares explicitly simulated purchase, repeated-view, merchant-affinity and active-World signals. Do not present these as real account history.
- `SampleData/NextGenerationFeedCardCatalog.swift` owns signal → supported job → retrieval → semantic spec. Its `prototypeMerchants` snapshot is shared by Home, gallery and inspector, avoiding merged/live inventory changing the fixture. `Models/NextGenerationFeedCard.swift` defines primary entity types, groupings and supported inputs; it does not supply arbitrary visual values.
- Six experiences: jacket + swap pants; focused chair comparison; Standards Manual's editorial Graphic standards grouping; saved table + chair; coffee counter/commute directions; Forom/House of Leon/Lichen discovery. The new group-led compositions intentionally do not offer misleading product-only Hero alternates.
- `NextGenerationFeedCardView.swift` is the shared renderer; `GenerativeDiscoveryComposition.swift` owns direction and merchant-led compositions. The first two cards now use `GenerativeDecisionCompositions.swift`: a fixed jacket with changeable pants, and two simultaneously visible chair candidates. Bounded media cannot expand the feed. Nineteen exact images are bundled with provenance; the extra black-chair studio image is from that same SKU's canonical gallery.
- `GenerativeFeedPrototypeSession` owns selected/dismissed products, chosen direction/merchant, supported signal/job overrides, revisions, enabled signals and order. Group choice is a hard relevance gate. Regeneration repeats retrieval and deterministic reranking while retaining valid state; no model API is called.
- Screenshot-directed follow-up: the outfit card now places the purchased jacket at the top, then Wear it with and a horizontal pants carousel with a next-item peek. Buy pants opens the selected pants' canonical merchant page. Media, title, price, save state and purchase URL follow the same selection. Saved looks remains secondary; Hero retains thumbnail choices. Header long-press has priority over its product tap so consumer-mode inspection still works.
- Room-card polish: a compact saved-table header now precedes a large square chair carousel, replacing the letterboxed strip and separate thumbnail row. Exact photography remains fitted and uncropped. Paging carries the selected chair into and out of the room-plan sheet. The room card now shares the refined header/footer clearance used by the first two jobs.
- First-card polish adds exact saved outfit pairs, comparison focus, same-currency decimal price deltas, a third-candidate swap that retains the focused chair, and secondary shortlist removal. `GenerativeShoppingReview.swift` provides saved-look review and exact product details with canonical merchant PDP links. Saves remain local/session-only; this is not a full Wardrobe World or authenticated favorites.
- Consumer preview starts with a disclosure of simulated activity, then hides demo/debug chrome. Sliders in design mode—or a long press on a consumer heading—open `GenerativeFeedInspector`. The chair scenario supports repeated-view/saved signals and compare/resume jobs. Other scenarios offer only valid inputs.
- Inspector toolbars keep Regenerate this card and Feed always reachable. `GenerativePrototypeTools` hosts a stable feed editor with signal switches, drag-handle reordering, regenerate-all and consumer preview. Disabling every card retains an Edit demo feed recovery control.
- Run `./Scripts/run_generative_feed.sh [feed|gallery|consumer] [0...5]`. Existing launch flags remain. The gallery uses stable card identity across reordering and the same session/renderer as Home. Use gallery for exact-index review: the inherited native feed deep-link can initially settle on a neighboring snap slot; ordinary swipe navigation is verified.
- Room-plan sheet and feed still share session state. Full persistent World integration/AR, general AI generation, automatic adjacency ranking, arbitrary inputs, profile editing and the full 10–12-case feed remain unbuilt; see `NEXT_GENERATION_FEED.md`.
- The first-card pass passed all fifteen tests (`/tmp/generative-first-cards-acceptance.log`). The subsequent carousel revision passed four focused acceptance checks (`/tmp/generative-pants-carousel-acceptance.log`): native consumer swiping/purchase URL coupling, saved-pair retention, alternate-composition state, and consumer disclosure/long-press inspection. The later room-hero revision passes three focused checks, including real-feed hero height (≥300pt), reachable actions, swipe/sheet continuity and all-six-card bounds (`/tmp/generative-room-hero-tests.log`). Full-suite reruns remain pending for these quick layout revisions.
- Bottom navigation has bounded hit geometry. The outfit, comparison and room card treatments use shared header/foreground tokens and reserve actual bottom layout space, with additional clearance for whichever entry occupies the first-card takeover slot. Other generated cards retain their previous layout. Visual offsets are not substitutes for reachable controls.
- Legacy `Media/` films remain excluded from this branch target, not deleted. The original `184320 KB` gate is unchanged; this build is approximately `181660 KB`.
- Dedicated Simulator: `Feed Interactive Cards` (`A2AA7E39-93E3-47FE-8599-B523E3358700`), derived data `/tmp/pi-feed-interactive-cards-derived`.

## Full prototype baseline

The feed is personalized for Luke, Mikhail, Tobi, Katarina, Kenny, and Archie.
Each buyer receives authored For You and topic feeds backed by the local buyer
profile/catalog data. Feed presentation is shared across buyers rather than
forked into per-profile views.

### Feed and topic behavior

- For You opens at the utility rail and resets there when revisited.
- The first feed card smoothly takes over the viewport as the utility rail
  leaves, and subsequent cards share the same full-bleed snap geometry.
- Cards retain a 40pt bottom radius and expose the next-card peek above the
  bottom navigation.
- Topic feeds enter in the normal full-width white-background state and reuse
  the same header navigation component.
- Topic drill-ins preserve buyer context and use shared-view navigation.
- Authenticated shelf exports for every preview buyer contribute privacy-safe
  shelf type, persona, price-band, quality, and related-shelf signals. Raw
  hypotheses, queries, activity, suppression history, and provenance stay out
  of the app bundle.
- Topic drill-ins use those relationships for featured collections and require
  both semantic and price-band fit before showing canonical merchant cards.
- Lifestyle covers are selected from verified topic/product/merchant media;
  merchant cards require a verified bundled wordmark and merchant-owned cover.
- The 10 canonical Luke topics now prefer approved merchant-owned covers from
  exact PDP galleries or relevant Nocs, Fellow, and Extra Butter editorial
  pages. Feed cards, topic headers, and topic feature cards share the same
  `FeedCoverCatalog` decision and retain the bundled covers as load fallbacks.

### Shared presentation components

- `BuyerFeedNavigationBar.swift` owns the buyer avatar and top-level topic
  chips, including the selected white pill and shared shadow treatment.
- `FeedCardStyle` owns shared card radius, spacing, peek, and bottom-navigation
  clearance tokens.
- `GravityShadows` and `GravityTypography` own utility, selected-topic, feed
  contrast, and editorial typography treatments.
- Feed cards, merchant cards, posts, and product cards share the same contrast,
  corner, favorite-heart, and typography conventions.
- Utility cards use a shared horizontal snap rail and consistent card/product
  sizing. Luke currently exposes the Your orders example.

### Opt-in World prototypes

Luke’s experimental Worlds are disabled by default and can be enabled
individually from the avatar/overflow feed-controls sheet. Following and Deals
can also be hidden there without altering the underlying authored feeds. Each
feed independently persists its mix of general recommendations, merchant
cards, and merchant-authored posts; enabled Worlds remain separately managed.

- `HomeFeedPlanner.swift` is the single feed-planning seam. It resolves authored
  and followed content, distributes posts, prioritizes Worlds, applies each
  feed’s composition settings, inserts campaigns, reports available card-type
  counts, and memoizes the resulting render plan.
- `SuggestedCollectionsFeedCard.swift` is the first reusable format in the
  expanded feed-card library. A compact `SuggestedCollectionsPresentation`
  interface carries real catalog-backed `FeedStory` destinations plus authored
  full-bleed hero media; the card owns horizontal snapping, neighboring peeks,
  active surface-color transitions, overflow, and shared-view collection
  navigation. It has its own per-feed **Suggested collections** composition
  toggle rather than inheriting the broader Recommendations toggle. Luke's For You
  feed inserts it after the lead story with Caps, warm lighting, and trail-run
  collections ranked through the same custom-feed catalog retrieval seam.
- Shopper-created feeds now persist their entered phrase as `customIntent`
  instead of copying placeholder For You story IDs. `CustomFeedRecommendationEngine`
  searches every product in the merged global merchant catalog, requires an
  intent match, then uses the selected buyer's authored products, merchant
  affinity, followed shops, and available shopper signals to rank those
  matches. It emits deterministic catalog-backed `FeedStory` cards; generated
  stories travel through `HomeRoute.customStory` so their detail pages retain
  the exact assortment even though they are not in the authored catalog.
- `WorldDomain.swift` owns World identity, context, lifetime, session state, and
  preference persistence. Parent/child relationships remain separate from
  identity. Mission state now records a product selection and an owned, rent,
  or buy decision per readiness step rather than treating completion as an
  independent checkbox.
- `CanvasAgentWorldDestination.swift` owns the Watch Canvas presentation,
  steering, shared chrome alignment, and feed-cover Canvas preview.
- `CanvasAgentInfiniteProductCanvas.swift` is the source-aligned Canvas engine
  adapted from `shopify-playground/canvas-agent` at commit `a5957f4`.
- `CanvasAgentSupport.swift` is the adapter seam between canonical Shop
  products and Canvas products.
- `VerySpecialWatchCatalog.swift` owns the deterministic 47-watch snapshot from
  Very Special’s official Watches collection, including canonical prices,
  imagery, and PDP destinations.
- `WorldExperienceViews.swift` contains the remaining lightweight World forms;
  Canvas and Spatial no longer share that implementation file.
- The Ski weekend Mission World is now an editable readiness plan. Compact
  context menus capture mountain, dates, ability, and travel method; expandable
  sections join authentic catalog products to owned/rent/buy decisions; and a
  live packing plan summarizes the choices. Hard gear combines the canonical
  setup shelf with its related all-mountain ski shelf, while the remaining
  sections retrieve matching products from the merged catalog.
- `SpatialARWorldDestination.swift` owns the camera-first Spatial destination:
  a live ARKit surface on supported iPhones with a looping room-film fallback
  in Simulator, a floor-finding reticle, a swipeable product picker, place and
  remove actions, pinch-to-resize, and tap-through to real PDPs. Product
  placement is an explicit visual prototype until production 3D assets exist.
- `GiftGuideCreationFlow.swift` owns the gift-guide creation flow and the
  persisted `GiftGuideBrief`/`GiftGuideBriefStore`. The utility belt leads with
  a shared-styling `UtilityBeltPromotionCard` gift entry; completing the flow
  personalizes and opens the existing gift World, whose recipient name,
  occasion, and interests now flow through `GiftGuidePrototypeState` into
  titles, steering copy, and product ranking.

The Watch Canvas feed card uses a noninteractive instance of the real Canvas
engine as its cover. Opening it restores full pan, zoom, density, steering,
product actions, and Shop PDP routing. The destination computes its own safe
area chrome, so callers provide only the World session, resolved products, and
close action.

World feed cards anchor their title and product treatment as one bottom
composition (`usesWorldCardComposition` in `StoryFeedCard`). A compositor-only
`visualEffect` lift pins that composition above the floating bottom navigation
while the card travels toward its snap slot, mirroring the top-pinned title
mechanism. The delayed Explore more button has been removed; the card itself
remains the destination affordance.

### Try your faves world

The world is a fixed seed avatar the shopper dresses with saved products.
Every page is **one flat photograph**, centred and filling the viewport, with
its environment baked into the render. There is no figure cutout and no
separate backdrop plate; an earlier revision composited a lifted cutout over a
plate, and the assets from it are still in the catalogue.

- The seed photograph is the design's warm-interior editorial frame.
  `try-faves-avatar` is both the generator's model input and the Home card
  cover. `try-faves-stage-warm-interior` and `try-faves-stage-photo-studio`
  are now only the environment picker's thumbnails.
- `try-faves-figure` (the Vision-derived cutout) is unused by the current
  flat-photograph path. Delete it and the stage plates if the picker stops
  needing thumbnails — together they are roughly 400 KB against a budget with
  about 1 MB of headroom.
- `TryFavesEnvironment.swift` owns the locations. They are prompt-driven: the
  environment is baked into each generation, so every look is one flat
  photograph of the person in that place. Changing it therefore affects new
  shoots only — which is why Try on configuration commits with **Update look**
  and calls `TryFavesLookService.regenerate(_:)` rather than applying live.
  The seed look is a bundled photograph with no pipeline behind it, so
  regenerating it shoots its outfit as a *new* look instead of overwriting the
  one photograph every shopper starts from.
- `TryFavesStageColors.swift` samples the top and bottom edges of the look on
  screen. The canvas under the frame uses the exact ground tone so the lift
  leaves no step; the header and panel fades use a lightly darkened version,
  because a fade tinted with the colour it sits on is invisible and white type
  over bare photography has nothing holding it. A fixed grey cannot serve a
  warm interior and a mountaintop at once. Weight lives in two knobs —
  `scrimDarkening` and the tint stops in `TryFavesEdgeFade` — both kept clear
  of the material blur, which sets the softness independently.
- The panel and its fade are pinned to the stage *above* the pager. Below it,
  the photograph simply covered the fade; inside the pager, rubber-banding
  dragged the panel away from the header. Only the photograph swipes.
- `TryFavesConfigurationSheet.swift` is the settings sheet beside
  **Create a look**: personal avatar (flow still ahead), environment, and a
  free-text appearance note. The note rides the posture pass and is part of
  the render cache key. Its button carries a one-time discovery dot.
- `tryFavesGlass(in:)` in `TryFavesStyle.swift` is the world's only floating
  surface: the design's `IconButton/Blurred` and `Sheet` are the same
  material. Header buttons, the status chip, and both sheet plates go through
  it, so a sheet reads as the same stuff as the button that opened it. One
  thing to know: the tint must sit *on* the glass, not behind it —
  underneath, the bright material washes it out. It runs at
  `bg-overlay-fixed-dark-20`, a step above the design's value — Liquid Glass
  carries most of the separation, but 10% left white type short of the
  brighter parts of the stage photography.
- `TryFavesSheet.swift` holds the plate, scrim, section, and button the New
  look and Try on configuration sheets share. Both are **overlays on the
  world page, not presentations**: a cover slides the whole stage, and the
  stage has to stay fixed. The plate fades and rises `sheetRise`; the scrim
  behind it only fades. They are two separate `.overlay` calls on purpose —
  as children of one inserted container, only the container's transition
  runs and the plate's rise is silently dropped.
- The sheet backdrop is `BackdropBlurView` (in `VariableBlurView.swift`),
  which blurs what is *behind* it. SwiftUI's `.blur()` on the stage collapses
  that subtree's safe area, which shifted the whole look up ~15pt in a single
  frame, outside any animation transaction, so it could not even be smoothed.
- Sheets dismiss by tapping the scrim, by Close, or by swiping the plate down
  past `sheetDismissDistance` or with a flick past `sheetDismissFlick`.
  There is deliberately no grabber; the design's Sheet component has one but
  hides it in these frames.
- The look panel is a fixed block (`TryFavesStyle.panelHeight`, composed from
  its parts). Panel content legitimately varies — the seed look has no
  overflow menu, a shoes-only look has one tile — and a hugging panel made
  the headline and garments jump on every swipe and delete. The title row,
  the rail, and each tile's meta block are all pinned.
- `TryFavesProductTile.swift` is the only product tile in the experience.
  Home passes a price capsule, the look panel a favourite heart plus
  merchant/product/price meta, the composer a selection check. The well,
  radius, hairline, and shadow are identical everywhere, so entering the
  world is a zoom into the same design rather than a different one.
- `TryFavesStyle.swift` owns the shared stage, chrome, tile, and sheet
  tokens for the Home card and the world alike.

Dev shortcuts: `-openTryFavesWorld`, `-openTryFavesComposer`,
`-openTryFavesConfiguration`, `-generateTryFavesLook`,
`-deleteLastTryFavesLook`. `-TryFavesEnvironment photoStudio` also works,
since the stage is a plain `UserDefaults` value.

### Holiday banner variant

Tap the buyer avatar and use **Holiday banner** to choose:

- Off
- Header
- Feed card

`HomePage.SeasonalPlacement` is persisted through `seasonalPlacement`. The
legacy `holidayHeaderEnabled` value is migrated on first use.

`SeasonalSavingsSurface` owns the shared campaign image, copy, and CTA so the
header and card cannot visually drift. `HolidayFeedCard` adds real buyer
products in a horizontally snapping rail. The rail uses shared feed clearance
tokens and interpolates its inset during takeover, keeping complete product
tiles above the bottom navigation in both compact and snapped states.

## Data boundaries

- Buyer feeds and utility items come from the existing personalized catalog.
- Merchant cards only render when a canonical merchant identity, bundled
  wordmark, and verified lifestyle cover are available.
- Shop Posts are exposed through `ShopPostService.posts(for:)`; curated post
  availability is currently implemented for Luke only.
- The holiday CTA is intentionally a prototype hook until the campaign has a
  canonical collection destination. Product tiles route to real PDPs.

## Verification

Simulator:

- Device ID: `9FBE811F-24D3-4F33-B361-96B027B108D1` (iPhone 17 Pro; the older
  `286EAAB0-C6BC-41CB-A40C-B84318D400D8` is no longer available locally)
- Bundle ID: `com.shopify.purl.prototype.shop.feed.summer.26`

Build:

```sh
xcodebuild -project ShopFeedSummer26.xcodeproj \
  -scheme ShopFeedSummer26 \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=9FBE811F-24D3-4F33-B361-96B027B108D1' \
  -derivedDataPath /tmp/shop-feed-derived build
```

New Swift files need `xcodegen generate` before they reach the target.

The clean simulator build, personalized-feed validation, product-budget
validation, and `git diff --check` pass. The debug app product is approximately
`184048 KB` against the enforced `184320 KB` budget, so bundle headroom remains
very narrow. Existing unrelated Swift concurrency warnings may remain.

Driving the simulator for visual checks: the device screen is the first
`group` of the Simulator window, so its on-screen rect comes from
`System Events`, not from the window frame (the window includes chrome and
bezel, and guessing the inset misses 36pt controls by ~30pt).

## Design intent

- Keep Shop UI direct, restrained, native, and media-led.
- Preserve shared geometry across buyers; do not add per-buyer layout forks.
- Use lifestyle media for feed covers and merchant-owned assets for merchant
  cards.
- Keep editorial titles heavy with controlled multiline leading.
- Avoid bounce or content reflow in the vertical snap interaction.
- Top-level tabs move horizontally; content drill-ins use shared-view depth.
