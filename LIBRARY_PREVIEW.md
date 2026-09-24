# Native Shop asset-library preview

This is an alternate Swift app, not the Shop Canvas UI and not a replacement
for the five-video demo currently installed on Luke's phone.

- Working copy: `/Users/lukedupont/bento-shop-feed-library-demo`
- Branch: `experiment/shop-agent-world-lab` (based on the polished library preview)
- Display name: **Shop Library Preview**
- Bundle ID: `com.shopify.purl.prototype.shop.feed.library.preview`
- Version: 1.0 (20)
- Original demo: `/Users/lukedupont/bento-shop-feed-ceo-demo`, unchanged by this import.

## Restarting the local preview

The project and simulator data survive a computer restart. This preview is local—not deployed to a server—and the active worktree contains uncommitted work, so do not delete or reset `/Users/lukedupont/bento-shop-feed-library-demo`.

From Terminal, rebuild and open the all-blocks World with one command:

```sh
cd /Users/lukedupont/bento-shop-feed-library-demo
Scripts/run_library_preview.sh host
```

Other supported destinations are `self-care`, `reading-corner`, and `home`. The script boots the exact **Bento Architecture Review** simulator, validates the source snapshot and the Shopify-only publication set, rebuilds the app, installs it, and launches the requested destination. To work in Xcode instead, open `ShopFeedSummer26.xcodeproj`, select the `ShopFeedSummer26` scheme and **Bento Architecture Review** simulator, then press Run. `xcodegen generate` is needed only after changing `project.yml`.

The phone installation survives both Mac and phone restarts and can be opened directly as **Shop Library Preview**. It does not require the Mac unless rebuilding or using a local development service.

## The Oblist — reading-corner set

Run `Scripts/run_library_preview.sh reading-corner`. The new World is second
in For You, after Norda. Its feed card and hero share The Oblist’s Living Room
Edit photograph, labelled as inspiration rather than the selected set.
The original $600 request follows the shorter hero. The Oblist logo and three
role selectors use background-removed photos of the actual selected products.
The rejected vector icons and carousel have been replaced. A physical card pile
offers five chairs, two tables and two lights: flick sideways, or briefly hold
to lift and throw in any direction. Short drags spring home. White product text
stays on the image, without hearts, swap footers or instructional captions.
The working budget is now $3,000 at the shopper's explicit request; history keeps
the original $600 prompt. The initial set remains $3,894. The feed retains its
square trio, wordmark and subtotal; the World has an editable budget and a simple
“Find options closer to my budget” button. Supporting price details are in Sources.

Three visual style directions pair FRAMA/Audo lifestyle imagery with product
groups. Categories cover side tables, reading chairs, lighting and finishing
touches; they open shared native assortment sheets. An Oblist/FRAMA/Audo/Ferm
Living logo rail and existing lighting/books/furniture Worlds extend discovery.
These are editorial moods, not exact photographed sets or trending rankings.

“See it in your room” is a tappable perspective-room card using the same selected
cutouts. Inside, move the pieces or add a local room photo. There are no extra
moodboard links or disclaimers on the invitation; Info explains the illustrative,
unmeasured composition. Photos and positions stay session-local, without uploads.
Native PDP/back, merchant, search and Ask keep the canonical catalog graph.
Provenance and limitations: `docs/OBLIST_READING_CORNER_RESEARCH.md`.

Latest slice: **56 XCTest cases (3 skipped), 27 Swift Testing cases** passed.
Six focused UI journeys passed across final runs: vertical card throws without
page movement; role/light controls; five-chair cycling and persistence/room
carryover; native PDP return; independent room-piece dragging; Norda advice.
Parent-scroll interference was fixed with scoped drag ownership. Room tests scope
the editor, avoiding identically named decorative pieces behind the sheet.
No full UI-suite or actual photo-picker coverage claimed.
Shipping: **184,292 / 184,320 KB**, **28 KB headroom**, **44,692 KB** feed,
**978 media files**, **6 fonts**. Existing images were losslessly repacked, with
byte-identical decoded pixels, to fit the cutouts without more video degradation.

## Shop Agent — Norda price edit

Run `Scripts/run_library_preview.sh home`. **Your trail-running price edit** is the first For You story (`library-edit-norda-price-research`), using the existing native shared transition and persistent Julian dock. Its cinematic opening occupies about 58% of the viewport, leaving the first two products as the next visible beat.

The source-checked supplement adds 19 offers from Norda, Renegade Running, The Exchange Running Collective, District Vision, SOAR and SATISFY, including two Hoka alternatives sold by Renegade. The simplified feed cover says the shopper's Norda edit is ready, gives one factual offer/shop count, and previews only the strongest observed-price shoe plus one sale find. The World renders the exact triggering request as a sent chat bubble with a lightweight thumbs-up reaction, followed by a Shop Agent response, checked offer/shop counts and the resulting mix of exact-price research, sale finds, kit and alternatives. A locally persistent brief lets the shopper add a real delivery destination and fit/aesthetic preferences. Upcoming race is a dedicated picker: three source-linked New York event cards show name, location and date, and the selected event becomes a compact calendar card in the World. The picker does not call an event “nearby” until the entered destination establishes New York context; blank values remain visibly unset rather than being invented. Every amount is a merchant-supplied USD storefront price, not an agent-generated conversion. Nine shoe offers cover three merchants. “Find your Norda” exposes the available models as direct pills; selecting one shows every checked merchant offer for that model with its shop name and price. “Where to buy it” carries that model forward, asks only for size, features the lowest exact-match observed price and places every other proven exact seller in smaller image-and-price cards under “Also available.” Shipping policy evidence stays in merchant details, and no unsupported speed/rating rankings appear. Merchant rows open variant/source details; product images retain the native PDP journey. “A closer look” pairs Norda's attributed Western States lifestyle story with exact product details. The kit is grouped into District Vision, SATISFY and SOAR merchant cards, while a source-derived side-by-side compares the selected Norda with Hoka, District Vision and SATISFY alternatives without presenting the copy as wear testing. The separate shop rail is reduced to wordmarks, external-link badges are removed from the story rail, and the bottom protection uses the World surface color with enough trailing space to avoid a hard end seam. Product tiles have fixed square media, and feed thumbnails have no captions. Saved product hearts, model choice and comparison size persist on this device. There is no live tracking or generated conversation—this is an authored price-snapshot artifact.

The first cover and World header now share an **8-second, muted native loop** from Norda's official 055 film: a runner moving through rocky terrain. Both surfaces use the same player through the native transition. The published source streams remotely; only its real first-frame poster is bundled, for loading/failure and Reduce Motion/Low Power Mode. Attribution is in “About these prices.” Later films and social sources still open in Safari. This is internal-reference media, not permission-cleared production content. See `docs/NORDA_WORLD_MEDIA_RESEARCH.md` for evidence, merchant IDs and limitations. Refresh prices explicitly with `python3 Scripts/import_running_research.py`; the independent film manifest is under `LibraryAssets/catalog/research-media/`.

Latest verification: **46 XCTest cases (3 skipped), 26 Swift Testing cases, the expanded Norda UI journey, and 11 Python importer tests passed**. Coverage includes comparison criteria, product/back navigation, source details, equal tile dimensions, local poster loading and a native shared-player/excerpt-loop test. Reduce Motion was manually checked with pixel-identical still crops three seconds apart, then restored. A clean tracked-files export passed catalog/source validation without local credentials or the optional external feed checkout. Outgoing history and the staged patch passed Gitleaks; two exact historical localization-comment false positives are documented in `.gitleaksignore`.

Norda checkpoint shipping build: **184,140 KB / 184,320 KB**, with **180 KB headroom**. Existing preview clips were re-encoded for the phone target (including 360px Sculptural Living Room/Streetwear and 320px Fuumuu/Stadium exports), the new running films remain remote, and the unused `try-faves-figure` cutout was removed after checking all source references. Active avatar/environment assets and interactive Worlds are retained. The budget was not raised; further additions still need size discipline. The Norda journey also fixed a PDP bug where an oversized decorative image intercepted the Back button.

### Buying-time prompt

Below the checked sellers, a compact “Waiting for a better price?” card shows the compared shoe. “Tell me the best time to buy” opens an **unsent** draft in the existing Julian Ask surface with the model, color, size, merchant and observed price. It retains the World context and does not create a watcher or price alert. Submission still uses the existing Agent/sign-in path; there is no guaranteed forecast or price history.

Validation for this addition: 46 XCTest cases (3 skipped) and 27 Swift Testing cases passed, including the unsent-draft contract. The focused buying-advice UI journey passed. The longer Norda journey passed in the initial run, but a repeat left the World during the existing PDP/back segment before reaching this card; that repeat did not pass. Shipping build and budget validation passed.

## Rich movement World — build 20

`library-edit-9` (**For your self-care reset**) follows the Norda and Oblist stories in Luke’s For You feed. Its motion-led feed card uses the cinematic material-detail film rather than the grid film, the same compact two-line editorial title component as the destination hero, the shared product rail, and coordinated media-aware dark chrome. The grid film is reserved for a later editorial beat inside the World. The Nike lockup is neither rendered nor bundled.

The destination uses the campaign’s warm brown surface and a long-form editorial sequence: two campaign films, 26 filmstrip frames, six independent campaign stills, seven autoplaying collection/fabric films, four native Shop product shelves, and the complete 18-product edit. The fabric chapter retains the first-party collection names and full descriptions for Studio Stretch, Matte, Airy, Satin Shine, Weightless, Ribbed Seamless, and Stretch Knit. Collection, color, styling, and movement galleries now include concise editorial context, and paired media is explicitly clipped to prevent overlap.

Every commercial action stays native to Shop: product cards open the existing PDP using exact product/merchant joins. Campaign films and galleries do not navigate, and there are no Nike URLs or Nike shopping actions. The campaign media is isolated under `LibraryAssets/nikeskims-world/manifest.json` as internal-reference-only with permission not established, source URLs, dimensions, and SHA-256 checksums. `Scripts/import_nikeskims_world.py` reproduces the optimized bundle while excluding the Nike lockup; `Scripts/validate_nikeskims_world.py` verifies all 48 files.

## Source and editorial contract

Read-only source: `/Users/lukedupont/Developer/apx3000-shop-canvas/public/`.
The importer reads `catalog/catalog.json`, `catalog/merchants.json`, and
`catalog/merchant-depth.json` in full.

The source snapshot contains exactly **328 curated products**. From that immutable snapshot, the Shop prototype publishes only the **213 products** associated with one of the **79 confirmed Shopify merchants**. The reviewed research supplement adds 19 products and four additional merchants through the same gate, and the Oblist supplement adds nine products from an existing merchant, for **241 products / 83 merchants** in the combined catalog; domain-only, unresolved, and other-platform records are excluded from feeds, Worlds, search, merchant pages, and Agent context. `selectedIds` remains the ordering authority within the base eligible subset; **All finds** appends the running and reading-corner observations in their reviewed source order. For You groups those records by their existing group
labels, ordered by each group's first appearance; it does not claim that a
grouped feed is the same thing as the flat 328-product sequence.

Published product-to-merchant associations are retained only when joined by **exact ID** to a merchant whose source outcome is `confirmed_shopify` and whose ID is a Shopify Shop GID. Embedded product-record branding is not used. A card uses its first confirmed Shopify association as its default destination; other confirmed associations remain available. There is not yet a
multi-seller picker on the PDP.

Enrichment is joined by exact source product ID (132 curated records matched).
The original source IDs remain on the native products; deterministic numeric
IDs only adapt them to the existing Swift model. Collisions are rejected.

The broader 6,083-product archive and 663 merchant-depth rows are **not published
in this initial preview**. The importer's optional broader-inventory merge
retains non-curated status rather than promoting records into editorial feeds.

## All-blocks World prototype

**For the thoughtful host** is the current kitchen-sink World for evaluating page richness. It deliberately combines the safe block palette in one long destination: editorial statement, authentic merchant film, reviewed image gallery, native product shelf, authentic post rail, dynamic curated table, full merchant feature, material diptych, full-bleed image pause, contextual Ask refinement, neutral merchant spotlights, reviewed category subsets, merchant and maker rails, mixed-size product bento, full exploration grid, and related Worlds. The implementation is marked `PROTOTYPE`; it exists to decide cadence and density before these beats move into the planned shared `EditorialWorldRecipe` renderer. Deal language remains disabled—the former promotional card now uses the evidence-safe **Explore the shop** CTA.

## Feed-card comparison control

The overflow menu’s **Utility belt** sheet includes a persisted **Show product carousels** toggle. Turn it off to compare a lighter, full-bleed editorial treatment: reviewed merchant artwork can replace the title, while other cards show a compact title, an authored mood or point-of-view deck, and an outlined **Explore** or **See more** CTA. Every library World has its own reviewed deck copy; inventory counts are not used as editorial description. In this mode the heart/share rail collapses to one top-right overflow action. Turn the setting on to restore the authored product rails and full feedback stack. This changes presentation only and does not alter feed membership or product data.

## Assets and branding

The app bundles only referenced local assets, keeping these directory paths:

- `catalog/`
- `cosmos-brand-assets/`
- `merchant-assets/`
- `merchant-cover-assets/`

`ShopFeedSummer26/LibraryAssets/` contains 511 original local files plus native
SVG raster siblings, the normalized manifests, and higher-resolution copies of
23 reviewed product-cover photographs. The initial import was about 24 MiB;
with the explicit cover edit the library resources are about **33 MiB**.
All relative URLs resolve from that root, never from its `catalog/` subfolder.
Remote CDN URLs remain external. Original images are retained for larger
surfaces; local thumbnails provide a fallback. This is not a fully offline
copy of the merchants' catalogs, and it does not depend on localhost:5184.

Source JSON and asset hashes are recorded and validated. Source files are never
edited; imports require a separate, empty output directory. `merchant-review/`,
path traversal, and escaping symlinks are not publishable.

For dark surfaces the native wordmark loader tries **wordmarkWhite → wordmark →
logo**; light surfaces prefer wordmark first. The matte algorithm in
`src/merchant-wordmark.js` was adapted to Swift, not its UI: uniform opaque
white/black backplates become real alpha off the main thread, transparent
artwork is tinted appropriately, and unknown opaque artwork is not converted
into a destructive silhouette. Results are cached with bounded memory.

A merchant having a logo and cover does **not** create an editorial card or
approve a feed hero. For You is driven by curated products and their authored
groups. Build 4 restores the original edge-to-edge World-card treatment using
30 separately reviewed cover decisions in `editorial-covers.json`. Each cover
has a rationale, a role, a source product or exact merchant ID, and a byte hash.
Validation checks that the source belongs to the edit. The authoring script is
pinned to the reviewed snapshot, so a new import requires renewed cover review.
Merchant pages continue to use the directory's current branding as branding.

The framed-product treatment from build 3 was rejected. Build 4 removes the
white hero panel and blank color gap, keeps the title/products in the original
anchored composition, restores Luke's avatar, and replaces the raw count/group
navigation with Living, Style, Travel, Wellness and All finds. Unrecorded prices
are omitted from feed-image badges rather than repeated as fake CTA pills.
When a reviewed product image serves as a hero, its duplicate thumbnail is
omitted from that card's preview rail; the full collection and All finds keep
all products in their original order. Portrait framing is explicitly adjusted
where needed rather than blindly cropping a face at the edge.

## Native surfaces connected

- For You and collection navigation use the existing Swift feed/card system.
- All finds retains the exact relative order of the 213 Shopify-eligible products.
- Collection pages use the existing recipe blocks with honest labels: From the
  edit, More curated edits, The full selection. They do not invent best-seller,
  new-arrival, discount, or availability evidence.
- PDPs and merchant pages route through the existing native navigation stack.
- 162 missing prices remain unknown (View at shop), not $0 or guessed USD.
  The 50 USD prices and one TRY price retain their supplied currencies.
- Library PDPs suppress prototype ratings, urgency, shipping, discounts and
  checkout claims; they link to the supplied merchant product URL and show the
  source's commerce/provenance note.

Live Shop account/history/search and camera/AI experiences have not been
reimplemented against this library. This is a catalog-browsing/content preview,
not a production commerce integration.

## Julian source navigation and composer — builds 13–14

Build 12's simplified navigation/Ask sheet was rejected. It is no longer mounted.
Build 13 imports the actual source components from `Shopify/shop-client` branch
`feature/agent-vision-prototype-refresh`, commit
`79849f634b495df011aeefc0c4ef04a7180e633d`, into the local `JulianAgentUI` package.

**Long-press the bottom tab pill** to open the original **Bottom navigation**
controls: Rodeo/Pistons, full/chip/floating/tab-bar search, starter glass, all 14
app icons, and Reset to defaults. The tab/input swap, persistent UIKit input,
keyboard geometry, draft curtain/toolbar, starter stack/glass, context lane and
follow-up input come from the source, not substitute SwiftUI approximations.

The library retains its feed, utility belt, products, Worlds and post rail. The
source header replaces the added build-12 search pill; the avatar is not duplicated
in the category rail in full-search mode. Catalog queries remain local to the
213 Shopify-eligible records. The source's empty-cart policy is retained rather than
inventing cart items to force its Cart button visible.

Source provenance is recorded for 65 upstream files plus 596 unchanged support
files (Gravity, icons and translations). Local data/routing adapters and the two
input-ownership fixes are explicitly separated/documented in
`Vendor/JulianAgentUI/README.md` and `source-manifest.json`.
`Scripts/validate_julian_ui_port.py` checks the recorded port hashes and removal
of temporary diagnostic logging. This contains private Shopify source and must
not be published to the public feed repository without authorization.

**Service boundary (build 14):** Julian’s initial and follow-up composer submissions
now drive the app’s existing Shop OAuth + live Agent transport: conversation
creation, signed stream URL creation, SSE responses, product shelves, suggestions,
stream cancellation, and follow-ups. Signed-out submissions remain saved and open
the real Shop web-session sign-in action; no request is sent until authentication
succeeds. Production history/threads, notifications, and image upload remain
unavailable and are identified as such rather than simulated. Catalog search uses
Julian’s source chrome over exactly the 213 Shopify-eligible local products. This is not a
complete standalone copy of the Shop production app or all of its services.

Build 13 is optimized Debug (`-O`) to keep the complete imported source/icon set
inside the unchanged 180 MiB budget. The original demo worktree and phone build
remain unchanged. Final regression: **59 passed, 0 failed, 3 intentionally skipped
legacy fixtures**. This includes Julian's 26 imported component tests and all 8 UI
integration/content tests. Settings/reset across relaunch, both layouts, every
search placement, exact typed-draft retention, follow-up input, product routing,
worlds, gift creation and the post/merchant walkthrough are covered. Source hashes,
curated snapshot validation and `git diff --check` pass. Screenshots and the test
summary are in `DemoArtifacts/Verification/julian-source/`; the full result bundle
is `/tmp/julian-port-final2.xcresult`. Home, both dock layouts, search and the focused
composer/follow-up surfaces were visually inspected.

## Superseded navigation approximation — build 12

A single Pistons-inspired native shell, not a transplant of Julian's Shop-client
branch. Home, Orders and Favorites occupy the leading pill; Ask and Cart sit
alongside it. The library keeps the bar available inside Worlds. The original
app's `BottomNavBar` implementation and physical-phone installation are unchanged.

A compact search entry stays pinned above the existing avatar/category rail as
Home scrolls. Launch clearance and pinned-title clearance increase by 56pt;
card heights, full-bleed widths and product sizes do not change. The existing
utility belt remains at the top. Search opens a native sheet, searches only the
328 curated records (product, brand, group and exact-joined merchant names),
retains the query during this app session, and opens existing PDPs after the
sheet finishes dismissing. Empty results are explicit; no remote Agent request
is used as a search fallback.

Ask uses the current World, product or merchant context. Drafts and demo exchanges
are separately retained by stable context ID in memory; dismissing the sheet or
visiting a product does not overwrite its parent World's draft. The sheet clearly
labels itself **Demo · On-device catalog only**. Its deterministic replies expose
catalog products and recorded shop names; it is not connected to a live Agent,
does not fabricate answers to arbitrary questions, and does not claim stock,
shipping, prices, or purchase history. Other root tabs use the general library
context rather than pretending to know their account contents.

Implementation: `Navigation/LibraryShellSession.swift`,
`Navigation/LibraryNavigationPrototype.swift`, `Pages/LibrarySearchPrototype.swift`,
and `Pages/LibraryAskPrototype.swift`.

Verification: 25 applicable unit tests and all 7 UI tests passed; 3 original-buyer
fixture tests remain intentionally skipped. Checks cover pinned search, empty
results, exact PDP routing, retained search query, all four navigation destinations,
World/product draft isolation and context restoration, plus the existing belt,
gift creation, covers, merchant links and post-rail walkthrough. The bundled
snapshot validator and `git diff --check` pass. Rendered Home, scrolled feed,
World, Search and Ask screens were inspected; screenshots and the test summary
are in `DemoArtifacts/Verification/navigation/`.

Build 12 is a Debug simulator iteration, not a newly signed phone or Release
artifact. Full results: `/tmp/library-navigation-verified.xcresult`.

## Utility belt restored — build 11

The library profile now uses the existing top-of-feed utility belt, including
its gift-guide entry, original orders demo card, horizontal paging and pull
expansion/refresh behavior. No second belt implementation was added. There is
no invented purchase/saved-product history; buy-again, saved and cart signals
remain unset for this catalog-only profile. The orders card remains the original
illustrative prototype fixture, not a claim about purchases from this library.

Gift creation stays on the curated library: the existing brief form opens a
resolvable World of library products selected by the entered interests. Pull
to refresh does not load the old dossier feed or authenticated post catalog.
The library's feed, post rail and World pages remain below the belt; the preserved
original demo working copy and phone app are untouched.

## Actual post rail — build 10

The single full-width Service Projects gallery was not the requested post rail.
Build 10 replaces it with the existing `TopicRecentPostCard` format in a
horizontal snapping rail with separate cards and a neighboring peek. It uses
the original app's user-supplied Caraway table-setting and Fuumuu studio demo
post examples, retaining their identities. These are existing demo fixtures,
not newly fetched live posts or catalog photographs relabeled as social posts.
No dates, engagement counts, product matches or new merchant relationships are
invented. The 328-product catalog remains unchanged.

Tapping a post opens the existing `ShopPostFeedCard` presentation. Rail videos
pause when offscreen or while the post viewer is presented. The shared PORTA
card and linen-detail block remain below the rail. Changes remain local to the
host World in the simulator preview; the phone demo is untouched.

The first swipe check exposed an AVPlayer preroll exception while an asset was
still loading. Frame warming now requires both the player and current item to
be ready. After that fix all four UI checks passed, including separate rail
cards, horizontal swiping, opening/closing a post, and the existing merchant and
product routes. The rendered rail was visually checked; screenshots and results
are in `DemoArtifacts/Verification/post-rail/`.

## Host gallery and detail iteration — build 9 (superseded gallery)

The current host World keeps the cleaner build-8 presentation: no selected-count
subtitles, domain-style merchant labels, placeholder price text, added all-caps
eyebrows or decorative section arrows. It reuses `MerchantCollectionFeedCard`
for PORTA rather than maintaining a bespoke merchant panel.

Build 9 replaces the single lifestyle scene with a two-image, attributed
Service Projects gallery and replaces the bento with a matching green-linen
setting/detail pair from Salter House. Gallery photographs link to the actual
steel tray; the attribution links to its merchant. Both linen photographs link
to the existing linen product. These are catalog gallery photographs, not
fabricated merchant posts: no social captions, dates, likes or engagement counts
are asserted. The 17-product selection and other Worlds are unchanged.

All 21 applicable native data/navigation checks passed (3 legacy-fixture tests
remain skipped). The UI walkthrough verified the gallery swipe, product links,
PORTA navigation and linen detail link; rendered screenshots were reviewed.
This is a simulator prototype; the phone's existing demo is unchanged.

## Initial one-World editorial prototype — build 7

Only `library-edit-0` (For the thoughtful host) uses the new authored sequence:
existing hero → four opening picks → a serving-tray lifestyle scene → PORTA
feature → linen/candle/vase bento → the complete 17-product selection → related
edits. All other Worlds retain the shared recipe.

The middle blocks live in `Pages/ThoughtfulHostWorldPrototype.swift` and are
intentionally a local prototype until the direction is agreed. Its five
additional photos are copied into our native snapshot from the same products'
galleries, with source IDs/URLs and byte hashes in `host-prototype-assets.json`.
The source library is not modified.

“View steel tray” routes to the pictured tray. “Shop this mood” opens a curated
assortment, explicitly described as inspiration rather than claiming all items
are pictured. The PORTA feature routes to its real merchant page; its product
tiles and the bento tiles route to their real product pages. No stock, price,
shipping or checkout claims are invented.

## Supplied wordmarks — build 6

Source archive: `http://127.0.0.1:56239/cosmos-wordmarks.zip` (downloaded once;
the running app does not depend on that server). Its manifest explicitly marks
reuse permission as **not established / internal review only**. No public
publication or rights clearance is implied.

The importer selected 72 reviewed asset identities for 67 exact merchant
mappings and 10 explicitly branded edits. It excluded 618 pending/unreviewed
rows, including the entire sweep-generated tier and two pending entries inside
the launch-approved folder. Selected originals and native rasters add about
4.4 MiB, not the full 93 MiB ZIP.

Exact Shopify/domain IDs map directly. Numeric Cosmos IDs map only through the
current directory's exact `curatedBranding.sourceProfileId` metadata. No
merchant-name or slug matching is used. The ten named brand edits also have
an explicit identity map, checked against every product's supplied brand.
A brand logo on a multi-retailer edit never replaces the product's seller ID.

The supplied marks replace plain brand headings on applicable feed cards,
related-collection cards and their World heroes. Mixed editorial Worlds retain
their titles. Merchant avatars/store headers prefer the new reviewed marks,
with the previous current-directory sources retained as fallbacks. The data,
cover choices and spacing are otherwise unchanged.

Reimport with:

```sh
python3 Scripts/import_merchant_wordmarks.py /path/to/cosmos-wordmarks.zip \
  /Users/lukedupont/Developer/apx3000-shop-canvas/public/catalog/merchants.json \
  ShopFeedSummer26/LibraryAssets
python3 -m unittest discover -s Scripts -p 'test_*import.py'
```

Mappings and SHA-256 hashes are in `LibraryAssets/wordmarks.json`. ZIP paths,
checksums, review status, native rasters and source-library separation are
validated. This import did not edit the source library or the phone's original
demo. During verification, the external `merchant-depth.json` was updated by
another process; the native preview deliberately retains its pinned enrichment
snapshot. The source catalog, merchant directory and 511 original asset hashes
still match the imported snapshot.

Verification: all 11 importer tests passed; 16 native data/state tests passed
with 3 legacy-fixture tests skipped, and all 3 UI navigation/screenshot tests
passed. The Release build passed the 180 MiB budget at 125,576 KiB (~123 MiB).
Eckhaus Latta and Nordic Knots feed renders were visually inspected; screenshots
and test output are in `DemoArtifacts/Verification/wordmarks/`. This remains an
internal simulator preview; the phone's existing demo was not updated.

## World-page spacing — build 5

The shared topic block layout now uses 44pt between standard sections (48pt for
relaxed recipes), 24pt between a heading and its content, 24pt between product
grid rows, and 24pt between the hero and the first block. Card dimensions,
font sizes, horizontal gutters, and the For You feed composition are unchanged.
This spacing pass is confined to the library preview, not the installed phone demo.

## Verification

Build 4 adds explicit cover/rail validation and screenshot checks across the
opening World cards. Visual review includes the actual rendered hosting, gift,
fashion and living-room cards, not only successful image decoding.

Verified 2026-09-17: 18 native tests passed, with the 3 intentionally inapplicable
legacy-demo fixture tests skipped; all 7 importer tests passed. The Release
simulator build passed the unchanged size guardrail at 120,880 KiB (~118 MiB).
It is running in the simulator, with screenshots and the test summary in
`DemoArtifacts/Verification/editorial/`. The source library and the original
phone demo were not modified. No physical-phone installation of build 4 has
been performed.

### Initial build 3 checks

- All 7 importer tests passed.
- All 6 native library tests passed, along with 8 shared state/planning tests;
  the 3 original-demo fixture tests were explicitly skipped.
- Both native UI flows passed twice after targeting the actual collection
  button: feed/artwork → collection → Close, and collection → product → merchant
  → Back. The checks include loaded artwork, clear title geometry, missing-price
  handling, and the absence of fabricated checkout claims.
- Release simulator build succeeded at **111,280 KiB (~109 MiB)**, including
  **24,108 KiB (~24 MiB)** of library resources.
- The Release preview was installed and launched in the simulator. It has not
  been installed on the physical phone; the original build 2 remains there.
- Hashes confirm all 3 source JSON files and all 511 referenced original assets
  are unchanged. No `merchant-review/` files were copied.
- `git diff --check` passed and temporary diagnostic logs were removed.

The Release app is `DemoArtifacts/ShopLibraryPreview-Simulator.app`. A screenshot
and navigation-test summary are in `DemoArtifacts/Verification/`. Full local
native test results are `/tmp/bento-library-final-tests.xcresult` (data/matting)
and `/tmp/bento-library-ui-verified.xcresult` (repeated final UI checks).

## Import, validate, build

```sh
# Choose a new empty output location for an import; do not overwrite the source.
python3 Scripts/import_shop_canvas_library.py \
  /Users/lukedupont/Developer/apx3000-shop-canvas/public \
  /tmp/new-shop-library-snapshot

python3 -m unittest discover -s Scripts -p 'test_shop_canvas_import.py'
python3 Scripts/validate_shop_canvas_snapshot.py ShopFeedSummer26/LibraryAssets
xcodegen generate
Scripts/build_demo.sh simulator <exact-simulator-UUID>
```

The library preview deliberately does not embed the old 77 MiB frozen feed.
Existing native UI assets remain available, but its active catalog never merges
in the old buyer inventory. The app's 180 MiB budget is unchanged.

Native tests cover order, exact merchant associations, URL roots, current dark
wordmark priority, unknown prices/currency, alpha matting, artwork loading and
layout, and feed → collection → PDP → merchant navigation. Three tests for the
original demo's Luke/Mikhail opening are explicitly skipped in this alternate
app; they remain covered in the preserved original project.
