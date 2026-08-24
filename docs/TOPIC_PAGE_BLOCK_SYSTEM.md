# Topic page block system

Topic pages are assembled by `TopicPageRecipe` in
`ShopFeedSummer26/Pages/TopicPageRecipe.swift`. A recipe is an ordered list of
blocks plus the vertical spacing between them. Resolution/rendering lives in
`TopicDetailPage.swift`; reusable card components live in
`TopicPageBlocks.swift`.

Every feed-card, inline-topic, expanded-topic, related-collection, and
subcategory destination resolves through this renderer. There is no second
legacy topic-page system.

## Available blocks

| Block | Required configuration | Behavior |
|---|---|---|
| `productRail` | Title, product query, card width | Snapping horizontal product rail |
| `featuredDeals` | Title | Centered, looping deal carousel |
| `relatedCollections` | Title, card height | Snapping editorial collection rail |
| `topMerchants` | Title | Snapping merchant carousel |
| `brandGrid` | Title | Merchant cards with six-product grids and persistent Follow controls |
| `categories` | Title, category queries, snapping preference | Bento category rail; category title opens the full assortment |
| `curatedLooks` | Title, look definitions | Free-scroll editorial looks; CTA opens every product in the look |
| `recentContent` | Title, catalog-fallback preference | Snapping Shop Posts or clearly labeled catalog media |
| `bento` | Title | Free-scroll mixed-size product rail with a defined start and end |
| `explore` | Title, filters | Two-column masonry grid with functional product filters |

## Product queries

`TopicProductQuery` supports:

- `matching`: terms searched across title, type, description, and tags
- `excluding`: terms that remove false-positive products
- `fallbackOffset`: deterministic starting point when an authored query is sparse
- `count`: maximum products returned

## Adding another topic

1. Select or add a recipe family in `TopicPageRecipeCatalog`.
2. Choose and order existing blocks.
3. Supply section labels, product queries, category definitions, and filters.
4. Add a new block type only when the interaction pattern is genuinely new.

Topics without an authored recipe automatically use the generic recipe:
new products, deals, best sellers, related collections, brand arrivals, top
merchants, recent content, a contextually named bento rail, and Explore More.
Its filter chips are derived only from topic terms that actually match products
in the assortment. Merchant-card destinations use a tighter brand-specific
recipe built from the same primitives.

## Contracts

Debug builds validate every resolved recipe. A recipe must have positive
spacing, unique non-empty block titles, product queries with at least three
results requested, supported card geometry, at least three categories, at
least two curated looks, and an `All` filter first in Explore. The build-time
feed validator separately verifies that story/product/media references exist.

## Shared geometry

Use `TopicBlockMetrics` for product widths, collection heights, and section
spacing. New blocks should use Gravity tokens internally and expose only the
few dimensions that represent a deliberate recipe variation.
