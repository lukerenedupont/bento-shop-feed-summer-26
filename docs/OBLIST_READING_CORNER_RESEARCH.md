# Oblist reading-corner World — sourcing and first implementation

User-selected collection: https://oblist.com/collections/mid-century-modern-living-room

## Proposed direction

Build a budgeted, editable reading-corner set using The Oblist's actual products. Reuse the existing World shell, feed transition, native product/merchant destinations and Julian dock. A product collage is a composition, not proof of physical fit. A later “See it in your room” action must distinguish visualization from dimensionally accurate placement.

The original $600 constraint is unresolved: do not replace it silently or publish an under-budget claim for this assortment.

## First-party observations — September 24, 2026

The collection's product endpoint (`/collections/mid-century-modern-living-room/products.json?limit=250`) provided product IDs, descriptions, variants, imagery and availability. Each shortlisted product page was checked separately. The pages reported `Shopify.currency.active = USD`, corroborating the prices below, and the corresponding structured offers reported `https://schema.org/InStock`. This is an observation, not a checkout/delivery guarantee. Prices are storefront-provided; no agent currency conversion was performed.

| Role | Product | Observed USD price | Source |
| --- | --- | ---: | --- |
| Chair | Sedia Tonda Armchair | $1,514 | https://oblist.com/products/594146-sedia-tonda |
| Side table | Cubo Side Table | $990 | https://oblist.com/products/635658-cubo |
| Floor light | Floor Lamp # 1 | $1,390 | https://oblist.com/products/floor-lamp-1 |
| Alternate table | Figure Side Table 04 · Walnut | $1,048 | https://oblist.com/products/633555-figure-side-table-4 |
| Alternate chair | Small Palma Chair | $978 | https://oblist.com/products/161659-small-palma |
| Alternate light | Plaster Table Lamp Bien Faite Taupe | $447 | https://oblist.com/products/la-lampe-bien-faite-taupe |

Chair + side table + floor light: **$3,894 item subtotal**, before tax/shipping. A $4,000 budget would leave $106 at the item-subtotal level only. Replacing the floor lamp with the table lamp yields **$2,951**, before tax/shipping; the table lamp uses table surface, so this is a layout trade-off rather than an equivalent replacement.

### Source-supported design distinctions

- Sedia Tonda: natural-pigment-stained birch plywood; flat-pack, tool-free assembly, per the product description. Do not label it oak or upholstered, or infer reading comfort.
- Cubo: natural-pigment-stained birch plywood; adjustable height from 32 to 55 cm, per the product description. Provides a coherent material direction with the chair; physical clearance remains unverified.
- Floor Lamp # 1: brushed stainless steel, stated dimensions 1400 × 350 mm, E27 bulb compatibility. Warm output depends on bulb selection; do not claim a supplied warm bulb or proven task-light performance.
- Bien Faite Taupe: recycled paper, vegetable flour and Paris plaster; 26.5 × 21.1 × 13 cm; LED G9 bulb not included. The listing's shipping statement is specific to metropolitan France, not evidence of US delivery speed.

## Living-room media selection

The collection JSON (`/collections/mid-century-modern-living-room.json`) identifies its image as:
https://cdn.shopify.com/s/files/1/0671/5290/4457/collections/Capture_d_ecran_2024-02-08_a_15.14.35.png?v=1726065948

Visually reviewed against the room-edit alternatives: warm paneled rooms, dark sculptural seats and a low wood table. The same photograph is now the feed cover and shared World hero. It is labelled **living-room inspiration**, not a photograph of the selected products. A 600px-bounded JPEG is bundled under `catalog/reading-corner/living-room.jpg`; provenance and checksum live in `reading-corner.json`. Source image resolution is limited; this is not a newly rendered room. Public availability does not grant production reuse rights.

## First implemented slice — September 24, 2026

- Story `library-edit-oblist-reading-corner`, second in For You after Norda, also in Living. Launch with `Scripts/run_library_preview.sh reading-corner`.
- Three-piece starting set, with chair and light swaps; the sheet quotes the resulting set subtotal and delta before selection. Small Palma changes the original set to **$3,358**, a **$536 reduction**.
- Original **$600** request and default item budget remain unchanged. The feed and World explicitly show the overage. Only a shopper action changes the item budget; the sent request remains immutable.
- Six first-party observations from `Scripts/import_reading_corner.py`: each validates the confirmed Shopify merchant (`gid://shopify/Shop/67152904457`), active USD page, JSON currency, available Ajax variant, matching price and selected-variant image. No FX calculation. Supplements use the existing catalog/search/PDP/merchant/Ask graph; `snapshot.json` is unchanged.
- Local selection and budget persist together and update the feed summary. Hearts are separate local saves. Selected product photos now use their recorded native aspect ratios in full-width cards, rather than letterboxed squares.
- “See it in your room” opens a **photo moodboard**, carrying the same selected set and subtotal. The system photo picker supplies an optional local image; draggable rectangular product photos keep their original backgrounds. Not AR, 3D, an exact-set render, or a dimensional fit check. The photo and tile positions are session-only; no upload or generation service.
- Sources and rights details are available on demand. The refinement action opens an unsent Ask draft containing the current selected set and budget.

Validation: 51 XCTest cases (3 skipped), 27 Swift Testing cases, and three focused UI journeys passed: Oblist feed → World → native PDP → back; swap → persisted selection → room moodboard; existing Norda buying-advice draft. Source validators and 11 existing Python importer tests passed. New importer exercised live; no new Python importer unit test suite. Photo-library selection, actual image dragging, light-swap UI and budget-menu UI have not been automated. No new full UI-suite guarantee.

Shipping build: **184,228 / 184,320 KB**, 92 KB headroom, 44,760 KB feed, 968 media files and 6 fonts. Existing RCOUT, Warm Designer Lighting and BFCM clips were re-encoded (content retained) to fit the unchanged cap.

## Richer editorial pass — September 24, 2026

User feedback: more visual/product breadth, visible Oblist/shop identities, request near the top, usable set controls, and a more compelling room invitation.

Composition now follows: shorter shared hero → original request → Oblist identity and role selectors → full-width selected product with attached swap footer → compact subtotal/budget and contextual refinement action → visual room-moodboard invitation → three style directions with products → category grid → shop logo rail → existing related World cards.

- Layout regression reproduced the actual issue: 166pt product media on a 402pt screen, and the light-swap right edge at 480.7pt. Source-matched portrait framing removes introduced white bars without cutting off the object. Chair/table/light selectors replace the horizontally clipped primary controls. Regression now checks card width, source aspect ratio, request ordering, light-control bounds, and opening the light-swap sheet.
- Six available Oblist observations. Figure Side Table 04 in Walnut is the new table alternative, making the set $3,952 if selected. Its source photograph shows two tables; no two-for-one claim. Shear Side Table 01 was excluded because Ajax reported no available variant. The refresh aborts rather than publishing unavailable products.
- `ReadingCornerDiscovery.swift` defines three editorial directions, four categories, four verified merchant links and three existing related Worlds. Its 14 unique product references join the canonical catalog and World context. Global publication is now **238 products / 83 merchants**; base snapshot unchanged.
- **Warm & collected** uses FRAMA Easy Chair 01’s source gallery context image (index 2); **Soft & sculptural** uses Audo Brasilia’s source gallery room image (index 1); **Quiet contrasts** uses FRAMA Rivet’s source gallery image (index 2). Images were downloaded and visually reviewed; URLs stay remote, already recorded in the immutable catalog. Room scenes guide the mood, not exact variant/set matching. The Brasilia discovery thumbnail explicitly selects the dark-oak Bouclé 02 source image matching the recorded price variant instead of the legacy mixed-finish lead image. The existing native PDP gallery is not rewritten by this pass.
- Categories open the existing native assortment sheet. Shop links are The Oblist, FRAMA, Audo and Ferm Living. Copy says “Shops with a point of view,” not an unsupported trending/popularity ranking. Related cards reuse the shared World-card component for lighting, books and furniture.
- Discovery is separate from selected-set editing: changing a visual direction does not silently replace selected products or the $600 budget. Budget refinement opens an unsent contextual Ask draft, not a research job or a promise of a sourced $600 set.

Latest validation: **53 XCTest cases (3 skipped), 27 Swift Testing cases** passed. All five focused UI journeys passed across the final runs: full-width/role/swap regression; styles/category sheet; persisted chair swap/room carryover; feed/native PDP return; Norda unsent advice. The breadth test needed a navigation-bar-scoped Close selector to avoid the underlying World’s Close control; its focused rerun passed. No fresh full UI-suite guarantee. Photo picker/dragging remains outside automated coverage.

Latest shipping app: **184,248 / 184,320 KB**, **72 KB headroom**, 44,760 KB feed, 968 media files, 6 fonts. BFCM Holiday Header, Senvoler and House of Errors clips were additionally re-encoded to 360px/24fps; content and existing routes remain. No new bundled lifestyle assets in this pass.

## Swipe stacks, compact feed and floating roles — September 24, 2026

This pass supersedes the card/footer/swap-sheet interaction described above.

- The selected front card is the choice. Native page-style stacks cycle through **five chairs, two tables and two lights**, changing only their role. White title/price sit directly over the photograph; no heart, separate footer or Swap button. Tap the front card for its canonical PDP. Whole-set subtotal, feed preview and room moodboard follow persisted selections.
- Added available, source-observed chair variants: Melides **$3,726**, Vaga **$3,807**, and “Buoys” **$2,887**. Exact variant URLs, source timestamps, images and made-to-order/comfort caveats are in the supplement and sources sheet. Buoys is an experimental direction, not a tested reading-comfort recommendation. Several unavailable candidates were rejected. Publication now totals **241 products / 83 verified Shopify merchants**, with **nine Oblist observations** and **17 unique references** in the World. Base snapshot unchanged.
- Feed preview: three equal square photographs span the content width, with the Oblist wordmark and selected item subtotal. Removed the feed over-budget sentence at the user's request. The immutable original $600 request, explicit higher-budget framing, adjustable budget and overage remain inside the World; no under-budget or delivered-price claim.
- Make it yours: original native vector illustrations of a wooden chair, side table and floor lamp float without tile backgrounds above their labels. These are category controls, not generated photographs or exact representations of selected variants. The active role has a lime underline; changing roles does not change the selected set. `ReadingCornerRoleArtwork.swift` adds no bundled media or image-generation dependency.
- Gesture regression exposed reverse custom drags also triggering native Back. A scroll-position implementation then exhibited offscreen/stale targets after vertical scrolling. Final `ReadingCornerDeck` uses native page-style `TabView`, duplicate end pages for wrapping and a single selection binding. This avoids custom gesture arbitration and scroll-offset inference.

Verification: **54 XCTest cases (three skipped), 27 Swift Testing cases** passed in the model run. Final focused UI run passed all three journeys: all role controls + vertical scrolling + both light swipe directions and subtotal; all five chair choices + wrap + persistence + same-set room board; updated feed → World → native PDP → return. The earlier combined run had UI failures documented above, corrected in the final focused rerun. This is not a fresh full UI-suite pass. Photo picking/dragging and budget-menu UI still need manual review.

Final shipping build: **184,244 / 184,320 KB**, **76 KB headroom**; feed **44,768 KB**, 968 media files, six fonts. No new media re-encoding was needed in this pass.

## Actual product cutouts and physical manipulation — September 24, 2026

The shopper rejected the vector illustrations and carousel. This pass replaces both; it supersedes the immediately preceding interaction description.

- Nine actual merchant photographs were background-removed with Apple's Vision foreground-instance masking, visually reviewed, trimmed and packaged as transparent WebP cutouts bounded to 480px. No furniture geometry was generated. The selected handle drives both the role control and room composition. Gallery alternatives avoid extra objects: Cubo index 4 (collapsed configuration, no books), Figure index 4 (one table), Melides index 2 and Vaga index 2. Other pieces use their reviewed lead images. Source URLs, source image IDs, processing parameters and checksums are in `catalog/reading-corner/cutouts/provenance.json`; extraction utility: `Scripts/extract_product_foreground.swift`. Production media rights remain unresolved.
- A physical pile replaces TabView. `ReadingCornerGrabSurface` provides immediate horizontal manipulation, or a 0.16-second lift for free-direction motion. The card follows both axes, tilts and throws away on a meaningful release; a short drag springs home. Left/up advances, right/down goes back, wrapping within the same role. Taps keep canonical PDP navigation, and VoiceOver adjustment remains available. The page still scrolls on ordinary vertical swipes; there is no visible instruction caption.
- The exact regression went red: a held upward throw left the card unchanged and scrolled the page from y=88 to y=-66.7. UIKit gesture priority alone proved insufficient in a later combined run. `WorldDragOwnership` now temporarily locks the enclosing World/sheet scroll during manipulation. `TopicScrollBehavior` extracts the existing margins/bounce policy, keeping `TopicDetailPage` at 1,198 lines. Final focused up/down and horizontal/page-scroll checks passed.
- The shopper explicitly approved a **$3,000 working budget**. The original $600 message remains history; a current-budget response is shown beneath it. A one-time migration updates the old $600 default without changing selected products, customized budgets or later explicit changes. The initial set is still $3,894; there is no under-budget claim. Visible tax/currency/overage helper lines are removed, with price scope preserved in Sources and contextual Ask drafts.
- The room invitation is a single tappable card with actual selected cutouts, two angled walls, a floor plane, rug and separate object placements. The same scene becomes editable inside the sheet; cutouts drag independently, with accessible movement actions. A table lamp is positioned near the tabletop rather than treated like a floor lamp. An optional local photo can replace the illustrative room. No image upload, AR, dimensions, occlusion inference or generated installation is provided. Capability/privacy details are in Info, not on the invitation.
- Removed the extra moodboard link, photo-collage/not-to-scale caption, swipe instruction, and the discovery “not an exact shop-the-room match” line. Source attribution and explanations remain on demand; no exact-room shopping claim was added.

Verification: **56 XCTest cases (three skipped), 27 Swift Testing cases** passed, including one-time budget refinement and decoding every cutout with genuinely transparent and opaque pixels. Six focused UI journeys passed across the final runs: physical up/down throws; role controls, ordinary vertical scrolling and light swipes; five-chair wrap/persistence and room carryover; native PDP return; independent cutout movement and unchanged total; Norda unsent advice. The room-drag test initially selected a decorative piece behind the sheet; scoping to `corner.room-board` corrected the test. Prior failed/timed-out runs are not counted as full-suite passes. Photo-picker selection is still not automated.

Shipping build: **184,292 / 184,320 KB**, **28 KB headroom**, feed **44,692 KB**, **978 media files**, six fonts. Cutouts initially exceeded the cap. Ten existing JPEG/PNG derivatives were losslessly repacked, saving approximately 282 KB, with byte-for-byte identical decoded RGBA pixels. The Norse wordmark uses an exact 17-color/alpha palette, not quantization. Derivative checksums were refreshed; base `snapshot.json` and the original 511-entry source-asset manifest are unchanged. Audit and original/optimized hashes: `docs/READING_CORNER_LOSSLESS_MEDIA.json`. No additional video degradation in this pass.

Next: user review of the real cutouts, tactile pile and room arrangement. Preserve truthful capability boundaries and the shopper's refined $3,000 working budget.
