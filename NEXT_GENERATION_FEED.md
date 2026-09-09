# Generative Shop Feed — twenty-card review

## Current prototype

Twenty authored commerce scenes demonstrate possible generative output using 52 canonical products from 17 merchants. This is **not a live AI generator**. `main` is the confirmed native visual and flick-and-stick reference; all work stays on `feed-interactive-cards`.

Eighteen cards use official storefront wordmarks, reusing `MerchantWordmarkImage` and the audited `MerchantWordmarks/manifest.json` assets. Ceremonia and Lalo were added through the existing sync script. Standards Manual remains unchanged and Babyletto uses plain attribution. Product-led scenes prioritize a larger lead image; Feature now shows one large selectable shoe rather than three tiny rows. Fitted photographs preserve complete products, with captions positioned against their actual image height.

Product-led cards now have soft, photography-informed color washes rather than uniformly white surfaces. The image area extends to 8pt side margins; text and controls retain 20pt clearance. Studio images keep a neutral surrounding center and are never tinted to match the wash. These are art-direction choices, not claims about official merchant brand colors.

The approved Graphic standards card is preserved. The rejected outfit/chair treatments are outside the default sequence. The new cards still require human visual approval; twenty is a coverage target, not a quality certificate.

```sh
./Scripts/run_generative_feed.sh feed 0
./Scripts/run_generative_feed.sh gallery 2   # Approved books
./Scripts/run_generative_feed.sh consumer 0
python3 Scripts/prepare_editorial_feed.py --check
```

Indices are `0...19`. `PrototypeCardMedia/EDITORIAL_PLANS.json` holds shopping purposes, canonical references, bounded image placements, headline anchors and trusted palette/interaction choices. `EditorialFeedCatalog.swift` validates and resolves them; `EditorialCommerceFeedCard.swift` composes native scenes rather than supplying twenty separate hard-coded views. Existing Shop typography, navigation and transitions remain shared.

Photographic stories keep the photographed product as their anchor and open related products directly. Selectable product scenes couple their photo, title, price and destination to session selection. Other interactions include horizontal footwear browsing and a canonical book cover/interior reveal. Plans are authored; regeneration only revalidates them. Inventory and prices are frozen catalog data, not a live availability check.

The media script bundles 62 canonical gallery images, trims pale studio margins with recorded crop rectangles, and preserves source URLs and derivative hashes in `EDITORIAL_SOURCES.json`. The earlier nineteen images remain. No generated product imagery, invented reviews, measurements or account history are used.

`EditorialFeedUITests` exercises the twenty-card native scrolling sequence and representative identity/selection handoffs. Full legacy regression and physical-device QA remain separate pending work. Review in the actual feed, including neighboring cards; gallery screenshots alone cannot establish quality.

## Historical six-job scaffold

The remainder records the previous experiment, available via `-legacyGenerativeJobs`. Its six-item indices and earlier validation results do not describe the current default.

### Original question

Can a shopping job produce the right small experience—and can we change its inputs, composition and state at the pace of a design discussion?

This is a **six-experience deterministic prototype**, not a live AI recommender. It evolves the four-card scaffold (`cd20f57`), replacing the earlier decorative layout gallery (`f5cb6ab`). Work stays on `feed-interactive-cards`; `main` is untouched.

## Run

```sh
./Scripts/run_generative_feed.sh feed 4      # Request coffee card in the real Shop shell
./Scripts/run_generative_feed.sh gallery 0   # Direct six-card review
./Scripts/run_generative_feed.sh consumer 4  # Setup disclosure → clean consumer preview
```

All modes use the dedicated **Feed Interactive Cards** Simulator. No desktop mouse injection. Gallery and Home use the same specifications, frozen merchant snapshot and session implementation. Use gallery for exact-index review; inherited native feed deep-link snapping can initially land on the neighboring slot.

Normal app launch starts with the utility belt. Only Luke's For You uses the demo plan. Other buyers, authored topics and custom feeds keep their previous planning path.

## Six experiences

| Index | Shopping job | Behavior |
|---|---|---|
| 0 | Complete a jacket purchase | Purchased jacket at the top; swipeable pants carousel underneath; Buy pants opens the selected SKU's actual merchant page |
| 1 | Compare a chair shortlist | Two candidates remain visible, with canonical finishes and a calculated price difference; bring in the third while retaining the focused chair |
| 2 | Explore Standards Manual | Merchant-led NYCTA, NASA and EPA manual grouping; browse the books |
| 3 | Continue a living room | Compact saved-table context + large square chair carousel; swiped selection carries into and back from the room plan |
| 4 | Narrow a coffee journey | Choose **At the counter** or **Out the door**; the card's copy and inventory change in place |
| 5 | Discover furniture merchants | Forom, House of Leon and Lichen are the primary entities; choosing one retains its identity and exact inventory |

The coffee directions are hard content gates: commute shows the Carter Move Mug, not a coffee maker. Counter shows the Aiden and Stagg kettle, not the travel mug. Change direction to return to the two choices. There is no default-biased extra CTA beneath the two choices.

The merchant card's **Graphic standards** grouping is editorial, not a claimed official collection or unverified new launch. The room plan is a local continuity sketch—not AR, spatial fit validation or integration with the full persistent World runtime.

## Editorial visual direction

The user approved the Standards Manual treatment: existing heavy topic typography, a paper-toned surface, and large overlapping crops of the real book covers. `GenerativeEditorialMerchantCard.swift` replaces its thumbnail picker and Next book CTA with cover selection and a canonical product-detail handoff.

The next fast pass applies that language to the outfit and chair comparison, not yet the remaining three jobs. Outfit retains the purchased jacket at the top, swipeable pants and actual Buy pants destination, with a heavy Wear it with heading and tighter studio-margin crops. Comparison uses a heavy Down to these two heading, staggered photography with inline finishes/prices, and a quiet focus check. Additional candidates now live in More/Shortlist options rather than a third product row. Source photography and shopping state remain canonical; no product parts are intentionally cropped. Build/media checks pass. Full UI regression and feed-geometry checks are deferred until visual review, per the user's request for speed.

## First-card design pass

Following the screenshot review, the jacket now leads as compact purchased-item context, above **Wear it with** and a horizontally snapping pants carousel with a next-item peek. The selected pants' name, price, save state and **Buy pants** destination stay coupled during paging. Buy pants opens the actual merchant SKU page; it does not place an order or simulate checkout. **Saved looks** remains secondary and retains the exact pair after swiping/regenerating. The Hero alternate retains the same products and selection through thumbnail choices.

Comparison now shows two chairs together rather than one hero image at a time. Tap to focus one, then **Also on your shortlist** to replace the other candidate. Same-currency price differences are calculated from the catalog with decimal arithmetic; names and finishes are split only at the canonical title separator. Saving is distinct from focus and shortlist removal. Removal lives in the shortlist overflow menu.

**View chair**, garment taps and the saved-look review open an exact catalog detail sheet with an actual merchant PDP link. No dimensions, stock, reviews, sizes or checkout are invented. The first cards reserve real bottom layout space—including extra clearance for the utility-to-first-card takeover—rather than visually offsetting their buttons.

A subsequent room-card pass replaces the short, letterboxed image strip and separate thumbnail row with a nearly full-width square carousel. A single compact saved-table header replaces the stacked heading/subtitle/context blocks. The entire source photograph is fitted into a square allocation (about 333pt on the review phone), so the chair is much larger without cropping it. Name, price and Review room plan remain below the hero, and both card and sheet share selection.

These are local session saves and a small product handoff, **not** account mutations, a full Wardrobe World or persistent favorites. Merchant/discovery experiences are unchanged. The authenticated Quick site remains unavailable to this environment; this is a design interpretation of the supplied written brief, not a claimed reference match.

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
- `Components/GenerativeFeedInspector.swift`: single-card inspection and editing.
- `Components/GenerativePrototypeTools.swift`: stable setup/feed-editor presentation above lazy cells.
- `Components/NextGenerationFeedGallery.swift`: direct review of the same plan.

State is in memory only. It survives scrolling, card regeneration and local room-plan presentation—not app restarts. No authenticated account mutations or purchases occur.

## Catalog media

Nineteen exact product images are bundled in `ShopFeedSummer26/PrototypeCardMedia/`. `SOURCES.json` records merchant/product IDs, canonical image URLs and SHA-256 hashes. A failed image never substitutes another product or a merchant cover. One additional House of Leon image is the same black chair's official studio photograph, selected from its canonical gallery for comparison. Its original lifestyle lead remains unchanged elsewhere.

```sh
python3 Scripts/prepare_generative_demo_media.py --check
```

Preparing media requires Pillow. The previous scaffold refreshed two dead Feature URLs from the exact official product endpoints without changing prices, titles or destinations:

- https://feature.com/products/nike-nike-x-stussy-reversible-varsity-jacket-medium-olive-bright-mandarin.js
- https://feature.com/products/nike-nike-x-stussy-stone-washed-fleece-pant-black.js

## Verification

The room revision passes three focused checks: at least 300pt of hero image in the real consumer feed, reachable navigation/actions and swiped-selection continuity; room-sheet changes returning to the carousel; all six card bounds/actions. The preceding first-card pass passed all fifteen Simulator tests. The carousel revision updates the affected checks to swipe rather than tap a swap CTA and checks that the purchase URL follows the selected pants. Coverage includes saved-pair identity after swapping/regeneration, comparison focus/price calculation, canonical destination URLs, consumer-mode feed geometry and actions, six-card bounds, shortlist reset, same-data alternatives, room continuity, direction relevance, merchant coupling, signal/job changes, empty-feed recovery and reordering.

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
