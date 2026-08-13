# Personalized Feed Architecture

## Intent

The home screen is a finite set of personalized commerce stories, not a merchant marketplace or an infinite product grid. Topics are channels into a larger story catalog. A story can reference products from several merchants and opens a nested flick-and-stick feed before an individual product page.

## Data flow

```text
prototype-merchants.json       personalized-feed.json
(real catalog fixtures)        (topics + story definitions)
             \                    /
              FeedStory resolves stable product IDs
                           |
                    HomePage ranks/filters
                           |
                     StoryFeedCard
                           |
                  StoryDetailPage -> PDP
```

### Product catalog

`Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json`

Contains merchant presentation data and real product metadata. Product references must use the pair `(merchantID, productID)`. Titles are display data and must not be used as foreign keys.

Loaded by `SampleData/LocalMerchantService.swift`.

### Personalized feed catalog

`Assets.xcassets/personalized-feed.dataset/personalized-feed.json`

Versioned, data-driven definitions for:

- Ordered topic labels and topic keys
- Story copy and format
- Topic membership
- Stable product references
- Presentation accent and destination label
- Optional `coverImageName` pointing at a bundled cover imageset

Decoded by `SampleData/PersonalizedFeedCatalog.swift`. This bundled source can later be replaced by a generated/server response without changing the views.

### Cover images

Each editorial topic's lead story may carry a `coverImageName` (e.g. `cover-birding`). The same asset renders in two places:

- `StoryFeedCard` — full-bleed atmosphere behind the Made for You card
- `TopicLandingView` — topic header background with a legibility scrim

Source art lives in `covers/<topic>/v*.png` (highest version wins) and is downscaled into `Assets.xcassets/cover-*.imageset` as ~2200px JPEGs (~500KB each) via `sips`.

A cover story's `accentHex` is not hand-picked — it is sampled from the image itself so the header fade dissolves seamlessly. `Scripts/extract_cover_color.swift` averages the bottom ~22% of the cover (the region the fade crosses) via CoreImage `CIAreaAverage`, caps HSV brightness at 0.42 so white text stays legible, and prints a hex per image. Re-run it and update the feed JSON whenever a cover changes:

```bash
swift Scripts/extract_cover_color.swift ShopFeedSummer26/Assets.xcassets/cover-*.imageset/*.jpg
``` Stories without a cover fall back to the blurred-product atmosphere, so covers are additive, never required. Covers are generated atmosphere only — commerce facts (products, prices, images, links) always come from the merchant catalog.

Both fill images use the `Color.clear.overlay { Image(...) }.clipped()` pattern. A bare `resizable().scaledToFill()` image reports its intrinsic size to the layout and will blow out sibling padding — keep the overlay pattern when adding new cover surfaces.

## UI layers

- `Components/StoryFeedCard.swift` — shared shell, navigation, atmosphere, title, and footer.
- `Components/StoryCardLayouts.swift` — finite visual formats (`world`, `shortlist`, `setup`).
- `Pages/HomePage.swift` — topic selection and story filtering only.
- `Pages/StoryDetailPage.swift` — nested snapping feed generated from the selected story.
- `Navigation/RootView.swift` — centralized `HomeRoute` destination handling.

New content should normally require data changes, not a new SwiftUI component. Add a format only when it represents a genuinely different shopping job rather than a cosmetic carousel variation.

## Validation

Run before building or handing off:

```bash
Scripts/validate_personalized_feed.py
xcodebuild -project ShopFeedSummer26.xcodeproj \
  -scheme ShopFeedSummer26 \
  -sdk iphonesimulator \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

The validator checks IDs, references, formats, duplicates, topic coverage, covers (every `coverImageName` must have a bundled imageset; every bundled `cover-*` imageset must be referenced by a story), and subtopics (every subtopic needs a label and must reference a story inside its own topic feed).

### Topic merchandising blocks

A topic may declare ordered `merchandisingBlocks` in `personalized-feed.json`. This replaces the old fixed page template. Supported block kinds are:

- `mediaCarousel` — swipeable, ordered mix of story/collection, merchant, and product cards
- `merchantRail` — avatar-only related shops
- `productRail` — titled horizontal product assortment (for example, “For you in Coffee counter”)
- `masonry` — heterogeneous discovery stream

Blocks and their items can be reordered or independently curated without editing Swift. The validator checks block IDs, kinds, and every story, merchant, and product reference. Do not label a shelf “Deals” until authentic sale or compare-at-price data is present.

**Intent-grouped recipe (piloted on Birding gear).** Every shelf answers a
different shopper question, stated in its title, rather than mixing formats in
one carousel:

1. `Keep shopping` (productRail) — retargeting; highest intent, first slot
2. `Collections for you` (mediaCarousel, stories only) — the topic's editorial subcategories
3. `Trending shops` (merchantRail) — trust, trimmed to topically relevant merchants
4. `Discover more` (masonry) — open-ended browse; post cards stay interleaved here

Roll this recipe to the remaining topics by re-authoring their
`merchandisingBlocks` in the JSON — no Swift changes required.

### Catalog depth

Topic masonry streams the **full inventory of every shop on the page** —
story-curated products lead (editorial ordering is authoritative), then the
rest of each relevant merchant's catalog, deduped (`deepProducts` in
`TopicLandingView`). The bundled catalog holds ~340 real products pulled from
the 17 merchants' live storefronts via `Scripts/deepen_catalog.py`, which hits
each shop's public `/products.json`, skips gift cards and unavailable items,
and appends deduped entries after the hand-curated ones. Re-run it any time;
it is idempotent. Note: a topic's `relatedMerchantIDs` now surface those
shops' full catalogs in its masonry — prune off-topic related IDs in the JSON
if the mix drifts.

### Navigation model

The home tab has three levels that all render **inline** (HomePage state), so
the top bar — avatar + topic pills — persists across the whole world:

1. **For You** — vertical story-card feed (`selectedTopicID == "for-you"`)
2. **Topic** — `TopicLandingView`, selected via pill or story card
3. **Subcategory** — a drilled-in story (`focusedStoryID`), rendered through
   `StoryTopicPage` inline

`NavigationCoordinator.pushRoute(.story(…))` is intercepted at the home root
by `inlineStoryHandler` and becomes state instead of a push; pushes from other
tabs or deeper pages still navigate normally. The bottom nav's back button
walks the levels via `topicBackAction` (subcategory → topic → For You).
Product and store pages remain real pushes.

### Subtopics

Each topic may declare `subtopics` — curated `{label, storyID}` pills rendered in the topic header. Labels are phrased as shopping categories (“Optics by size”, “Kinto glassware”), not truncated story titles, and each pill opens its story. Topics without subtopics fall back to story-title pills.

### Merchant avatars

`prototype-merchants.json → images.logo` holds a real avatar URL per merchant, sourced from each store's own favicon/touch-icon CDN asset (or Google's favicon service at 128px where the store only ships a tiny icon). `MerchantLogoImage` renders these and falls back to a brand-colored initial if a URL ever dies.

## Scaling next

1. Replace bundled feed JSON with a generated response conforming to the same schema.
2. Add ranking metadata: signal source, freshness, confidence, and diversity group.
3. Add product attributes for material, form, use case, technical specs, and cultural adjacency.
4. Generate 6–10 distinct stories per topic, then select a diverse subset for For You.
5. Preserve factual product assets separately from generated atmosphere or motion.

## Roadmap: Shopping as a Bento

The next structural evolution. Worlds answer *why am I seeing this* (the
personal signal); the bento answers *how does this fit together* (the
structural grammar). Topic pages evolve from linear shelves into a packed box
of role-based compartments — for birding: *See* (optics), *Wear* (footwear),
*Carry* (straps/bags), *Keep shopping*, *Shops* — so the page teaches what a
kit **is**, not just what's for sale.

Planned sequence:

1. Bento layout engine (new `bento` block kind: compartments carry a role
   label and a cell span), piloted on Birding gear — its four hero products
   already have completed dossiers
2. Compartment sizing driven by real data: cart item → large, recent search →
   medium, taste adjacency → small; dossier/film coverage adds prominence
3. Different bento shapes per topic (mirrors by wall/room, coffee by ritual
   step) to prove the grammar flexes
4. Home For You bento as a toggle experiment — covers stay the door, bento is
   the room; masonry remains the overflow drawer below

### Dossier integration (content layer)

An external pipeline (dossier-lab) builds a **Deep Dive dossier** per curated
product plus **two portrait Sora films** of the product in use. The batch is
keyed to this prototype's stable graph keys (`merchantID + productID`), so it
is a direct content-enrichment layer:

- **Ambient films** (muted, autoplaying, looping) become bento compartment
  texture via `AmbientProductVideo` — film #1 is the ambient cell loop,
  film #2 is reserved for the Deep Dive page
- **Dossier payloads** will power a Deep Dive product page replacing the
  plain PDP for covered products: cover → bento → deep dive, each level with
  its own content type
- Coverage grows without code changes — see “Dossier drop zone” below

Status: scaffolding shipped (store, component, manifest, validation, drop
zone); awaiting first dossier JSONs + films to type the payload schema and
build the bento renderer.

## Dossier drop zone

Deep Dive dossiers + ambient films from dossier-lab plug in via `ShopFeedSummer26/Dossiers/`
(a bundle **folder reference** — new files ship on rebuild, no project regeneration):

1. Drop `<key>.json` (a saved dossier payload) into the folder.
2. Drop its mp4 films alongside, named `<key>-*.mp4` — or any name, listed under
   the manifest entry's `videoFiles`.
3. Ensure the key has an entry in `dossier-manifest.json` mapping it to
   `merchantID` + `productID` (the 11 completed batch keys are pre-seeded).
4. Rebuild. `Scripts/validate_personalized_feed.py` verifies manifest ↔ catalog ↔ files.

Runtime pieces: `DossierStore` (indexes by merchant+product, schema-tolerant payload)
and `AmbientProductVideo` (muted autoplaying loop with product-photo poster fallback;
pauses off-screen). `TopicFeatureCard` already prefers a hero product's ambient film
over cover art, so dropped films appear in Collections carousels immediately.
