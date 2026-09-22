# Rich Merchandised World Plan

## Recommendation

Build **“For your self-care reset”** (`library-edit-9`) as the first thicker World, and promote it into the first three cards of **For you** for the demo.

This is the best fit for the NikeSKIMS reference because the approved library already contains an 18-item movement/self-care edit with exact merchant joins, including Bandit Running, District Vision, ÉTERNE, Literary Sport, Free People/On, and Walden. It can support truthful native PDPs without pretending Nike or SKIMS products exist in the local catalog.

Use the NikeSKIMS campaign media extensively for **sequence, scale, restraint, and alternation between feeling and shopping**, while keeping it in an editorial-only lane. All commerce belongs to Shop’s approved catalog: no Nike destination URLs, no Nike shopping actions, and no suggestion that an approved Shop product is the item shown in campaign media.

## What the NikeSKIMS page is doing

The current first-party page is a useful merchandising reference rather than a conventional product grid:

1. A restrained identity plate opens the page.
2. A large portrait campaign film establishes the visual world before shopping begins.
3. A short proposition and a single primary shopping action follow the film.
4. Two large image-led category features provide the first commercial handoff.
5. A nine-frame “Meet the Collections” filmstrip restores visual exploration.
6. Full-width editorial images interrupt the commerce rhythm.
7. “Explore by Color” uses a five-frame visual rail.
8. More full-width images create breathing room.
9. “Build Your Look” provides a seven-category shopping rail.
10. A second large campaign film resets the pace.
11. “Explore by Movement” closes with a three-frame activity rail.

The page payload currently declares 33 authored card records and `hasVideo: true`. Its mobile layout includes two large video records, multiple edge-to-edge stills, and horizontal filmstrips of 9, 5, 7, and 3 frames. The important pattern is not the exact number of modules; it is the repeated cadence:

> **immersion → concise idea → shopping → gallery → pause → shopping → immersion**

The campaign art also maintains a tight visual grammar: cool studio backgrounds, warm skin/material closeups, controlled negative space, repeated body crops, and only occasional text. That consistency makes a long page feel like one authored story.

### Primary sources

- [NikeSKIMS landing page](https://www.nike.com/nikeskims) — first-party page structure, metadata, authored card payload, imagery, and video declarations.
- [NikeSKIMS collection destination](https://www.nike.com/w/nikeskims-b2asd) — first-party commercial destination linked by the campaign proposition.
- [NikeSKIMS collection guide](https://www.nike.com/nikeskims-collection-guide), [bra guide](https://www.nike.com/nikeskims-bra-guide), and [lookbook](https://www.nike.com/nikeskims-lookbook) — first-party local-menu destinations exposed by the landing page.
- [NikeSKIMS page campaign poster](https://static.nike.com/a/images/f_auto,cs_srgb/w_1536,c_limit/bdf3c643-4c2c-45bf-9369-f0f920fe4f37/image.jpg) and [second film poster](https://static.nike.com/a/images/f_auto,cs_srgb/w_1536,c_limit/fd94095c-16f3-4a2e-930e-71e3d12a6d3e/image.jpg) — first-party evidence of the page’s collage and detail-crop art direction.

Observed on 2026-09-19. Nike can change the page independently.

## Proposed World: “For your self-care reset”

### Feed entry

Keep the existing full-bleed native World card and product strip. Give this story a reviewed motion-capable cover, but retain a still poster as the first frame so feed launch remains immediate.

For the demo only, promote `library-edit-9` into positions 2–3 of **For you**. Preserve:

- the authoritative 328-item catalog;
- `selectedIds` order within catalog-backed selections;
- exact merchant-ID joins;
- the current selected topic/navigation behavior.

Do not make the richer World a new top-level app mode.

### World sequence

| Beat | Presentation | Commerce behavior |
|---|---|---|
| 1. Opening film | 80–95% viewport portrait loop, edge-to-edge, muted, no white frame | No product overlay; let the World establish itself |
| 2. Thesis | One short title and at most two lines of reviewed copy | Optional single “Shop the edit” anchor, not a row of CTAs |
| 3. First shelf | Four products from the existing 18-item edit | Reuse native product cards and Shop PDP routing |
| 4. Portrait gallery | Five tall, horizontally swipeable NikeSKIMS campaign frames | Editorial-only; no fake hotspots or outbound links |
| 5. Material sequence | Three wide/tight campaign crops with controlled framing and generous spacing | Non-interactive editorial media; never claim that a Shop product is pictured |
| 6. Second shelf | Four different approved products | Native Shop PDP routing |
| 7. By activity | 3 NikeSKIMS visual category cards such as Studio, Training, and Lifestyle | Tapping the section opens the corresponding manually reviewed subset in Shop, not Nike |
| 8. Second film | Full-width NikeSKIMS movement loop, roughly one viewport tall | No destination; only mute/replay/accessibility behavior |
| 9. Build the kit | Rails for apparel, equipment, and footwear using manually reviewed membership | Native Shop PDP navigation; no invented price or availability |
| 10. Color gallery | Five campaign color/material frames | Editorial-only horizontal rail with no outbound links |
| 11. Merchant feature | One or two existing merchant collection cards for merchants represented in the edit | Exact Shop merchant destination and exact merchant products |
| 12. Closing gallery | Three additional campaign movement frames | Editorial-only visual close |
| 13. Full selection | Existing explore/grid treatment | All 18 approved products in original relative order |
| 14. Contextual Ask | Julian’s existing persistent composer | Real OAuth/Agent transport only; no scripted response |

A post rail is **not** included by default. Add one only if reviewed, merchant-authentic posts exist. Product imagery arranged like social cards is not a substitute.

### Destination policy

- NikeSKIMS campaign films and galleries do not navigate.
- Every product card opens the existing native Shop PDP.
- Every merchant feature opens the existing native Shop merchant destination.
- Every category action resolves to a reviewed subset of the approved 18 products inside Shop.
- There are no Nike URLs, web views, or Nike shopping CTAs in the World.
- Distribute first appearances across shelves and category modules so all 18 products receive a meaningful shoppable placement before the closing full-selection grid; do not create richness by repeating the same hero products.

## Asset brief

The catalog product images are sufficient for shopping modules but not for the editorial spine. The NikeSKIMS source page exposes enough first-party media to make the World materially richer:

- 2 portrait autoplay video records and their poster frames;
- a 9-frame collection filmstrip;
- a 5-frame color filmstrip;
- a 7-frame category/build-a-look filmstrip;
- a 3-frame movement filmstrip;
- multiple independent full-width campaign stills and two image-led category features.

Import roughly **24–30 distinct stills plus both portrait films**, after deduplicating responsive variants and visually near-identical crops. Use one reviewed still or video poster for the feed cover only when entering the World does not immediately repeat the same composition.

### Delivery targets

- Portrait master: 1080×1440 or 1080×1920, with a documented safe crop.
- Images: display-sized HEIF/JPEG, generally under 1.5 MB each.
- Video: H.265 preferred with H.264 compatibility where needed, no audio track unless editorially necessary, generally 4–10 MB per loop.
- Every asset: source URL/file, owner, usage status, checksum, dimensions, focal point, alt text, and approved role.
- Bundle budget for the complete World: approximately 20–35 MB after optimization.

### Rights and provenance gate

Nike’s public CDN makes campaign files technically retrievable; that is not publication permission. This plan therefore treats the exact NikeSKIMS media as **internal-reference-only** unless separate permission is established.

Store every imported campaign file behind an internal reference-media manifest, mark permission as not established, preserve its first-party source URL and checksum, and exclude it from distributable builds. Campaign blocks are editorial-only and have no shopping destination. Shop product cards may follow or interrupt those blocks, but they remain visually and semantically distinct so the interface never claims that the Shop product is pictured, endorsed, or part of NikeSKIMS.

## Code design

### Deep module

Generalize the current one-off `ThoughtfulHostWorldPrototype` into one recipe-driven module:

```swift
struct EditorialWorldRecipe {
    let storyID: String
    let surface: EditorialWorldSurface
    let blocks: [EditorialWorldBlock]
}

enum EditorialWorldBlock {
    case film(EditorialFilm)
    case statement(EditorialStatement)
    case productRail(ProductSelection)
    case gallery(EditorialGallery)
    case diptych(EditorialDiptych)
    case categoryRail([EditorialCategory])
    case merchantFeature(MerchantFeature)
    case postRail(PostSelection)
    case explore(ProductSelection)
}
```

The interface should describe editorial intent, IDs, and ordering—not SwiftUI geometry. A single `EditorialWorldPage` implementation owns:

- native layout and pacing;
- media lifecycle and poster fallback;
- visibility-aware playback;
- prefetch/cancellation;
- accessibility and Reduce Motion behavior;
- PDP/merchant routing;
- light/dark chrome intent;
- block-level analytics hooks if those are later connected.

This gives callers one small interface while keeping layout, playback, and routing complexity local. Do not add a media-provider protocol until a second real adapter exists. The initial adapter is the reviewed local bundle.

### Reuse instead of replacement

Reuse these existing implementations:

- `ProductCard` and existing product rail/PDP routing;
- `MerchantCollectionFeedCard` for merchant storytelling;
- `TopicRecentPostCard` / `ShopPostFeedCard` only for authentic posts;
- `LoopingVideoPlayer` as the playback base, extended for visibility and poster behavior if necessary;
- `CachedAsyncImage` and existing local asset resolution;
- Julian’s persistent bottom navigation/composer unchanged;
- shared media-aware chrome authority from `HomePage`/`JulianShellState`.

Migrate `ThoughtfulHostWorldPrototype` onto the recipe renderer after the new World proves the interface. Do not maintain two competing editorial layout systems.

### Likely files

- New: `ShopFeedSummer26/Worlds/EditorialWorldRecipe.swift`
- New: `ShopFeedSummer26/Worlds/EditorialWorldPage.swift`
- New: `ShopFeedSummer26/SampleData/SelfCareWorldEditorial.swift`
- Extend: `ShopFeedSummer26/Components/LoopingVideoPlayer.swift`
- Extend routing only at the current `TopicDetailPage.merchandising` seam
- Extend `LibraryArtDirection` with reviewed World media roles
- Extend the asset manifest/import validator; do not hand-add untracked files

## Performance rules

1. Render posters synchronously from local optimized assets; never wait for video before first paint.
2. Only the most visible film may play. Pause when below the visibility threshold, when a sheet/PDP covers it, or when the app backgrounds.
3. Prewarm the next poster, not every full-resolution asset in the World.
4. Cancel image/video work as blocks leave the prefetch window.
5. Respect Low Power Mode and Reduce Motion by using posters.
6. Do not instantiate AVPlayers for off-screen rails.
7. Keep the existing feed card cheap; the full media set loads only after entering the World.

## Implementation phases

### Phase 0 — editorial proof

- Confirm the target is `library-edit-9`.
- Approve the World title and one-sentence thesis.
- Build a contact sheet of the 18 products and available merchant imagery.
- Produce an asset/provenance manifest before UI work.
- Decide whether media is approved original/supplied work or internal-reference-only Nike material.

### Phase 1 — vertical slice

Build only:

- feed entry placement;
- opening film with poster;
- thesis;
- one four-product shelf;
- one three-frame gallery;
- full native PDP routing.

Review this on the physical phone for pace and visual coherence before adding page length.

### Phase 2 — full merchandising

Add:

- detail diptych;
- activity/category rail;
- second film;
- build-the-kit shelves;
- merchant feature;
- full selection.

### Phase 3 — hardening

- Migrate Thoughtful Host to the same renderer.
- Add playback/memory tests and asset-manifest validation.
- Verify media-aware top and bottom chrome across every full-bleed/light surface transition.
- Run existing navigation/search/composer/utility regressions.
- Measure cold launch, World first paint, scroll hitching, and memory on the physical iPhone.

## Acceptance criteria

- The World feels authored before it feels like a grid.
- No two consecutive major beats use the same scale or interaction pattern.
- At least two full-bleed motion moments are separated by meaningful shopping/content beats.
- Every shoppable item resolves to an approved local product and exact merchant.
- Editorial imagery is never presented as a product image without documented provenance.
- Galleries remain galleries; posts remain real post cards.
- No fabricated social, price, availability, account, or Agent state.
- Only one video plays at a time; Reduce Motion and Low Power Mode have complete poster fallbacks.
- The top search/topic chrome and persistent bottom navigation transition together.
- The existing World, search, Ask, PDP, and merchant routes continue to work.

## Confirmed direction

The working direction is now confirmed:

- use as much distinct NikeSKIMS campaign media as improves the pacing, targeting 24–30 stills and both portrait films;
- make campaign media non-commercial and non-linking;
- route every product, category, and merchant action into native Shop destinations;
- show all 18 approved products by the end of the World;
- mark exact campaign media internal-reference-only and permission-not-established.

Everything can be built on the same recipe-driven World module.
