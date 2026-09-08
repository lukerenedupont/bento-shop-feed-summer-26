# Generative Shop Feed — steerable feel test

## Question

Can a shopping job produce the right small experience—and can we change its inputs, composition and state at the pace of a design discussion?

This is a **six-experience deterministic prototype**, not a live AI recommender. It evolves the four-card scaffold (`cd20f57`), replacing the earlier decorative layout gallery (`f5cb6ab`). Work stays on `feed-interactive-cards`; `main` is untouched.

## Run

```sh
./Scripts/run_generative_feed.sh feed 4      # Request coffee card in the real Shop shell
./Scripts/run_generative_feed.sh gallery 0   # Direct six-card review
./Scripts/run_generative_feed.sh consumer 4  # Setup disclosure → clean consumer preview
./Scripts/run_generative_feed.sh canvas      # Standards Manual's optional fisheye composition
```

All modes use the dedicated **Feed Interactive Cards** Simulator. No desktop mouse injection. Gallery and Home use the same specifications, frozen merchant snapshot and session implementation. Use gallery for exact-index review; inherited native feed deep-link snapping can initially land on the neighboring slot.

Normal app launch starts with the utility belt. Only Luke's For You uses the demo plan. Other buyers, authored topics and custom feeds keep their previous planning path.

## Six experiences

| Index | Shopping job | Behavior |
|---|---|---|
| 0 | Complete a jacket purchase | Purchased jacket at the top; swipeable pants carousel underneath; Buy pants opens the selected SKU's actual merchant page |
| 1 | Compare a chair shortlist | Two candidates remain visible, with canonical finishes and a calculated price difference; bring in the third while retaining the focused chair |
| 2 | Explore Standards Manual | Twenty canonical catalog items, browsable as a merchant shelf, Hero or an optional two-dimensional fisheye canvas |
| 3 | Continue a living room | Compact saved-table context + large square chair carousel; swiped selection carries into and back from the room plan |
| 4 | Narrow a coffee journey | Choose **At the counter** or **Out the door**; the card's copy and inventory change in place |
| 5 | Discover furniture merchants | Forom, House of Leon and Lichen are the primary entities; choosing one retains its identity and exact inventory |

The coffee directions are hard content gates: commute shows the Carter Move Mug, not a coffee maker. Counter shows the Aiden and Stagg kettle, not the travel mug. Change direction to return to the two choices. There is no default-biased extra CTA beneath the two choices.

The merchant card's **From the bookshelf** grouping is editorial, not a claimed official collection or unverified new launch. The room plan is a local continuity sketch—not AR, spatial fit validation or integration with the full persistent World runtime.

## First-card design pass

Following the screenshot review, the jacket now leads as compact purchased-item context, above **Wear it with** and a horizontally snapping pants carousel with a next-item peek. The selected pants' name, price, save state and **Buy pants** destination stay coupled during paging. Buy pants opens the actual merchant SKU page; it does not place an order or simulate checkout. **Saved looks** remains secondary and retains the exact pair after swiping/regenerating. The Hero alternate retains the same products and selection through thumbnail choices.

Comparison now shows two chairs together rather than one hero image at a time. Tap to focus one, then **Also on your shortlist** to replace the other candidate. Same-currency price differences are calculated from the catalog with decimal arithmetic; names and finishes are split only at the canonical title separator. Saving is distinct from focus and shortlist removal. Removal lives in the shortlist overflow menu.

**View chair**, garment taps and the saved-look review open an exact catalog detail sheet with an actual merchant PDP link. No dimensions, stock, reviews, sizes or checkout are invented. The first cards reserve real bottom layout space—including extra clearance for the utility-to-first-card takeover—rather than visually offsetting their buttons.

A subsequent room-card pass replaces the short, letterboxed image strip and separate thumbnail row with a nearly full-width square carousel. A single compact saved-table header replaces the stacked heading/subtitle/context blocks. The entire source photograph is fitted into a square allocation (about 333pt on the review phone), so the chair is much larger without cropping it. Name, price and Review room plan remain below the hero, and both card and sheet share selection.

These are local session saves and a small product handoff, **not** account mutations, a full Wardrobe World or persistent favorites. Coffee directions and multi-merchant discovery are unchanged. The authenticated Quick site remains unavailable to this environment; this is a design interpretation of the supplied written brief, not a claimed reference match.

## Extracted fisheye canvas

`Packages/ShopFisheyeCanvas` is a standalone, dependency-free SwiftUI library extracted from `shopify-playground/shop-week-baskets` at `16f2078037ee6325bb5dc2a5246919a09c7aee8e`. It retains the procedural grid, radial scaling/3D tilt and velocity-driven release spring from `AddProductsView.swift`. Basket generation, product models, loading, selection UI and the unused drawing Canvas/timer are not imported. The package README records provenance, API and differences.

Standards Manual is the first adapter: a familiar merchant's visual assortment suits exploration better than a focused chair comparison. All three compositions share its twenty real catalog items and selected product. The infinite grid repeats this finite assortment; it does not invent products. Thirty-five exact images now cover all six experiences, including the full library.

Tap **Explore library** for two-dimensional pan. While exploring, pan takes priority over tile buttons so dragging never selects a product. **Done exploring** returns vertical swipes to the feed; the outer gutter can scroll the feed even while exploring. Leaving a card exits exploration but retains pan position and selection. Tapping a product focuses it, and its name/price row opens the existing canonical product review and merchant destination. Reduced Motion uses a flat grid and direct pan without the spring.

The package owns geometry and gesture mechanics; `GenerativeFisheyeComposition.swift` owns Shop media, selection and product review. Session state above lazy cells retains position across regeneration and composition changes. The existing full Canvas World engine is untouched.

## Consumer and design modes

Before consumer preview, a setup sheet explains that the activity is simulated and nothing changes the real account. Consumer cards contain no demo band or inspector buttons. Long-press a heading to enter the inspector; this is a hidden prototype entry point.

In design mode, heading sliders open the inspector:

- **Signal**: for the chair scenario, switch repeated views ↔ saved shortlist.
- **Shopping job**: compare ↔ resume for supported shortlist signals.
- **Why this card?**: inspect provenance and selection rationale.
- **Composition**: default ↔ Hero where both retain the meaning of the job. Direction and merchant-group cards intentionally do not offer misleading product-only alternates.
- Toggle local interactions, inspect state or reset one card.
- **Regenerate this card** in the bottom toolbar repeats catalog retrieval with current inputs.
- **Feed** in the top toolbar opens the stable feed-level editor.

The feed editor can enable/disable any of the six source signals, reorder them using drag handles, show all signals, regenerate the feed or switch to consumer preview. Removing the currently inspected card or disabling every signal does not destroy the editor; an empty feed retains an **Edit demo feed** recovery action.

Regeneration is deterministic, not an AI request. It reruns retrieval and modestly rotates relevant candidate order without introducing unrelated products. Valid selected/dismissed products and chosen directions remain intact. A chosen product may therefore remain visually unchanged after regeneration. Composition-only changes never swap data.

## Implementation seams

- `Models/NextGenerationFeedCard.swift`: source signals, supported jobs, primary entity types, content groupings and semantic specifications. No arbitrary visual values.
- `SampleData/GenerativeFeedPrototypeFixtures.swift`: explicitly simulated activity plus canonical reference groups.
- `SampleData/NextGenerationFeedCardCatalog.swift`: signal → job → entity retrieval → validated composition spec.
- `Models/GenerativeFeedPrototypeSession.swift`: signal/job overrides, revisions, state, direction/merchant filtering, feed visibility and order.
- `Components/NextGenerationFeedCardView.swift`: native renderer, shared geometry and existing shopping compositions.
- `Components/GenerativeDecisionCompositions.swift`: anchored outfit and simultaneous chair comparison.
- `Components/GenerativeShoppingReview.swift`: exact saved pairs and catalog-backed product/merchant handoff.
- `Components/GenerativeDiscoveryComposition.swift`: direction and merchant-first compositions.
- `Packages/ShopFisheyeCanvas`: reusable SwiftUI grid/projection/pan engine.
- `Components/GenerativeFisheyeComposition.swift`: catalog-backed feed adapter for that engine.
- `Components/GenerativeFeedInspector.swift`: single-card inspection and editing.
- `Components/GenerativePrototypeTools.swift`: stable setup/feed-editor presentation above lazy cells.
- `Components/NextGenerationFeedGallery.swift`: direct review of the same plan.

State is in memory only. It survives scrolling, card regeneration and local room-plan presentation—not app restarts. No authenticated account mutations or purchases occur.

## Catalog media

Thirty-five exact product images are bundled in `ShopFeedSummer26/PrototypeCardMedia/`. `SOURCES.json` records merchant/product IDs, canonical image URLs and SHA-256 hashes. A failed image never substitutes another product or a merchant cover. One additional House of Leon image is the same black chair's official studio photograph, selected from its canonical gallery for comparison. Its original lifestyle lead remains unchanged elsewhere.

```sh
python3 Scripts/prepare_generative_demo_media.py --check
```

Preparing media requires Pillow. The previous scaffold refreshed two dead Feature URLs from the exact official product endpoints without changing prices, titles or destinations:

- https://feature.com/products/nike-nike-x-stussy-reversible-varsity-jacket-medium-olive-bright-mandarin.js
- https://feature.com/products/nike-nike-x-stussy-stone-washed-fleece-pant-black.js

## Verification

The full eighteen-test Simulator suite covers both canvas behaviors and all sixteen existing card checks. Canvas checks verify real tile movement without accidental selection, canonical product selection/review, retained geometry across regeneration and composition changes, passive feed scrolling, active exploration, outside-gutter escape and exploration reset when leaving the card. Existing coverage includes room hero size, swiped pants purchase-URL coupling, saved-pair identity, comparison focus/prices, consumer navigation clearance, six-card bounds, shortlist reset, room continuity, direction relevance, merchant coupling, signal/job changes, empty-feed recovery and reordering. This validation used a temporary QA Simulator. The command below targets the persistent review Simulator.

```sh
xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
  -destination 'platform=iOS Simulator,id=A2AA7E39-93E3-47FE-8599-B523E3358700' \
  -derivedDataPath /tmp/pi-feed-interactive-cards-derived \
  -parallel-testing-enabled NO test
```

The original **184320 KB** app gate is unchanged. Legacy `Media/` films remain excluded from this branch's target, as before. Feed controls reserve actual layout space above floating navigation rather than moving only their drawn appearance.

## Not built yet

- General model-generated plans or automatic job/adjacency ranking.
- Arbitrary signal/job combinations; the editor only offers supported scenarios.
- Shopping Profile editing, replenishment, seasonal cases or a 10–12-case feed.
- Full World runtime handoff, AR, real checkout or persisted account state.
- Variable outer snap heights. Current variation is inside the proven full-height shell.

Next decisions should come from comparing the six experiences together, particularly the focused chair comparison, the binary direction refinement and the merchant-led hierarchy.
