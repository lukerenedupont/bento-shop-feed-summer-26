# Next Generation Feed — 20 composition-tree cards

## Current connected demo

The same twenty cards now support a connected room comparison/return path, a Salomon-to-outfit continuation with actual selected-product imagery, and book inspect/keep/resume. Kept selections and relevant choices persist on this device, with a demo-scoped reset. See [UNIFIED_DEMO.md](UNIFIED_DEMO.md) for the walkthrough, implementation seams and verification.

Run `./Scripts/run_unified_demo.sh room` (or `footwear`, `books`) to open the native feed. No parallel feed or second twenty-card catalog was added. Two continuation recipes live beside the cards in the existing authoring source.

## Schema-2 cleanup (preceding pass)

`Packages/ShopCompositionCore` now owns the UI-independent, typed tree contract and field-specific validation. Layout, product presentation, media fit/playback, and card action/disclosure are separate choices; overloaded node `mode` strings are removed. The app and command-line checker use the same core. See the package README for its interface and checks.

`CompositionContext` resolves canonical product bindings into lookup tables when constructed, shared by its descendants. Swaps use those bindings rather than repeating catalog searches for each product node. Session mutation and hosted state tests remain in the app; they have not been moved into the core.

Authoring is one-way: edit `Scripts/build_next_generation_20.py`, run `--write-spec`, then `--check-spec`. Both flags avoid media generation/downloads; checks also avoid writes. They use the existing frozen catalog inputs, including the sibling dossier bundle. `run_next_generation_20.sh` rejects source/bundle drift before building.

```sh
python3 Scripts/build_next_generation_20.py --write-spec
./Scripts/check_composition_contract.sh [--simulator <booted UDID>]
```

At the end of the initial cleanup, ten CLI contract regressions passed against the actual Swift core via the Simulator runtime. Native macOS CLI execution was blocked by machine security policy; no policy was weakened. The first hosted attempt timed out after package resolution. The later unified-demo pass successfully ran twelve hosted model tests and five UI tests; see `UNIFIED_DEMO.md`. Full twenty-card visual approval remains separate.

This establishes a scalable contract, not a production feed of thousands: backend-backed state, paged payload delivery, async generation, measured media-cache limits and broad device coverage remain follow-up work.

## The design direction

**AI generates a shopping composition, not executable UI.** The output is a tree of native capabilities: product stages, media, weighted rows/columns, choices, comparisons, steps, grids, paging, merchant identity, and a product canvas. Twenty cards do not require twenty renderer cases.

The shared Shop chrome stays consistent: the existing flick-and-stick feed, lower-third editorial typography, native product cards, a single primary CTA, an overflow menu, and appropriate light/dark contrast. Brand differentiation comes from the products, merchant media, palette, visual hierarchy, and shopping job—not invented fonts, badges, or generic generated copy.

The video inspected as the likely quality reference was `~/Downloads/feeds-with-device.MP4` (52.5 seconds). No separately attached video was visible in the request.

## Run

```sh
cd /Users/lukedupont/bento-shop-feed-review
./Scripts/run_next_generation_20.sh feed
./Scripts/run_next_generation_20.sh gallery 9    # Exact-index Salomon direction card
./Scripts/run_next_generation_20.sh design 14    # Standards Manual canvas
```

Review simulator: **Shop Quiet Feed Review**, iPhone 17 Pro / iOS 26.5, UUID `9D696736-11E8-447A-A09D-8F63738786C5`.

The native Home deep-link can initially settle on a neighboring snap slot; ordinary flick navigation works. Gallery gives deterministic index selection. The original project checkout and main simulator remain untouched. Use `run_quiet_review.sh` to return to the previous Dossier treatment.

## The twenty cards

| Index | Experience | Layout / useful interaction |
|---|---|---|
| 0 | Valley of Flowers jacket | Cinematic control case, native product cards; long-press pants for real swap options |
| 1 | MESO woven room | Full-width room study with three companion slots and retained lamp anchor |
| 2 | Nike Vomero kit | Immersive styling study and four product tiles; independent pants swap |
| 3 | BODE combination | Asymmetric outfit assembly with a supporting styling photograph |
| 4 | Vintage Rolex | Paged detail study and exact source-product inspection |
| 5 | For Leon | Recipient-scoped gift composition and explicit keep action |
| 6 | Hat Trick NYC | Brand-led storefront moment with a native merchant handoff |
| 7 | Toddler Nike outfit | Tall lifestyle image beside a three-piece outfit column |
| 8 | Teenage Engineering | Modular studio board using the corrected source device image |
| 9 | Salomon directions | City/trail visual choice reconstructs a hard-gated assortment |
| 10 | House of Leon shortlist | Two explicit selections reveal a useful comparison |
| 11 | Fellow setup | Brewing steps change the selected product/stage in place |
| 12 | KINTO pouring study | Material close-ups alongside real glassware/pouring products |
| 13 | Ceremonia routine | A browsable routine with separate scalp/cleanse/finish/dry roles |
| 14 | Standards Manual library | The existing native fisheye canvas, backed by twenty real books |
| 15 | Coming Soon mirrors | Stacked visual directions, then a selected mirror study |
| 16 | FOROM corner | Room vignette and an independently changeable table |
| 17 | MoMA objects | Strong color, asymmetric media/product placement, merchant handoff |
| 18 | Nocs field kit | Field context, two optics, and supporting equipment |
| 19 | Lichen discovery | Large Storage photograph and stacked Seating/Objects choices with hard assortment gates |

## What is actually generated

`NextGeneration20/ng20-compositions.json` contains **20 distinct agent-authored composition trees**, using 12 primitive kinds and 86 catalog product references. Two direction cards also have intentionally exposed alternate compositions. These are reviewed model-output fixtures produced during this work—not a connected live model service.

The spec is semantic and bounded. Example tree fragment (the envelope supplies entity bindings):

```json
{
  "id": "example.root",
  "kind": "column",
  "weights": [2, 3],
  "children": [
    {"id": "example.anchor", "kind": "product", "role": "anchor"},
    {
      "id": "example.support",
      "kind": "row",
      "children": [
        {"id": "example.pants", "kind": "product", "role": "pants", "alternatives": ["pants", "denim", "cord"]},
        {"id": "example.layer", "kind": "product", "role": "layer"}
      ]
    }
  ]
}
```

The model cannot supply fonts, radii, pixel coordinates, arbitrary colors, or executable SwiftUI. Artwork binds to a specific merchant/product reference in a trusted asset registry. Group choices cannot leak unrelated inventory into their responses.

## How this scales to hundreds or thousands

1. **Retrieve before composing.** Give the model allowed merchant/product IDs, supported media, shopper/job context, native capabilities, and existing journey state.
2. **Generate candidate trees.** Vary hierarchy, object relationships, approved palette, and interaction—not merely a template ID or a background video.
3. **Validate commerce and structure.** Reject invented IDs, wrong image subjects, unsupported actions, excessive depth, and invalid layout weights. Keep the previous good card on a failed live generation.
4. **Render and assess visual quality.** Schema validity alone is insufficient. Check phone-sized previews for hierarchy, legibility, tap sizes, cropping, repetition, and misleading generated imagery. Rank candidates and reject weak ones before publishing.
5. **Generate ahead of the scroll.** Cache validated cards; never wait for a model during a flick. Interaction updates structured state and can request a new candidate asynchronously.
6. **Keep journey state separate.** A new layout should not forget a comparison, chosen direction, saved composition, or selected product. Persist this state with the relevant World in a production integration.

A new card inside the grammar requires a new specification, not new renderer code. A genuinely new capability may require a new native primitive. The current payload cap is 100 cards per batch, not a limit on the total design space.

## Code seams

- `Models/GeneratedComposition.swift`: model-output types, themes, role bindings, and catalog adapter.
- `Models/CompositionValidation.swift`: fail-closed structural and artwork/identity checks.
- `Components/GeneratedCompositionCard.swift`: shared Shop chrome, actions, and exact-selection review.
- `Components/CompositionNodeView.swift`: recursive native renderer; no switch on merchant/card ID.
- `GenerativeFeedPrototypeSession`: shared swaps, comparisons, directions, paging, canvas position, and saved snapshots.
- Existing `ProductCard`, `GenerativeProductReview`, `NavigationCoordinator`, `FisheyeCanvas`, and `SpatialARWorldDestination` are reused. Room reviews can enter the existing one-object Spatial prototype.

## Verification and corrections

- All twenty default cards were captured and reviewed together through multiple visual passes.
- Corrected an asset-alias collision that substituted the Gabb phone image for the gift organizer. Product artwork now carries an identity binding checked against the entity.
- Replaced missing/stale CDN media only by refreshing the **same canonical product ID** from its merchant endpoint.
- Source product images are fitted; foreground masks remove backgrounds without generating new product pixels. Supplied generated imagery remains explicitly styling inspiration.
- Removed weak mechanically transposed layouts rather than calling every schema-valid variation polished.
- Focus information has reserved space so swaps do not resize the anchor and surrounding layout.
- Seven hosted model tests pass: twenty inventory-resolved specs, hard group gating, state retention across recomposition, independent swaps, immutable saved snapshots, explicit comparison selection, pagination/reset, and rejection of misbound artwork.

```sh
python3 Scripts/validate_next_generation_20.py
xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
  -destination 'platform=iOS Simulator,id=<test-simulator>' \
  -derivedDataPath /tmp/shop-composition-tests-derived \
  -parallel-testing-enabled NO -only-testing:CompositionEngineTests \
  COMPOSITION_TEST_HOST=YES test
```

Use separate DerivedData for hosted tests: Xcode injects Apple XCTest frameworks into the host. The explicit test-host flag excludes only those instrumented runtimes from the app-only budget. The normal review build retains the unchanged **184320 KB total-app gate**.

## Limits to be clear about

- No live model endpoint, live inventory refresh, account mutation, or production checkout was added.
- NG20 choices and exact kept selections are device-local demo state. Other prototype sessions can remain ephemeral; backend persistence and durable cross-World learning are not implemented.
- Export prices without currency metadata remain withheld rather than silently treated as USD. Merchant/source URLs are not guessed.
- Spatial remains a one-object visual prototype, not multi-object placement or fit validation. Physical-device AR was not tested.
- Generated scenes are not exact renders of changed selections or photographs of the buyer. Product details preserve source photography.
