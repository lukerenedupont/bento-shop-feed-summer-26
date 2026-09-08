# Generative Shop Feed — first feel test

## Question

Does a signal-driven shopping job feel more useful than another product recommendation, within the existing Shop feed?

This is a four-experience **prototype**, not a live AI recommender. It replaces the earlier twenty-layout experiment on `feed-interactive-cards`. That earlier version remains in git at `f5cb6ab`; `main` is untouched.

## Run

```sh
./Scripts/run_generative_feed.sh           # Real feed shell, first card
./Scripts/run_generative_feed.sh gallery 0 # Direct four-card review
./Scripts/run_generative_feed.sh feed 3    # Room continuation in the feed
```

These build/install on the dedicated **Feed Interactive Cards** Simulator. No desktop mouse injection. The gallery uses the exact same specifications, catalog records and renderer as Home, without instantiating another feed behind it.

Normal app launch still starts with the utility belt. Luke's For You contains the four demo experiences; other buyers, custom feeds and authored topics retain the existing planning path.

## Try these

1. **With the jacket you bought** — an authentic Nike × Stüssy jacket stays fixed; **Swap pants** cycles through two actual Feature products.
2. **Still considering these chairs?** — three House of Leon chairs with equal image allocation, canonical names and prices. Remove candidates or reset the shortlist.
3. **Standards Manual** — merchant-led book discovery. Select a book or use **Next book**. No unverified new-launch or purchase claims.
4. **A chair for your living room** — the saved Sofita table anchors the next decision. Select a chair and **Review room plan**. Changing selection in that sheet updates the same feed card.

The room plan is a **local continuity sketch**, not AR, a fit assessment, or an integration with the full persistent World engine.

## Direct the prototype

Tap the sliders beside **Demo context**, or long-press the heading:

- Inspect the signal, job, rationale, anchor, catalog candidates and World identifier.
- Switch between the recommended composition and **Hero**, keeping data and selection unchanged.
- Turn interactions off/on.
- Hide/show the inspector buttons.
- Inspect local state or reset one card.

Gallery arrows move between the four jobs. Selections survive scrolling and gallery navigation for the current session; they do not persist across app restarts or mutate real buyer data.

## Data and honesty

**Purchases, views, affinity and World activity are explicitly simulated.** They are not inferred from Luke's real account. Product and merchant records are authentic.

- `GenerativeFeedPrototypeFixtures.swift` declares four activity signals, not layouts.
- `NextGenerationFeedCardCatalog.cards(signals:merchants:)` determines the shopping job, retrieves matching entities, then emits a semantic specification.
- The specification contains the signal, job, anchor/candidates, copy, primary interaction, default/alternate compositions, context ID and rationale. It cannot supply arbitrary fonts, colors, coordinates, radii or animations.
- `GenerativeFeedStyle` and the native renderer own the visual mappings.
- `GenerativeFeedPrototypeSession` owns selection, removed candidates, composition overrides and interaction enablement above lazy feed cells.

This is a small deterministic slice. General job ranking, adjacent-card art direction, arbitrary signal editing, regeneration with AI, profile switching inside the inspector and production World handoff are **not implemented**.

## Media

Eleven exact product images are bundled in `ShopFeedSummer26/PrototypeCardMedia/`, with catalog IDs, canonical URLs and SHA-256 hashes in `SOURCES.json`.

Two dead Feature lead-image URLs were refreshed from these official product endpoints; product IDs, titles, prices and destinations were not changed:

- https://feature.com/products/nike-nike-x-stussy-reversible-varsity-jacket-medium-olive-bright-mandarin.js
- https://feature.com/products/nike-nike-x-stussy-stone-washed-fleece-pant-black.js

Validate offline with:

```sh
python3 Scripts/prepare_generative_demo_media.py --check
```

Preparing new images uses Pillow: `python3 Scripts/prepare_generative_demo_media.py`. Images fit their allocated region. A failed image never substitutes a different product or merchant cover.

## Verification

`PrototypeUITests/GenerativeFeedPrototypeUITests.swift` covers:

- Four bounded headings and reachable gallery actions.
- Swapping and composition changes retaining selection.
- Shortlist removal/reset.
- Room-plan selection returning to the card.
- Real feed-shell CTA reachability.
- Scrolling away/back retaining state.

```sh
xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
  -destination 'platform=iOS Simulator,id=A2AA7E39-93E3-47FE-8599-B523E3358700' \
  -derivedDataPath /tmp/pi-feed-interactive-cards-derived \
  -parallel-testing-enabled NO test
```

Feed controls reserve real layout space above floating navigation; visual-only offsets were not reliable hit targets. The bottom nav host is bounded to the pill region rather than a full-screen interaction shape.

The original **184320 KB** app gate is unchanged. The existing branch exclusion of legacy `Media/` films remains; full destinations are not the acceptance surface for this slice.

## Next discussion

Judge the relationship card, comparison density, merchant identity and room continuity before adding more scenarios. Choose the default versus Hero hierarchy using the inspector. The next implementation should respond to those observations rather than expand the number of decorative variants.
