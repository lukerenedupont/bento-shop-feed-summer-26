# Generative Shop Feed — steerable feel test

## Question

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
| 0 | Complete a jacket purchase | Jacket stays fixed; swap between two real Feature pants |
| 1 | Compare a chair shortlist | Focus a chair to see its photo, exact name, merchant, category and price; removal is secondary |
| 2 | Explore Standards Manual | Merchant-led NYCTA, NASA and EPA manual grouping; browse the books |
| 3 | Continue a living room | Saved Sofita table + chair choice; selection carries into and back from the room plan |
| 4 | Narrow a coffee journey | Choose **At the counter** or **Out the door**; the card's copy and inventory change in place |
| 5 | Discover furniture merchants | Forom, House of Leon and Lichen are the primary entities; choosing one retains its identity and exact inventory |

The coffee directions are hard content gates: commute shows the Carter Move Mug, not a coffee maker. Counter shows the Aiden and Stagg kettle, not the travel mug. Change direction to return to the two choices. There is no default-biased extra CTA beneath the two choices.

The merchant card's **Graphic standards** grouping is editorial, not a claimed official collection or unverified new launch. The room plan is a local continuity sketch—not AR, spatial fit validation or integration with the full persistent World runtime.

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
- `Components/GenerativeDiscoveryComposition.swift`: direction and merchant-first compositions.
- `Components/GenerativeFeedInspector.swift`: single-card inspection and editing.
- `Components/GenerativePrototypeTools.swift`: stable setup/feed-editor presentation above lazy cells.
- `Components/NextGenerationFeedGallery.swift`: direct review of the same plan.

State is in memory only. It survives scrolling, card regeneration and local room-plan presentation—not app restarts. No authenticated account mutations or purchases occur.

## Catalog media

Eighteen exact product images are bundled in `ShopFeedSummer26/PrototypeCardMedia/`. `SOURCES.json` records merchant/product IDs, canonical image URLs and SHA-256 hashes. A failed image never substitutes another product or a merchant cover.

```sh
python3 Scripts/prepare_generative_demo_media.py --check
```

Preparing media requires Pillow. The previous scaffold refreshed two dead Feature URLs from the exact official product endpoints without changing prices, titles or destinations:

- https://feature.com/products/nike-nike-x-stussy-reversible-varsity-jacket-medium-olive-bright-mandarin.js
- https://feature.com/products/nike-nike-x-stussy-stone-washed-fleece-pant-black.js

## Verification

Simulator acceptance coverage includes six card bounds/actions, focus/removal/reset, swap/composition state retention, room-plan continuity, direction relevance across regeneration, merchant/inventory coupling, supported signal/job changes, consumer disclosure, empty-feed recovery, reordering and real-shell scrolling/taps.

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
