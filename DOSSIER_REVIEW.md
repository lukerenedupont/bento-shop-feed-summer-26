# Dossier-led feed review

## Latest screenshot-directed changes

- **Jacket (index 0):** full-card image/video background, the existing Shop `ProductCard` list treatment in a horizontally snapping carousel, and a centered **View the look** CTA anchored above navigation. No beige footer panel, loose object strip, helper text, or CTA arrow. Tapping a product opens its exact details; the CTA retains the shared look review.
- **Vomero (index 2):** separate one-card bento experiment. A full-width shoe anchor sits above a pants compartment and stacked jacket/sock compartments, following the existing bento grammar. No poster, duplicate rail, or resting-state CTA. Tap Swap pants to browse three genuinely different pants inside that same compartment; the other objects stay fixed. Details and View look appear after interaction.
- Removed arrow glyphs from the other review-feed primary CTAs without changing those cards' layouts.
- Verified the jacket carousel pans to the next product and its CTA opens the composition. Verified the Vomero inline pager changes pants and updates the selected product without leaving the card.

The remaining sections describe the shared Dossier pass; these two treatments override its generic presentation.

This is the visual revision following the five-card structural pass. It reuses the existing feed planner, semantic specs, native renderer host, session, inspector, gallery, product review, and Spatial destination.

## Open

```sh
cd /Users/lukedupont/bento-shop-feed-review
./Scripts/run_quiet_review.sh feed
./Scripts/run_quiet_review.sh gallery 1       # Lamp, exact-index review
./Scripts/run_quiet_review.sh design 8        # Optional studio setup
./Scripts/run_quiet_review.sh structural 0    # Previous five-card version
```

**Simulator: Shop Quiet Feed Review** — `9D696736-11E8-447A-A09D-8F63738786C5`.
The original checkout and the Bento main simulator are unchanged. No changes are pushed.

The inherited Home deep-link can settle one snap slot past the requested card. A normal downward flick returns to the previous card; gallery is deterministic.

## The nine supplied dossiers

| Source index | Content | Default feed |
|---|---|---|
| 0 | Valley of Flowers jacket | Yes |
| 1 | MESO woven lamp | Yes |
| 2 | Nike Vomero | Yes |
| 3 | Rolex Oyster Perpetual Date | Yes |
| 4 | Tin Can / For Leon | Yes |
| 5 | Hat Trick NYC | Yes |
| 6 | BODE tee | Optional |
| 7 | Toddler Air Max outfit | Optional |
| 8 | Teenage Engineering setup | Optional |

All nine are available through the existing inspector → Feed → signal toggles. Launching an optional source index in gallery/design enables that source for the review. The duplicate toddler ZIP path was imported only once.

## Interaction

- **Rest:** readable full-scene imagery, separate tappable product objects, restrained context and one deeper action. Swipe the scene for another study. The macro-heavy supplied films mostly live on the next scene page rather than obscuring the initial composition; the watch can lead with film.
- **Touch:** tap an outfit or room object to switch the stage to independently rendered objects. Both large objects and their compact row are tappable.
- **Respond:** focus pants, a chair, or a table and use Swap. The anchor and other choices remain fixed. A swapped card shows its actual selected objects, never a stale photograph claiming to be the changed result.
- **Return to imagery:** View original study returns to the original media without forgetting selections. Once swapped, the scene is explicitly marked Original styling study.
- **Go deeper:** View look / Review room shares the exact current selection. Saving snapshots the whole list of selected object IDs, so later swaps do not rewrite earlier saved compositions. Room review can enter the existing one-object Spatial prototype.
- **Gift:** Keep for Leon saves the phone locally and opens the local gift review. This does not mutate an account or pretend to be a complete gifting-World integration.
- **Merchant / watch:** source product detail and session save, not invented variants or compatibility.

## Data and media safeguards

- Raw exports are extracted under ignored `.build/dossier-imports/`; originals remain unchanged in Downloads. Contact sheets are under `.build/dossier-contact-sheets/`.
- `ReviewSources/DossierLibrary/` preserves original source documents, global-ID → local-surrogate mappings, and asset hashes. It is not bundled.
- `DossierReviewMedia/` contains the compressed runtime media and catalog. Generated object backgrounds were removed into transparent PNGs rather than multiplying beige image rectangles over beige surfaces.
- Imported global IDs receive explicit stable local numeric surrogates. These are not claimed to be canonical merchant IDs. Existing verified catalog alternatives retain their actual IDs.
- Export amounts have no currency metadata; the imported details say Check merchant for price instead of silently treating every number as USD. Only source-provided primary product links are offered. Related objects without an exact link do not get a guessed one.
- Tin Can's alternative smartphone and Wi-Fi access point are excluded from its shoppable group. Only the phone and organizer are retained; its lead image avoids implying that a router or another phone is required.
- The Teenage Engineering export mixes model names and its generated object0 depicts K.O. II instead of the green source device. The standalone visual is replaced with the original source photograph. Its title/price are not treated as independently verified.
- Toddler content is optional and never receives the adult-pants alternatives used by the adult outfit cards. Sizes/fit still require merchant verification.
- Generated scenes are inspiration, not photographs of the buyer or exact renders of a changed selection. This is disclosed in setup, accessibility hints, the inspector, and the deeper review.

## Implementation and validation

- `DossierReviewLibrary.swift`: exported media/data → existing semantic card spec.
- `DossierShoppingCardPrototype.swift`: scene/focus/composition presentation within `NextGenerationFeedCardView`.
- `DossierSelectionReview.swift`: exact selection review and existing Spatial handoff.
- `GenerativeFeedPrototypeSession`: scene index, object mode, slot selections, and saved composition snapshots.
- `Scripts/import_dossier_review.py`: reproducible media preparation using Pillow, ffmpeg, Swift/Vision, and pngquant.
- `Scripts/validate_dossier_library.py`: nine unique dossiers, six defaults, 31 product mappings, object assets, provenance hashes, and excluded gift pairings.

The older frozen bento bundle is still included, with all 287 media files. Its optimization now uses 1000px PNG/JPEG targets and 480p clips; source assets are unchanged. New Dossier hero stills are 960px, object cutouts up to 560px, and clips 540p/24fps. The original 184320 KB app-size gate is unchanged.

Simulator smoke checks cover product focus, switching to object mode, pants and chair swaps, exact handoff into reviews, and saved-composition state. The full inherited UI test suite and physical-device AR were not run. State remains session-only. The full-height native feed slots remain; variable outer card scales and live recommendation generation are not part of this pass.
