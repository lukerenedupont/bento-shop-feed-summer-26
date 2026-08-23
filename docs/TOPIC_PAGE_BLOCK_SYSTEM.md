# Topic page block system

Topic pages are assembled by `TopicPageRecipe` in
`ShopFeedSummer26/Pages/TopicDetailPage.swift`. A recipe is an ordered list of
blocks plus the vertical spacing between them. The renderer, navigation,
loading behavior, and card components are shared.

Every feed-card, inline-topic, expanded-topic, related-collection, and
subcategory story destination resolves through this renderer. `TopicLandingView`
remains the top-level multi-story feed surface; it is no longer used as a
second visual system for individual topic details.

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

1. Add a recipe keyed by the topic/story ID in `pageRecipe`.
2. Choose and order existing blocks.
3. Supply section labels, product queries, category definitions, and filters.
4. Add a new block type only when the interaction pattern is genuinely new.

Topics without an authored recipe automatically use the generic recipe:
new products, deals, best sellers, related collections, brand arrivals, top
merchants, recent content, a contextually named bento rail, and Explore More.
Its filter chips are derived only from topic terms that actually match products
in the assortment. Merchant-card destinations use a tighter brand-specific
recipe built from the same primitives.
