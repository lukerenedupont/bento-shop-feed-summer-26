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
