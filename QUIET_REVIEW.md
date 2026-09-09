# Quiet shopping feed — morning review

> Historical structural pass. The current Dossier-led version is documented in [DOSSIER_REVIEW.md](DOSSIER_REVIEW.md). Use `./Scripts/run_quiet_review.sh structural 0` to open this earlier five-card version.

A first functional pass on **SEE → TOUCH → RESPOND → GO DEEPER**, built on the existing generative feed, not a replacement application.

## Open it

```sh
cd /Users/lukedupont/bento-shop-feed-review
./Scripts/run_quiet_review.sh feed          # Real Shop home feed, consumer preview
./Scripts/run_quiet_review.sh gallery 0     # Exact-index review, same renderer/session
./Scripts/run_quiet_review.sh design 3      # Room card with inspector controls
```

Simulator: **Shop Quiet Feed Review**, iPhone 17 Pro / iOS 26.5.
UUID: `9D696736-11E8-447A-A09D-8F63738786C5`.
Branch: `review/quiet-shopping-grammar`.
The original `feed-interactive-cards` checkout and `main` simulator clone are untouched.

The inherited Home deep-link/snap behavior can initially land one card beyond the requested index. Swipe down to the previous card, or use `gallery` for deterministic index selection. Ordinary vertical flicks navigate the feed. Long-press a heading for the existing inspector; its Feed action opens ordering/toggles.

## Walkthrough

1. **Style this tee** — fixed BODE tee illustration; swipe or focus pants. Metadata appears after interaction. View look carries the chosen pair into a local review; save or change pants there and return to the same selection.
2. **Still considering these?** — three sofas without initial metadata. Tap two, then Compare. Prices/materials are catalog-backed; unknown dimensions are deliberately omitted. Change selection or open the exact shortlist.
3. **Salomon at Extra Butter** — authentic existing campaign imagery with a product pager; focus reveals product details/save. Visit Extra Butter opens the existing merchant destination. This is not claimed to be a new release or a dynamically synchronized campaign.
4. **Works with your sofa** — sofa stays fixed; tap the chair or table and select an alternative. View room shares those exact choices. See in room reuses the existing Spatial prototype, one selected object at a time.
5. **Pick a direction** — Classic versus A little weird. Selection gates the assortment, with Change direction to reverse it. Keep exploring opens the existing Canvas using only the selected group's products. Selection/removal returns to the feed; product details are presented over the Canvas rather than routed invisibly behind its sheet.

All shopper signals and recommendation sets are authored. No model calls, purchases, account writes, or new image/video generation happen while using these cards. State is in memory and survives scrolling and local navigation, not app termination.

## Asset pipeline

`Scripts/prepare_quiet_review.py` imports the supplied Dossier export and exact public merchant records. `Scripts/prepare_review_cutouts.swift` uses Apple's foreground mask to crop furniture/pants without regenerating product pixels.

```sh
uv run --with pillow python Scripts/prepare_quiet_review.py /path/to/dossier-export
python3 Scripts/validate_quiet_review.py
```

If the machine's configured package registry is unavailable, use:

```sh
env -u UV_INDEX -u UV_INDEX_URL -u UV_DEFAULT_INDEX uv run --no-config \
  --index https://pypi.org/simple --with pillow python Scripts/prepare_quiet_review.py /path/to/dossier-export
```

- `ReviewSources/` preserves the export metadata, catalog image provenance/hashes, and explicit global-ID mappings. This folder does not ship in the app.
- `QuietReviewMedia/` contains 22 catalog products and 25 selected/compressed images, plus the catalog JSON. The Dossier's videos are not bundled in this first pass.
- The BODE and Carhartt global IDs are mapped to exact merchant product IDs. The export's Converse and Kith pairings remain explicitly unresolved; no invented mappings.
- The tee flat-lay is a **generated styling illustration**, identified in its accessibility hint and inspector. Tapping it opens the original merchant photograph. It is not a generated photo of the shopper.
- The generated look inside View look is labelled as styling inspiration, not a rendering of the selected outfit.
- Product details use canonical records; generated prose is not used as commerce evidence.
- Existing prototype JPGs were reduced to 560px / quality 72, with updated hashes, to retain the existing 184320 KB app limit. Original checkout assets remain untouched.

## What was reused

- `NextGenerationFeedCardSpec`, `NextGenerationFeedCardCatalog`, fixture/plan seam, and `GenerativeFeedPrototypeSession`.
- `NextGenerationFeedCardView` and the existing Home/gallery hosts, native Shop fonts and controls, inspector, ordering, and setup disclosure.
- Exact product review and merchant navigation.
- Canvas and Spatial destinations; each receives only an optional product-opening callback for use in a sheet. Default existing behavior is unchanged.

Review-specific presentation lives in `QuietShoppingCardPrototype.swift`; local handoffs live in `QuietShoppingJourneyPrototype.swift`. `QuietFeedReviewCatalog.swift` owns the five fixed scenarios. `-legacyGenerativeFeed` restores the original six-scenario selection for a launch.

## Deliberate limits

- Existing full-height snap slots remain. Small/medium/large outer card heights and automatic feed rhythm are not implemented.
- The room is a three-object composition sketch: sofa, chair, side table. No lamp/rug slot or physically accurate scene.
- The outfit handoff is a local pair review, not full Wardrobe/Try Faves integration. No automatic try-on rendering.
- Core feed imagery is bundled. Existing merchant/Canvas/spatial destinations retain their normal network/device requirements; Canvas may repeat its finite assortment.
- Camera placement remains the existing explicit visual prototype, not scale/fit validation or multi-object AR.
- Contextual “cheaper / more minimal” refinement in every card, durable cross-World state, live recommendation generation, and all seven Worlds are follow-up work.
- Current authored regeneration preserves the fixed review scenarios. It is not represented as live intelligent reranking.

## Verification

- Xcode simulator build passes; app budget **183996 KB / 184320 KB** at the last build.
- `validate_quiet_review.py`: 22 products, 25 asset hashes/provenance, 2 exact Dossier mappings.
- Existing personalized-feed validation and 35-image provenance validation pass; `git diff --check` passes.
- Simulator walkthrough verified: pants pan changes selection; outfit save reflects back on card; two explicit sofa selections precede comparison; room swap appears in room review; direction filters Canvas to its three matching products; returning retains the direction.
- Gallery navigation environment issue caught on launch and fixed by sharing the existing navigation coordinator/route stack.
- This is a targeted simulator smoke check, **not a run of the full inherited UI test suite**. Physical-device AR/live try-on were not tested.
