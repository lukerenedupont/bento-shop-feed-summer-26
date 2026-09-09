# Codex handoff

## Targeted review-checkout fix — 2026-09-08

The user explicitly authorized fixing the Lichen screenshot in `/Users/lukedupont/bento-shop-feed-review` on `review/quiet-shopping-grammar`. This checkout has substantial unrelated uncommitted work; preserve it. The upstream branch notes below are historical, not this checkout's current branch identity.

- Vomero follow-up: `ng20-vomero-kit` now uses its existing outdoor styling study as a full-card backdrop, with four equally sized shoe/pants/jacket/socks tiles. Root `mode: study` provides a quiet action and a persistent styling-study label (image unchanged after interaction). Original pants alternatives and all four review roles remain intact. Generator and bundled composition updated; no new imagery. Build/schema checks pass at 172364 KB; logs `/tmp/vomero-layout-final-build.log`, screenshot `/tmp/vomero-layout-after.png` (before shortening the study label). Gallery index 2 is open on Next Generation QA. No new interaction-test run.
- Follow-up: `ng20-woven-room` / Around this lamp now has a full-width room scene above three equal companion slots (chair/rug/table), with a quiet room-review action. The scene retains `role: anchor`, so the lamp stays in the review without a redundant cutout. Chair alternatives are unchanged; swapping still does not regenerate the styling image. Generator and bundled composition both updated. Build/provenance validation passed at 172496 KB; screenshot `/tmp/woven-room-layout-after.png`. Inspected gallery index 1 on Next Generation QA; no fresh interaction-test run.
- Lichen now uses a `featured` choice axis: large Storage photograph, two stacked Seating/Objects photographs, and the existing category gates. Its root opts into `mode: editorial` for a quiet merchant-link CTA. Other cards retain their existing layout/action styles.
- Both `Scripts/build_next_generation_20.py` and the Lichen entry in `NextGeneration20/ng20-compositions.json` reflect the change. No new imagery or inventory was added.
- Normal Simulator build and composition validation passed; app 172344 / 184320 KB. Inspected the actual rendered gallery at index 19 on Next Generation QA (`3F187DB4-1903-4F9D-A567-9779113B8229`); screenshot `/tmp/lichen-layout-after.png`.
- Added a focused category-gating regression in `CompositionTests/CompositionEngineTests.swift`. Its test build was blocked by the original app-size gate (190980 KB test host), so it has NOT executed. The normal build was rerun successfully afterward. Logs: `/tmp/lichen-layout-test.log`, `/tmp/lichen-layout-final-build.log`.
- Changes remain uncommitted in this review checkout; no branch switch, merge or push was performed.

Updated: 2026-09-08

## Repository state

- Repository: `/Users/lukedupont/bento-shop-feed-summer-26`
- Branch: `feed-interactive-cards`
- Handoff remote: `public` (`lukerenedupont/bento-shop-feed-summer-26`)
- The branch starts from `5936382`; do not merge it into or push it over `main` without explicit instruction.

## Next Generation Feed branch

- The current feel test has six signal-driven shopping experiences in Luke's For You. It evolves the four-card scaffold (`cd20f57`); the twenty decorative layouts remain archived at `f5cb6ab`. Other buyers/topics/custom feeds use the pre-existing planner.
- `GenerativeFeedPrototypeFixtures.swift` declares explicitly simulated purchase, repeated-view, merchant-affinity and active-World signals. Do not present these as real account history.
- `SampleData/NextGenerationFeedCardCatalog.swift` owns signal → supported job → retrieval → semantic spec. Its `prototypeMerchants` snapshot is shared by Home, gallery and inspector, avoiding merged/live inventory changing the fixture. `Models/NextGenerationFeedCard.swift` defines primary entity types, groupings and supported inputs; it does not supply arbitrary visual values.
- Six experiences: jacket + swipeable pants; focused chair comparison; Standards Manual's twenty-item editorial assortment; saved table + chair; coffee counter/commute directions; Forom/House of Leon/Lichen discovery. The new group-led compositions intentionally do not offer misleading product-only Hero alternates.
- `NextGenerationFeedCardView.swift` is the shared renderer; `GenerativeDiscoveryComposition.swift` owns direction and merchant-led compositions. The first two cards now use `GenerativeDecisionCompositions.swift`: a fixed jacket with changeable pants, and two simultaneously visible chair candidates. Bounded media cannot expand the feed. Thirty-five exact images are bundled with provenance; the extra black-chair studio image is from that same SKU's canonical gallery.
- `Packages/ShopFisheyeCanvas` extracts only the procedural grid, fisheye projection and release spring from `shopify-playground/shop-week-baskets` at `16f2078037ee6325bb5dc2a5246919a09c7aee8e`. It is an iOS 18+ Swift package with no dependencies, basket code, inventory or image loader. The package README records provenance/API; upstream had no license file. The full Canvas World engine is untouched.
- Standards Manual has an optional Fisheye canvas composition via `GenerativeFisheyeComposition.swift`. Merchant/Hero/canvas share twenty canonical products and selection. Explore library enables two-dimensional pan; Done exploring restores normal feed scrolling. The outside gutter remains scrollable even while exploring. Leaving the card exits exploration but retains position and selection. Pan has priority over tile buttons to prevent accidental selection during a drag. The product row opens canonical details/PDP.
- `GenerativeFeedPrototypeSession` owns selected/dismissed products, canvas position/exploration state, chosen direction/merchant, supported signal/job overrides, revisions, enabled signals and order. Group choice is a hard relevance gate. Regeneration repeats retrieval and deterministic reranking while retaining valid state; no model API is called.
- Screenshot-directed follow-up: the outfit card now places the purchased jacket at the top, then Wear it with and a horizontal pants carousel with a next-item peek. Buy pants opens the selected pants' canonical merchant page. Media, title, price, save state and purchase URL follow the same selection. Saved looks remains secondary; Hero retains thumbnail choices. Header long-press has priority over its product tap so consumer-mode inspection still works.
- Room-card polish: a compact saved-table header now precedes a large square chair carousel, replacing the letterboxed strip and separate thumbnail row. Exact photography remains fitted and uncropped. Paging carries the selected chair into and out of the room-plan sheet. The room card now shares the refined header/footer clearance used by the first two jobs.
- First-card polish adds exact saved outfit pairs, comparison focus, same-currency decimal price deltas, a third-candidate swap that retains the focused chair, and secondary shortlist removal. `GenerativeShoppingReview.swift` provides saved-look review and exact product details with canonical merchant PDP links. Saves remain local/session-only; this is not a full Wardrobe World or authenticated favorites.
- Consumer preview starts with a disclosure of simulated activity, then hides demo/debug chrome. Sliders in design mode—or a long press on a consumer heading—open `GenerativeFeedInspector`. The chair scenario supports repeated-view/saved signals and compare/resume jobs. Other scenarios offer only valid inputs.
- Inspector toolbars keep Regenerate this card and Feed always reachable. `GenerativePrototypeTools` hosts a stable feed editor with signal switches, drag-handle reordering, regenerate-all and consumer preview. Disabling every card retains an Edit demo feed recovery control.
- Run `./Scripts/run_generative_feed.sh [feed|gallery|consumer|canvas] [0...5]`. `canvas` opens the Standards Manual fisheye alternate directly; `-fisheyeCanvas` is its optional gallery launch flag. Existing launch flags remain. The gallery uses stable card identity across reordering and the same session/renderer as Home. Use gallery for exact-index review: the inherited native feed deep-link can initially settle on a neighboring snap slot; ordinary swipe navigation is verified.
- Room-plan sheet and feed still share session state. Full persistent World integration/AR, general AI generation, automatic adjacency ranking, arbitrary inputs, profile editing and the full 10–12-case feed remain unbuilt; see `NEXT_GENERATION_FEED.md`.
- Full eighteen-test acceptance includes all accumulated carousel/room changes and two canvas checks. Canvas coverage asserts actual tile movement without selection, retained tile geometry across regeneration/recomposition, canonical selection/review, passive feed scrolling, active exploration, gutter escape and exploration reset on leaving. See `/tmp/generative-fisheye-final-suite.log`. Validation uses a temporary QA Simulator, not the user's review Simulator.
- Bottom navigation has bounded hit geometry. The outfit, comparison, room and optional fisheye treatments use shared header/foreground tokens and reserve actual bottom layout space, with additional clearance for whichever entry occupies the first-card takeover slot. Other generated cards retain their previous layout. Visual offsets are not substitutes for reachable controls.
- Legacy `Media/` films remain excluded from this branch target, not deleted. The original `184320 KB` gate is unchanged; this build is approximately `182696 KB`; `HomePage.swift` is 1809 lines against its unchanged 1900-line limit.
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
