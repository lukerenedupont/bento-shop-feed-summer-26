# Next Generation Feed prototype

## Question

Can Shop generate a feed with substantial visual and interaction variety while keeping merchant identity, inventory, price, and product imagery truthful?

This branch answers with a constrained generative card grammar rather than unconstrained image generation. The system chooses among authored presentation structures, then fills those structures only with canonical catalog records. It may compose, crop, rank, color, and animate; it may not invent a merchant, product, price, claim, or destination.

## Experience

- The existing Shop shell remains: buyer identity, horizontal feed navigation, utility belt, full-height flick-and-stick paging, ambient backdrop, and floating tab bar.
- For You and topic feeds resolve to 20 generated commerce cards.
- Interactions happen on the card: selecting products, swiping stacks, scrubbing comparisons, building kits, revealing drops, following merchants, rotating stages, and answering quick preference prompts.
- Cards do not route into second experiences on this branch. This keeps iteration focused on the feed itself.
- Launch with `-nextGenerationGallery [0...19]` to inspect variants directly, or `-openNextGenerationCard [0...19]` to open one in the real feed shell.

## Card grammar

| # | Layout | Primary interaction |
|---|---|---|
| 1 | Focus frame | Tap through product frames |
| 2 | Orbit | Drag products around a focal orbit |
| 3 | Split decision | Choose between two products |
| 4 | Swipe stack | Flick through a product deck |
| 5 | Mosaic spotlight | Select a tile to promote it |
| 6 | Merchant window | Follow a shop and browse its tray |
| 7 | Color wash | Change the product/color mood |
| 8 | Product timeline | Move through an assortment sequence |
| 9 | Comparison scrub | Scrub between two products |
| 10 | Kit builder | Add/remove products from a live bundle |
| 11 | Constellation | Tap connected recommendations |
| 12 | Catalog ticker | Select from a continuous-looking rail |
| 13 | Detail lens | Move a magnifying lens over merchandise |
| 14 | Price ladder | Compare a merchant assortment by price |
| 15 | Drop reveal | Tap to reveal the product |
| 16 | Editorial fold | Expand a commerce editorial feature |
| 17 | Bundle builder | Assemble a compact product set |
| 18 | Texture rail | Swipe through tactile product details |
| 19 | Product stage | Drag to rotate the hero presentation |
| 20 | Rapid poll | Give lightweight preference feedback |

## Generation contract

A generated card specification has four responsibilities:

1. **Truth** — stable IDs and references to real merchants and products.
2. **Presentation** — one layout, palette, title, eyebrow, and supporting line.
3. **Interaction** — behavior implied by the layout; all state stays local to the card.
4. **Environment** — backdrop and navigation contrast metadata used by the feed shell.

The renderer receives resolved `SampleMerchant` inventory. Product images use the canonical product image URL with the existing image pipeline and bundled fallback. Merchant-specific layouts draw from one merchant; discovery layouts may deliberately combine several merchants. Prices always pass through the shared `formatPrice` formatter.

## Safety and quality constraints

- Never generate or rewrite merchant names, product names, prices, URLs, or factual claims.
- Keep product and merchant records coupled when selection changes.
- Prefer structure and direct manipulation over ornamental generated copy.
- Preserve native Shop navigation, type, spacing, radii, materials, and haptics.
- Every card must remain legible over delayed/failed media loads.
- Light surfaces declare dark navigation contrast explicitly.
- Only the active feed card animates.
- The 20 layouts must remain deterministic for reproducible review.

## Architecture

- `Models/NextGenerationFeedCard.swift` — card layout vocabulary, specification, deterministic catalog-backed generation, and palette/contrast policy.
- `Components/NextGenerationFeedCardView.swift` — centralized renderer and local interaction state for all variants.
- `Components/NextGenerationFeedGallery.swift` — direct review harness.
- `Pages/HomeFeedPlanner.swift` — swaps the current topic assortment into generated card entries when the branch-local prototype flag is enabled.
- `Pages/HomeFeedModels.swift` — generated cards are first-class feed entries and participate in filtering, counting, identity, and contrast.

The branch excludes legacy authored films from the app target to keep the unchanged `184320 KB` product budget while iterating on the larger SwiftUI card renderer. The files remain in git and in the full prototype on `main`.
