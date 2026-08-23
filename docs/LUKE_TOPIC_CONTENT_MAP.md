# Luke’s topic-view content map

Generated from the bundled Luke shelf catalog on 2026-08-21. This is the working source of truth for topic IDs, related collections, page recipes, and source products.

## How to use this file

- **Collection links** below jump to the related topic in this document. The source data does not include public collection URLs, so none are invented.
- **PDP** is shown only when the product has an exact title match in the canonical merchant catalog and therefore has a verified public `shopUrl`.
- **Image** links point to the exact source image bundled for that shelf product.
- **App route** is the prototype navigation contract. Product rows list the exact `merchantID` and `productID` consumed by `HomeRoute.product`.
- Rails can be enriched at runtime from the represented merchants’ broader catalogs. The product tables below are the authored shelf products, not every dynamically enriched rail item.

**Sources:** [Shelf catalog](../ShopFeedSummer26/Assets.xcassets/hypothesis-shelves.dataset/hypothesis-shelves.json) · [Merchant catalog](../ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json) · [Topic implementation](../ShopFeedSummer26/Pages/TopicDetailPage.swift)

## Page recipes

### Standard topic

1. Hero
2. New this week
3. Featured deals, when available
4. Best sellers
5. Top merchants, when available
6. Related collections, when available
7. Recent posts, when available
8. Explore more

### Expanded sculptural topic

1. Hero
2. Just dropped
3. Featured deals
4. Best sellers in lighting
5. Related collections
6. New arrivals from your brands
7. Brands worth the hype
8. Unique finds
9. Browse home objects by category
10. Recent posts
11. Complete the room
12. Explore more

## Topic index

| # | Topic | Category | Products | Related collections |
|---:|---|---|---:|---|
| 1 | [Modern bathroom fixtures](#shelf-luke-1-modern-bathroom-fixtures) | living | 8 | [Sculptural Bath Finishing Touches](#shelf-luke-14-sculptural-bath-finishing-touches) |
| 2 | [Sculptural Living Room Pieces](#shelf-luke-2-sculptural-living-room-pieces) | living | 8 | [Sculptural Bath Finishing Touches](#shelf-luke-14-sculptural-bath-finishing-touches) · [Modern kids seating & tables](#shelf-luke-12-modern-kids-seating-tables) |
| 3 | [Playful coffee & table](#shelf-luke-3-playful-coffee-table) | morning | 8 | [Whimsical sculptural decor](#shelf-luke-4-whimsical-sculptural-decor) |
| 4 | [Whimsical sculptural decor](#shelf-luke-4-whimsical-sculptural-decor) | living | 8 | [Playful coffee & table](#shelf-luke-3-playful-coffee-table) |
| 5 | [Modernist Graphic Design Library](#shelf-luke-5-modernist-graphic-design-library) | design | 8 | [Artist-Collab Tees, Hoodies & Prints](#shelf-luke-16-artist-collab-tees-hoodies-prints) |
| 6 | [Analog Watches & Desk Clocks](#shelf-luke-6-analog-watches-desk-clocks) | design | 7 | — |
| 7 | [Stylish travel essentials](#shelf-luke-7-stylish-travel-essentials) | outdoors | 8 | [Elevated Winter Knits](#shelf-luke-15-elevated-winter-knits) · [Streetwear caps and tees](#shelf-luke-9-streetwear-caps-and-tees) · [Neutral Activewear Essentials](#shelf-luke-11-neutral-activewear-essentials) |
| 8 | [Ceremonia hair ritual](#shelf-luke-8-ceremonia-hair-ritual) | wellness | 8 | — |
| 9 | [Streetwear caps and tees](#shelf-luke-9-streetwear-caps-and-tees) | style | 8 | [Artist-Collab Tees, Hoodies & Prints](#shelf-luke-16-artist-collab-tees-hoodies-prints) · [Stylish travel essentials](#shelf-luke-7-stylish-travel-essentials) |
| 10 | [Performance sneakers edit](#shelf-luke-10-performance-sneakers-edit) | style | 8 | [Elevated Classics](#shelf-luke-18-elevated-classics) · [Race-Day And Daily Trainers](#shelf-luke-19-race-day-and-daily-trainers) |
| 11 | [Neutral Activewear Essentials](#shelf-luke-11-neutral-activewear-essentials) | wellness | 8 | [Elevated Winter Knits](#shelf-luke-15-elevated-winter-knits) · [Stylish travel essentials](#shelf-luke-7-stylish-travel-essentials) |
| 12 | [Modern kids seating & tables](#shelf-luke-12-modern-kids-seating-tables) | living | 8 | [Sculptural Living Room Pieces](#shelf-luke-2-sculptural-living-room-pieces) |
| 13 | [Design-Forward Dog Essentials](#shelf-luke-13-design-forward-dog-essentials) | living | 8 | — |
| 14 | [Sculptural Bath Finishing Touches](#shelf-luke-14-sculptural-bath-finishing-touches) | living | 7 | [Modern bathroom fixtures](#shelf-luke-1-modern-bathroom-fixtures) · [Sculptural Living Room Pieces](#shelf-luke-2-sculptural-living-room-pieces) |
| 15 | [Elevated Winter Knits](#shelf-luke-15-elevated-winter-knits) | style | 6 | [Neutral Activewear Essentials](#shelf-luke-11-neutral-activewear-essentials) · [Stylish travel essentials](#shelf-luke-7-stylish-travel-essentials) |
| 16 | [Artist-Collab Tees, Hoodies & Prints](#shelf-luke-16-artist-collab-tees-hoodies-prints) | style | 8 | [Streetwear caps and tees](#shelf-luke-9-streetwear-caps-and-tees) · [Modernist Graphic Design Library](#shelf-luke-5-modernist-graphic-design-library) |
| 17 | [Pro-Level Painting Essentials](#shelf-luke-17-pro-level-painting-essentials) | design | 6 | — |
| 18 | [Elevated Classics](#shelf-luke-18-elevated-classics) | style | 8 | [Performance sneakers edit](#shelf-luke-10-performance-sneakers-edit) · [Race-Day And Daily Trainers](#shelf-luke-19-race-day-and-daily-trainers) |
| 19 | [Race-Day And Daily Trainers](#shelf-luke-19-race-day-and-daily-trainers) | style | 8 | [Performance sneakers edit](#shelf-luke-10-performance-sneakers-edit) · [Elevated Classics](#shelf-luke-18-elevated-classics) |

<a id="shelf-luke-1-modern-bathroom-fixtures"></a>

## 1. Modern bathroom fixtures

High-design faucets, hardware and wall lighting

- **Category:** living
- **Shelf ID:** `shelf-luke-1-modern-bathroom-fixtures`
- **Shelf type:** exploit · household persona
- **Price band:** $80–$1400
- **App route:** `HomeRoute.topicExpanded(topicId: "living", sourceStoryId: "shelf-luke-1-modern-bathroom-fixtures")`
- **Related collections:** [Sculptural Bath Finishing Touches](#shelf-luke-14-sculptural-bath-finishing-touches)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | CUNA - Cream \| Wall-Mounted Light | Upton | $129 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/7a05/0079/3545/9401/files/sconce-cuna-cream-2-upton.jpg) | `shelf-shop-upton-ff049dd` / `3391803343539049754` |
| 2 | Graff - M.E. Floor-Mounted Exposed Tub Filler - Trim Only | PlumbTile | $1749 | — | [Image](https://cdn.shopify.com/s/files/1/0623/8552/0866/files/G-1752-LM3F_1_ee60146c-bf46-476e-b42b-0c69bfd8fe8e.png) | `shelf-shop-plumbtile-fed4d0b` / `942989939971795568` |
| 3 | Gf Bathroom Faucet - Wall Mount - 5" Brass/Brushed Nickel | The Bathroom Boutique | $1089 | — | [Image](https://cdn.shopify.com/s/files/1/1357/6361/files/TTU.BAF.SGF.06632_01.jpg) | `shelf-shop-the-bathroom-boutique-37cda72` / `6883259897261938375` |
| 4 | Concord Wall-Mount Bathroom Faucet in Brushed Brass | Nouvelle Design Studio | $579.95 | — | [Image](https://cdn.shopify.com/s/files/1/0755/1057/9514/files/pdgr8a9p3njmze15jmki_9edcf843-db08-47eb-935c-d1726b7514a4.jpg) | `shelf-shop-nouvelle-design-studio-4ba0fea` / `7501361887877329415` |
| 5 | Concealed Toilet Paper Holder (Tile-Integrated) Edplit | EdPlit | $208.25 | — | [Image](https://cdn.shopify.com/s/files/1/0655/1463/5402/files/With_Cons.jpg) | `shelf-shop-edplit-d978f37` / `4491250619396773368` |
| 6 | Hidden Toilet Flush Button M3 Edplit - Сompatible with GROHE | EdPlit | $300.81 | — | [Image](https://cdn.shopify.com/s/files/1/0655/1463/5402/files/With_cons_black.jpg) | `shelf-shop-edplit-d978f37` / `4483912047189695803` |
| 7 | Artifacts Wall Mount Double Robe Hook | PDI Kitchen, Bath & Lighting | $105.63 | — | [Image](https://cdn.shopify.com/s/files/1/0782/9376/2286/files/e355e52a76010330100638f5e1f53f32865e4456.jpg) | `shelf-shop-pdi-kitchen-bath-lighting-47f83b2` / `1541058198250566249` |
| 8 | Kartners Circo Knurled Robe Hook | Focal Point | $84.52 | — | [Image](https://cdn.shopify.com/s/files/1/0726/1166/0077/files/366130-robe-hook-pc.jpg) | `shelf-shop-focal-point-574e42f` / `2193242313171164685` |

<a id="shelf-luke-2-sculptural-living-room-pieces"></a>

## 2. Sculptural Living Room Pieces

Artful lamps, mirrors, side and coffee tables

- **Category:** living
- **Shelf ID:** `shelf-luke-2-sculptural-living-room-pieces`
- **Shelf type:** exploit · household persona
- **Price band:** $200–$2511
- **App route:** `HomeRoute.topicExpanded(topicId: "living", sourceStoryId: "shelf-luke-2-sculptural-living-room-pieces")`
- **Related collections:** [Sculptural Bath Finishing Touches](#shelf-luke-14-sculptural-bath-finishing-touches) · [Modern kids seating & tables](#shelf-luke-12-modern-kids-seating-tables)
- **Page structure:** Hero → Just dropped → Featured deals → Best sellers in lighting → Related collections → New arrivals from your brands → Brands worth the hype → Unique finds → Browse home objects by category → Recent posts → Complete the room → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Silk Table Lamp | The Oblist | $1311.18 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/b7cd/0671/5290/4457/files/aq5ebmbr9xd8yvbkae0g_ea0d65ee-debd-4cc3-9aa1-72760b1e788e.jpg) | `shelf-shop-the-oblist-02fd47c` / `1791399064416116685` |
| 2 | Elyse Wall Mirror - Deep Lichen Green | Forom | $1250 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/d866/0356/2795/8403/files/Elyse-Wall-Mirror-Deep-Lichen-Green_2.jpg) | `shelf-shop-forom-330c94c` / `6889052820848670944` |
| 3 | Travertine Pyramid Table Lamp | The Oblist | $1735.38 | — | [Image](https://cdn.shopify.com/s/files/1/d/89c6/0671/5290/4457/files/kapuks6zek4qhx0e4mwi.jpg) | `shelf-shop-the-oblist-02fd47c` / `6732253626093937508` |
| 4 | Modern Red Oval Sculpted Pedestal Side Table | Homebaa | $478.99 | — | [Image](https://cdn.shopify.com/s/files/1/0668/8417/3981/files/modern-red-oval-steel-sculpted-pedestal-side-table-3.webp) | `shelf-shop-homebaa-42a4f71` / `1918088593929405847` |
| 5 | Pedestal Side Table | Thuma | $295 | — | [Image](https://cdn.shopify.com/s/files/1/2448/0687/files/thuma-pedestal-side-table-natural-1.png) | `shelf-shop-thuma-6ee196e` / `2917320268360463546` |
| 6 | Boomerang Coffee Table | 2Modern Furniture & Lighting | $769 | — | [Image](https://cdn.shopify.com/s/files/1/0265/0083/products/ethnicraft-boomerang-coffee-table-size-small--33-5-in-width-remove.jpg) | `shelf-shop-2modern-furniture-lighting-b86facc` / `1286356427168620425` |
| 7 | Monarch Coffee Table | Stillfried Design | $1495 | — | [Image](https://cdn.shopify.com/s/files/1/0010/0807/4867/files/MonarchCoffeeTable-NaturalWalnut-P01.jpg) | `shelf-shop-stillfried-design-178e768` / `3944500607985302627` |
| 8 | Sculptural Twist Pedestal Coffee Table for Organic Modern Living | A & E Bowery Lighting | $1460 | — | [Image](https://cdn.shopify.com/s/files/1/0670/8015/9275/files/3_382aafdb-f9cc-44ce-94de-8b6d7571f69d.jpg) | `shelf-shop-a-e-bowery-lighting-29b49c3` / `1588130628707273584` |

<a id="shelf-luke-3-playful-coffee-table"></a>

## 3. Playful coffee & table

Graphic brewer, bold storage and sculptural cups

- **Category:** morning
- **Shelf ID:** `shelf-luke-3-playful-coffee-table`
- **Shelf type:** exploit · household persona
- **Price band:** $30–$800
- **App route:** `HomeRoute.topicExpanded(topicId: "morning", sourceStoryId: "shelf-luke-3-playful-coffee-table")`
- **Related collections:** [Whimsical sculptural decor](#shelf-luke-4-whimsical-sculptural-decor)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | &klevering Grid Trivet | Stacked Store | $41 | Open loop | [Image](https://cdn.shopify.com/s/files/1/d/8092/0573/4088/7104/files/klevering-Grid-Trivet-Green-1_e67264e5-023f-43f7-b0f2-b1263233ed2c.jpg) | `shelf-shop-stacked-store-b6b9dd4` / `2780728077803625869` |
| 2 | Aiden Precision Coffee Maker | Fellow | $360 | — | [PDP](https://fellowproducts.com/products/aiden-precision-coffee-maker) · [Image](https://cdn.shopify.com/s/files/1/0057/6235/1219/files/Web_PDP_Aiden_Black_1_83032bf9-19ec-4a65-9165-ba53cae20a39.png) | `shelf-shop-fellow-f6f3c9f` / `6317690220130675415` |
| 3 | Caraway Dot Containers in Gray (Set of 4) | Premium Home Source | $25 | — | [Image](https://cdn.shopify.com/s/files/1/0082/6323/7713/files/caraway-dot-containers-in-gray-_set-of-4_-KW-FS05-DOT-premium-home-source.jpg) | `shelf-shop-premium-home-source-37cee7a` / `8496095282680422086` |
| 4 | Food Storage Set | Caraway | $225 | — | [Image](https://cdn.shopify.com/s/files/1/0258/6273/3906/files/food-storage-set_cream_hero.jpg) | `shelf-shop-caraway-39e10a4` / `668553342939229034` |
| 5 | Mini Food Storage Set | Caraway | $125 | — | [Image](https://cdn.shopify.com/s/files/1/0258/6273/3906/files/mini-food-storage-set_cream_hero.jpg) | `shelf-shop-caraway-39e10a4` / `903197280937113880` |
| 6 | Creative Porcelain Mugs & Espresso Cups - Coffee Mug Set of 4 | MoMA Design Store | $50 | — | [Image](https://cdn.shopify.com/s/files/1/0623/7962/2630/products/4d70ba8a-039b-43f8-b5de-d4fa8a4af0a8.jpg) | `shelf-shop-moma-design-store-ec1431b` / `5466224128689779172` |
| 7 | Butterfly Espresso Cup & Saucer | Blue Rose Pottery | $48.5 | — | [Image](https://cdn.shopify.com/s/files/1/0946/9227/8638/files/222-DSU103Filename2.jpg) | `shelf-shop-blue-rose-pottery-bb30e03` / `3372640558712480865` |
| 8 | 70's Ceramics Brutalism Espresso Mugs (Set of 4) | R.Place | $67 | — | [Image](https://cdn.shopify.com/s/files/1/0238/7957/files/espresso.png) | `shelf-shop-r-place-1462e44` / `782345018279794544` |

<a id="shelf-luke-4-whimsical-sculptural-decor"></a>

## 4. Whimsical sculptural decor

Characterful animal vases and playful figurines

- **Category:** living
- **Shelf ID:** `shelf-luke-4-whimsical-sculptural-decor`
- **Shelf type:** exploit · household persona
- **Price band:** $40–$250
- **App route:** `HomeRoute.topicExpanded(topicId: "living", sourceStoryId: "shelf-luke-4-whimsical-sculptural-decor")`
- **Related collections:** [Playful coffee & table](#shelf-luke-3-playful-coffee-table)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | DOIY Pigeon Vase | Stacked Store | $46 | Open loop | [Image](https://cdn.shopify.com/s/files/1/d/fe62/0573/4088/7104/files/DOIY-Pigeon-Vase-1_a329ee48-1c81-46d4-b32c-2a67a7ce6222.jpg) | `shelf-shop-stacked-store-b6b9dd4` / `8181050158038070899` |
| 2 | Donna Wilson Creature - Paddy Pigeon | Stacked Store | $115.68 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/3966/0573/4088/7104/files/Donna-Wilson-Creature-Paddy-Pigeon-1_45fd803c-3272-440b-a299-e19b504a60c9.jpg) | `shelf-shop-stacked-store-b6b9dd4` / `2670282561759860665` |
| 3 | Zana Vessel by MESO | MESO | $130 | — | [Image](https://cdn.shopify.com/s/files/1/1424/5908/files/Zana_Vessel_by_MESO.png) | `shelf-shop-meso-48549b5` / `7669716434801717588` |
| 4 | Ceramic Animal Bud Vase | L’Epicuriste | $46 | — | [Image](https://cdn.shopify.com/s/files/1/0632/6104/9082/files/FORLEEPWEBSITE-2026-03-31T144829.426.png) | `shelf-shop-lepicuriste-bd6fa40` / `4616622246943502832` |
| 5 | Ceramic Fish Vase | Herb & Living | $68.95 | — | [Image](https://cdn.shopify.com/s/files/1/0646/6859/8323/files/CeramicFishVases.avif) | `shelf-shop-herb-living-ff3ff2c` / `2180918525698509762` |
| 6 | Decorative Ceramic Balloon Dog Figurine – Modern Art Sculpture for Home or Office | Decor Amora | $59.95 | — | [Image](https://cdn.shopify.com/s/files/1/1016/0868/5914/files/Decorative_Ceramic_Balloon_Dog_Figurine__Modern_Art_Sculpture_for_Home_or_Office__Playful_Design__18x22_cm__Available_in_Multiple_Colors_0.png) | `shelf-shop-decor-amora-fe16387` / `2693367346869335690` |
| 7 | Dumpster Fire Trash Stash Ceramic Figure | 100% Soft | $40 | — | [Image](https://cdn.shopify.com/s/files/1/1133/3328/files/df-trashstash.jpg) | `shelf-shop-100-soft-2c1f919` / `3902571000770920883` |
| 8 | Pigeon Vase | KITSCH BITCH SIGHT STORE | $36.95 | — | [Image](https://cdn.shopify.com/s/files/1/1692/2189/files/5861-DYVASMPIG.jpg) | `shelf-shop-kitsch-bitch-sight-store-0033276` / `5683794288291404035` |

<a id="shelf-luke-5-modernist-graphic-design-library"></a>

## 5. Modernist Graphic Design Library

Standards, grids, identity, and contemporary typography

- **Category:** design
- **Shelf ID:** `shelf-luke-5-modernist-graphic-design-library`
- **Shelf type:** exploit · self persona
- **Price band:** $25–$90
- **App route:** `HomeRoute.topicExpanded(topicId: "design", sourceStoryId: "shelf-luke-5-modernist-graphic-design-library")`
- **Related collections:** [Artist-Collab Tees, Hoodies & Prints](#shelf-luke-16-artist-collab-tees-hoodies-prints)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | NYCTA Graphics Standards Manual Compact Edition | Standards Manual | $55 | — | [PDP](https://standardsmanual.com/products/nyctacompactedition) · [Image](https://cdn.shopify.com/s/files/1/0883/7252/products/payment_01-2500.jpg) | `shelf-shop-standards-manual-1a14dab` / `5374066407298938370` |
| 2 | NYCTA Objects | Backstory | $42 | — | [Image](https://cdn.shopify.com/s/files/1/0612/7193/3106/files/9780692902554_98980df0-6763-4503-96e9-cb689e610b23.jpg) | `shelf-shop-backstory-c403a09` / `672640030380459791` |
| 3 | NASA, DANNE & BLACKBURN’S GRAPHICS STANDARDS MANUAL [REPRINTED EDITION] | twelvebooks | $39 | — | [Image](https://cdn.shopify.com/s/files/1/1415/5034/files/00_e3f7fb0e-e2b2-4450-bbaf-8ba3c83604d0.jpg) | `shelf-shop-twelvebooks-28f5f04` / `7927441134849778849` |
| 4 | Rastersysteme für die visuelle Gestaltung | Niggli | $59.95 | — | [Image](https://cdn.shopify.com/s/files/1/0904/4803/6160/files/9783721201451_5.jpg) | `shelf-shop-niggli-0810760` / `2573501419342054110` |
| 5 | Grid Systems in Graphic Design: A Visual Communication Manual for Graphic Designers, Typographers and Three Dimensional Designers (Bilingual) | Bookshelf Bliss | $59.95 | — | [Image](https://cdn.shopify.com/s/files/1/0769/3765/8589/files/imageloader_5ba700cd-04d0-450b-b279-a086bac483c5.jpg) | `shelf-shop-bookshelf-bliss-e7130f1` / `4177441368935370413` |
| 6 | 1726481: Logo Modernism (Bu) | Stretta Music GmbH | $75 | — | [Image](https://cdn.shopify.com/s/files/1/0865/5067/5791/files/stretta-image-1726481-0.jpg) | `shelf-shop-stretta-music-gmbh-626229f` / `9110206033780521450` |
| 7 | Theory of Type Design | Draw Down | $50 | — | [PDP](https://draw-down.com/products/theory-of-type-design) · [Image](https://cdn.shopify.com/s/files/1/1681/2497/products/TheoryofTypeDesign_21s.jpg) | `shelf-shop-draw-down-aa4108d` / `495333147612150828` |
| 8 | A Grammar of Typography: Classical Design in the Digital Age: New Edition | Monstera's Books | $55 | — | [Image](https://cdn.shopify.com/s/files/1/0815/1652/7891/files/9781567928631.jpg) | `shelf-shop-monstera-s-books-3d7d342` / `3904914824635392663` |

<a id="shelf-luke-6-analog-watches-desk-clocks"></a>

## 6. Analog Watches & Desk Clocks

Design-forward wristwatches and compact timepieces

- **Category:** design
- **Shelf ID:** `shelf-luke-6-analog-watches-desk-clocks`
- **Shelf type:** exploit · self persona
- **Price band:** $80–$5210
- **App route:** `HomeRoute.topicExpanded(topicId: "design", sourceStoryId: "shelf-luke-6-analog-watches-desk-clocks")`
- **Related collections:** None authored
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Swatch Neon Flumotions Watch | MoMA Design Store | $125 | Saved | [PDP](https://store.moma.org/products/swatch-neon-flumotions-watch) · [Image](https://cdn.shopify.com/s/files/1/d/2d5b/0623/7962/2630/files/3b5c586c-e76c-4620-b971-e53a46ef05ac.jpg) | `shelf-shop-moma-design-store-ec1431b` / `3937523310879409231` |
| 2 | 1973 Rolex Oysterdate Precision 34mm Stainless Steel 6694 | Reference In Time | $3695 | — | [Image](https://cdn.shopify.com/s/files/1/d/2fce/0594/5907/6207/files/IMG_8224.jpg) | `shelf-shop-reference-in-time-07e890f` / `3168917830843931094` |
| 3 | The Studio Flip Clock - Retro Analog Desk Clock | Studio Analog | $129 | — | [Image](https://cdn.shopify.com/s/files/1/0663/1866/3774/files/4943b90cb4744a0b9201f74615467376.webp) | `shelf-shop-studio-analog-d7e888f` / `5192156250485947404` |
| 4 | Minimalist Ceramic Desk Clock | Vhail | $89.95 | — | [Image](https://cdn.shopify.com/s/files/1/0759/3672/7357/files/Minimalist_Ceramic_Desk_Clock_0.png) | `shelf-shop-vhail-bcc39aa` / `2570243354690201607` |
| 5 | Riki Alarm Clock | JINEN | $130 | — | [Image](https://cdn.shopify.com/s/files/1/1069/0552/products/lemnos_riki_alarm_clock_natural.jpg) | `shelf-shop-jinen-8f677a7` / `3903809854522595655` |
| 6 | Seiko Selection SCVE051 Mechanical Men's Watch | MonaWatch | $385 | — | [Image](https://cdn.shopify.com/s/files/1/0920/5858/3354/files/NewProject_15203a02-2b7e-4272-95f3-ab81b7b82918.webp) | `shelf-shop-monawatch-26661a2` / `4659095226737432615` |
| 7 | CITIZEN  NJ0150-56W | Bijouterie Veronneau | $438 | — | [Image](https://cdn.shopify.com/s/files/1/0624/8579/0874/files/Galnj0150-56w-1-20240813043253NJ0150-56W.png) | `shelf-shop-bijouterie-veronneau-38df653` / `5557586778689332515` |

<a id="shelf-luke-7-stylish-travel-essentials"></a>

## 7. Stylish travel essentials

Carry-on, organizers, cozy layers and comfort

- **Category:** outdoors
- **Shelf ID:** `shelf-luke-7-stylish-travel-essentials`
- **Shelf type:** exploit · self persona
- **Price band:** $40–$250
- **App route:** `HomeRoute.topicExpanded(topicId: "outdoors", sourceStoryId: "shelf-luke-7-stylish-travel-essentials")`
- **Related collections:** [Elevated Winter Knits](#shelf-luke-15-elevated-winter-knits) · [Streetwear caps and tees](#shelf-luke-9-streetwear-caps-and-tees) · [Neutral Activewear Essentials](#shelf-luke-11-neutral-activewear-essentials)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | The Carry-On in Misty Purple | Away: Built for modern travel | $278 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/9b3c/0664/7418/0792/files/PDP_School_PC_CAR_MistyPurple_02.jpg) | `shelf-shop-away-built-for-modern-travel-e44f9c2` / `2550493215484415686` |
| 2 | Featherlight Daily Tote in Misty Purple | Away: Built for modern travel | $97 | — | [Image](https://cdn.shopify.com/s/files/1/0664/7418/0792/files/PDP_School_DailyTote_MistyPurple_01.jpg) | `shelf-shop-away-built-for-modern-travel-e44f9c2` / `317796091470213712` |
| 3 | Airplane Mode Travel Hoodie | Comfrt | $59 | — | [Image](https://cdn.shopify.com/s/files/1/0569/4029/8284/files/1_-_2026-07-27T173134.845.jpg) | `shelf-shop-comfrt-6d9274b` / `8836003514488376238` |
| 4 | Carry-On Compression Packing Cube Set | Briggs and Riley | $109 | — | [Image](https://cdn.shopify.com/s/files/1/0141/2779/2186/files/X111-4f11_shirt_update_55c34a20-cf2e-4472-9bc3-5e908d268216.jpg) | `shelf-shop-briggs-and-riley-2b4febd` / `1262971616135959746` |
| 5 | Travel Packing Cubes, Set of 4 - Multi Folk Flower | Natural Life | $45 | — | [Image](https://cdn.shopify.com/s/files/1/0409/9656/9251/files/BAG000147.webp) | `shelf-shop-natural-life-3e4355b` / `6935462781929576082` |
| 6 | CozyRest® Memory Foam Neck Pillow | The Pillow Home | $75 | — | [Image](https://cdn.shopify.com/s/files/1/0726/5871/4960/files/Cozyrest_Pillow_Home_2_final_1_1.webp) | `shelf-shop-the-pillow-home-deb1aa3` / `8653670256137621866` |
| 7 | Luka Hanging Toiletry Bag | CALPAK | $64 | — | [Image](https://cdn.shopify.com/s/files/1/0941/4996/files/LUKA-HANGING-TOILETRY-BAG-FRONT-CHOCOLATE_020443de-073d-41de-a3a0-67aababe06d9.jpg) | `shelf-shop-calpak-a55db4c` / `9128552098469355717` |
| 8 | Terra 35L Soft-Sided Carry-On Luggage | CALPAK | $215 | — | [Image](https://cdn.shopify.com/s/files/1/0941/4996/files/TERRA-35L-SOFT-SIDED-CARRY-ON-LUGGAGE-WHITE-SANDS-FRONT.jpg) | `shelf-shop-calpak-a55db4c` / `7036088264504752270` |

<a id="shelf-luke-8-ceremonia-hair-ritual"></a>

## 8. Ceremonia hair ritual

Clean masks, oils, sprays and towels

- **Category:** wellness
- **Shelf ID:** `shelf-luke-8-ceremonia-hair-ritual`
- **Shelf type:** exploit · self persona
- **Price band:** $25–$50
- **App route:** `HomeRoute.topicExpanded(topicId: "wellness", sourceStoryId: "shelf-luke-8-ceremonia-hair-ritual")`
- **Related collections:** None authored
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Hair Towel | Ceremonia | $32 | — | [PDP](https://ceremonia.com/products/hair-towel) · [Image](https://cdn.shopify.com/s/files/1/0414/8301/0212/products/Ceremonia_ECOMM_HairTowel-Guava_4x5_bc988ce4-2c5c-4dc6-b6f9-c0a2365241cb.jpg) | `shelf-shop-ceremonia-2c22ebd` / `539085619044163298` |
| 2 | Guava Travel Kit | Credo | $49 | — | [Image](https://cdn.shopify.com/s/files/1/0637/6147/files/Ceremonia_GuavaTravelKit_01.png) | `shelf-shop-credo-676fdd6` / `7980425056781879608` |
| 3 | Guava Rescue Spray | Credo | $30 | — | [Image](https://cdn.shopify.com/s/files/1/0637/6147/products/ProductHeroImage-GuavaRescueSpray.jpg) | `shelf-shop-credo-676fdd6` / `4893750876822488626` |
| 4 | Ceremonia Babassu Deep Conditioning Hair Mask - Hydrates and Strengthens, 7.2oz | Sustai Market | $36.21 | — | [Image](https://cdn.shopify.com/s/files/1/0615/0887/8528/files/31ZsMu2kyiL._SL500.jpg) | `shelf-shop-sustai-market-9d2b547` / `5583337349594497881` |
| 5 | Ceremonia \| Aceite de Moska Scalp Oil | Living with Ivey | $34 | — | [Image](https://cdn.shopify.com/s/files/1/0639/1005/2011/files/ceremonia-aceite-de-moska-scalp-oil-ceremonia-living-with-ivey-1891112.jpg) | `shelf-shop-living-with-ivey-ccb8fb0` / `2088941386066517164` |
| 6 | Microfiber Towel + Wrap | Rizos Curls | $35 | — | [Image](https://cdn.shopify.com/s/files/1/1822/5087/files/HairTowel1.jpg) | `shelf-shop-rizos-curls-b31b2f6` / `9096306767346091317` |
| 7 | Smooth Microfiber Hair Towel Wrap | The Perfect Haircare | $28.99 | — | [Image](https://cdn.shopify.com/s/files/1/0025/1478/0219/products/black.towel.model.1a-pichi.png) | `shelf-shop-the-perfect-haircare-25831d3` / `3578977496630333503` |
| 8 | Weightless Hydration Mask | Launch Party | $36 | — | [Image](https://cdn.shopify.com/s/files/1/0068/4159/8040/files/6_322a5962-143f-4387-be42-fa01d4222611.png) | `shelf-shop-launch-party-7ee8ae8` / `8557727191679700916` |

<a id="shelf-luke-9-streetwear-caps-and-tees"></a>

## 9. Streetwear caps and tees

Graphic T-shirts and New York snapbacks

- **Category:** style
- **Shelf ID:** `shelf-luke-9-streetwear-caps-and-tees`
- **Shelf type:** exploit · self persona
- **Price band:** $30–$120
- **App route:** `HomeRoute.topicExpanded(topicId: "style", sourceStoryId: "shelf-luke-9-streetwear-caps-and-tees")`
- **Related collections:** [Artist-Collab Tees, Hoodies & Prints](#shelf-luke-16-artist-collab-tees-hoodies-prints) · [Stylish travel essentials](#shelf-luke-7-stylish-travel-essentials)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | 'Feel Alive' Shirt | Wicked Clothes | $33 | Saved | [Image](https://cdn.shopify.com/s/files/1/0251/5984/files/Feel_Alive_Shirt.jpg) | `shelf-shop-wicked-clothes-45c0043` / `3412777982406864989` |
| 2 | New York Yankees Subway Series Script Logo Snapback Hats-Infrared | Sports World NY | $39.99 | — | [Image](https://cdn.shopify.com/s/files/1/0505/0793/9999/files/0F824D58-FE1E-4FA2-864E-92AECF619565.jpg) | `shelf-shop-sports-world-ny-d54fe63` / `5020607137166840821` |
| 3 | New Era 9Forty A-Frame New York Yankees 1999 World Series Patch Trucker Snapback Hat - Realtree, Black | Hat Club | $45 | — | [Image](https://cdn.shopify.com/s/files/1/0833/0609/files/52110.1.jpg) | `shelf-shop-hat-club-dc4354b` / `4095048644261272835` |
| 4 | New York Mets 9Fifty A Frame Rope Trucker Snapback Hat | CapsuleHats | $38 | — | [Image](https://cdn.shopify.com/s/files/1/0504/3047/6476/files/MetsRopeTrucker-FSJPG.jpg) | `shelf-shop-capsulehats-5b22143` / `4782018840537819724` |
| 5 | Men's New York Yankees MLB Baseball RealTree APX '47 Hitch Snapback Trucker Hat | Bleacher Bum Collectibles | $39.99 | — | [Image](https://cdn.shopify.com/s/files/1/1835/3969/files/7HARMESH-0710-47_Brand_1.jpg) | `shelf-shop-bleacher-bum-collectibles-b9d71cc` / `5676554390495269207` |
| 6 | 'WEEZY' GRAPHIC TEE | HYPEDEPT | $34.99 | — | [Image](https://cdn.shopify.com/s/files/1/0697/5422/4935/files/WZY.png) | `shelf-shop-hypedept-2879247` / `4176582308335611151` |
| 7 | '97' GRAPHIC TEE | HYPEDEPT | $34.99 | — | [Image](https://cdn.shopify.com/s/files/1/0697/5422/4935/files/97_c5c4585b-dd07-44d2-93be-123a754ee235.png) | `shelf-shop-hypedept-2879247` / `2670836369645265328` |
| 8 | Eric B & Rakim on 14th street New York | Filipp Jenikae Art Prints | $120.2 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/ca3a/0802/4172/1692/files/Erib-and-Rakim-on-14th-street-New-York.webp) | `shelf-shop-filipp-jenikae-art-prints-adf17be` / `9075069708076876342` |

<a id="shelf-luke-10-performance-sneakers-edit"></a>

## 10. Performance sneakers edit

Nike and New Balance everyday trainers

- **Category:** style
- **Shelf ID:** `shelf-luke-10-performance-sneakers-edit`
- **Shelf type:** exploit · self persona
- **Price band:** $80–$220
- **App route:** `HomeRoute.topicExpanded(topicId: "style", sourceStoryId: "shelf-luke-10-performance-sneakers-edit")`
- **Related collections:** [Elevated Classics](#shelf-luke-18-elevated-classics) · [Race-Day And Daily Trainers](#shelf-luke-19-race-day-and-daily-trainers)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | New Balance Made in USA 992 - Shadow Grey/Turtledove | Sneaker Politics | $200 | Saved | [Image](https://cdn.shopify.com/s/files/1/0214/7974/files/Sneaker-Politics-NEWBALANCE-MadeinUSA992-ShadowGrey-Turtledove-U9927WX-WB-1.jpg) | `shelf-shop-sneaker-politics-4e294ec` / `1756791634573591281` |
| 2 | Nike x BODE Lacing Knit 'Cream Brown' FJ0218-125 | KICKS CREW | $150.56 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/1cf7/0603/3031/1875/files/Capture-2024-06-27-113835.png) | `shelf-shop-kicks-crew-8dcae0d` / `1058654969461855699` |
| 3 | New Balance Mens Made in USA 992 Shoes | Extra Butter | $200 | — | [Image](https://cdn.shopify.com/s/files/1/0236/4333/files/U992GY-1.jpg) | `shelf-shop-extra-butter-4dfaf3d` / `4543935540081980113` |
| 4 | NEW BALANCE 992 'MADE IN USA' - WHITE/ TEAM ROYAL | Undefeated | $140 | — | [Image](https://cdn.shopify.com/s/files/1/0282/5850/files/footwear_new_balance-992-made-in-usa_U99278L.view_1.jpg) | `shelf-shop-undefeated-f238736` / `5679103973533314127` |
| 5 | New Balance 992 Made in USA (Dusk Shower) | Patta | $138 | — | [Image](https://cdn.shopify.com/s/files/1/0018/7793/4115/files/U992TO_2.png) | `shelf-shop-patta-347149b` / `4123349625099545956` |
| 6 | Nike P-6000 'Light Orewood Brown Phantom Khaki' | TRNDS | $99.99 | — | [Image](https://cdn.shopify.com/s/files/1/0524/9128/8767/files/l2.png) | `shelf-shop-trnds-9a4c616` / `2730933857932203279` |
| 7 | New Balance 1890 'Grey Days' - Slate Grey/Shipyard | Sneaker Politics | $135 | — | [Image](https://cdn.shopify.com/s/files/1/0214/7974/files/Sneaker-Politics-NEWBALANCE-1890-U18905UY-WB-1.jpg) | `shelf-shop-sneaker-politics-4e294ec` / `1066932413820812129` |
| 8 | New Balance U992 7WX "Made in USA Shadow Grey" | FOOTDISTRICT | $161 | — | [Image](https://cdn.shopify.com/s/files/1/0929/8116/6458/files/sneakers-new-balance-u992-7wx-made-in-usa-shadow-grey-u9927wx-0.jpg) | `shelf-shop-footdistrict-4205a0c` / `1269347018478636280` |

<a id="shelf-luke-11-neutral-activewear-essentials"></a>

## 11. Neutral Activewear Essentials

Bras, shorts and tanks in soft everyday tones

- **Category:** wellness
- **Shelf ID:** `shelf-luke-11-neutral-activewear-essentials`
- **Shelf type:** exploit · self persona
- **Price band:** $60–$120
- **App route:** `HomeRoute.topicExpanded(topicId: "wellness", sourceStoryId: "shelf-luke-11-neutral-activewear-essentials")`
- **Related collections:** [Elevated Winter Knits](#shelf-luke-15-elevated-winter-knits) · [Stylish travel essentials](#shelf-luke-7-stylish-travel-essentials)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Cable Knit Cropped Winter Bliss Turtleneck Long Sleeve - Ivory | Alo Yoga | $148 | Open loop | [Image](https://cdn.shopify.com/s/files/1/2185/2813/files/W3910R_03299_b1_s1_a1_m242.jpg) | `shelf-shop-alo-yoga-561ac5f` / `5072467516453192554` |
| 2 | FITS EVERYBODY LACE SCOOP BRALETTE 2-PACK \| DUSTY PINK AND PIN DOT | SKIMS | $74 | — | [Image](https://cdn.shopify.com/s/files/1/0259/5448/4284/files/SKIMS-BRA-BR-SCP-9193-DPPD-FLT.jpg) | `shelf-shop-skims-ea54323` / `3883293732160115178` |
| 3 | CRZ YOGA Butterluxe Biker Shorts 4'' - High Waisted Spandex for Women's Yoga & Workouts | Purrosa | $49.95 | — | [Image](https://cdn.shopify.com/s/files/1/0793/3031/2451/files/81UIUDosOvL._AC_SL1500.jpg) | `shelf-shop-purrosa-4466268` / `483262702330922728` |
| 4 | Like a Cloud Spaghetti-Strap Bra | ShopSimon | $58 | — | [Image](https://cdn.shopify.com/s/files/1/0291/4536/6588/files/f90ca56d416841c9bfac9ef254032a28.webp) | `shelf-shop-shopsimon-f1874e5` / `6969395289128751081` |
| 5 | Wunder Train Mesh-Back Bra | ShopSimon | $49 | — | [Image](https://cdn.shopify.com/s/files/1/0291/4536/6588/files/378cecc693064b8f98185d03e754061b.webp) | `shelf-shop-shopsimon-f1874e5` / `2760635202683322749` |
| 6 | SCULPT Bike Shorts - Dark Chocolate | LEELO ACTIVE | $51 | — | [Image](https://cdn.shopify.com/s/files/1/0067/6069/3850/files/sculpt-bike-shorts-dark-chocolate-993536.jpg) | `shelf-shop-leelo-active-d074388` / `8845096794159359118` |
| 7 | Harmony Tank | LIVE! Activewear | $58 | — | [Image](https://cdn.shopify.com/s/files/1/0561/5383/3585/files/502004_P1627_00PT01_1.jpg) | `shelf-shop-live-activewear-32b40f1` / `9215861916712319276` |
| 8 | Comfort Basic Tank Top | LIVE! Lincoln | $42 | — | [Image](https://cdn.shopify.com/s/files/1/0686/1442/2753/products/306536_P121000BC01_11.jpg) | `shelf-shop-live-lincoln-b1cd60a` / `8540284475219409458` |

<a id="shelf-luke-12-modern-kids-seating-tables"></a>

## 12. Modern kids seating & tables

Design-forward chairs and play tables for children

- **Category:** living
- **Shelf ID:** `shelf-luke-12-modern-kids-seating-tables`
- **Shelf type:** exploit · household persona
- **Price band:** $120–$1600
- **App route:** `HomeRoute.topicExpanded(topicId: "living", sourceStoryId: "shelf-luke-12-modern-kids-seating-tables")`
- **Related collections:** [Sculptural Living Room Pieces](#shelf-luke-2-sculptural-living-room-pieces)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Dumbo Kids Chair | COZONI US | $119 | — | [Image](https://cdn.shopify.com/s/files/1/0750/4524/1123/products/dumbo-kids-chair-cozoni-us-8.jpg) | `shelf-shop-cozoni-us-c5eb27a` / `2446849591439869651` |
| 2 | Dumbo Armchair | COZONI US | $189 | — | [Image](https://cdn.shopify.com/s/files/1/0750/4524/1123/products/dumbo-armchair-cozoni-us-15.jpg) | `shelf-shop-cozoni-us-c5eb27a` / `1070908198373590011` |
| 3 | Minla 6-In-1 High Chair | Maxi-Cosi | $159.74 | — | [Image](https://cdn.shopify.com/s/files/1/0623/4564/2038/files/w03rwd9oaai9t0k1o3vn_1124bdac-bf42-4233-bf86-42dc707145ba.png) | `shelf-shop-maxi-cosi-fbad9af` / `906545070081479500` |
| 4 | Momcozy DinerPal High Chair Natural Wood | Joy Parenting Club | $463.11 | — | [Image](https://cdn.shopify.com/s/files/1/0706/8549/1446/files/61KKMxlQP7L._SY879.jpg) | `shelf-shop-joy-parenting-club-c1897ad` / `8121319771610869827` |
| 5 | Costzon 4-in-1 Kids Picnic Table with Umbrella, Sand & Water Sensory Bins \| Wooden Toddler Outdoor Table with Benches, Cushions, Cover, Gardening Tools, Kids Outdoor Furniture for Patio Backyard | ModernFurnitureDeals | $179.78 | — | [Image](https://cdn.shopify.com/s/files/1/0745/3733/7015/files/71TwqRRtsUL._AC_SX679.jpg) | `shelf-shop-modernfurnituredeals-76ae8a1` / `5196980198694618298` |
| 6 | Octagon Table, Stools & Umbrella Set - Bear Brown & Beige | KidKraft.com | $149.99 | — | [Image](https://cdn.shopify.com/s/files/1/0703/0767/6376/files/20304_rsm_1.jpg) | `shelf-shop-kidkraft-com-fff90d2` / `6913395034556184462` |
| 7 | Costzon Kids Picnic Table, Wooden Toddler Outdoor Table & Bench Set with Removable Umbrella & Cushions, Stripe Fabric, Kids Outdoor Furniture for Patio Backyard Garden, Fits 4 Children Age 3+ (Navy) | Velora | $119.3 | — | [Image](https://cdn.shopify.com/s/files/1/0710/8519/5366/files/71aMqcrk4XL._AC_SX679.jpg) | `shelf-shop-velora-6cc2eab` / `952068988054664632` |
| 8 | Cybex Lemo 2 Chair | Stork Exchange | $192 | — | [Image](https://cdn.shopify.com/s/files/1/0251/9059/6644/files/download_b449b7b8-428b-4bf4-b731-fc31ceb69058.jpg) | `shelf-shop-stork-exchange-17b3a60` / `1158927229899252743` |

<a id="shelf-luke-13-design-forward-dog-essentials"></a>

## 13. Design-Forward Dog Essentials

Stylish carriers, modern diners, beds and food

- **Category:** living
- **Shelf ID:** `shelf-luke-13-design-forward-dog-essentials`
- **Shelf type:** exploit · household persona
- **Price band:** $40–$250
- **App route:** `HomeRoute.topicExpanded(topicId: "living", sourceStoryId: "shelf-luke-13-design-forward-dog-essentials")`
- **Related collections:** None authored
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Sling Bag – Medium – Rope Carry | Labo Mono | $115.69 | Saved | [Image](https://cdn.shopify.com/s/files/1/d/05f2/0254/3252/2831/files/GridstopoliveRopestraporange.jpg) | `shelf-shop-labo-mono-6cb725f` / `4604275291855095167` |
| 2 | Knavigate \| Advanced Dog Carrier with Internal Frame & Hip Belt | K9 Sport Sack | $199.95 | — | [Image](https://cdn.shopify.com/s/files/1/1163/3982/files/Knavigate_Midnight_Black_1-XS_04_3742c742-ca5d-4ab4-96bf-101ecff677d8.jpg) | `shelf-shop-k9-sport-sack-aa50ac6` / `7919477752126057749` |
| 3 | Transit Tote Dog Carrier | Cleverpup | $120 | — | [Image](https://cdn.shopify.com/s/files/1/0730/2915/7157/files/Cleverpup_Transit_Small_Leopard_Side.jpg) | `shelf-shop-cleverpup-a3b8a51` / `3409473274721773702` |
| 4 | Tommy Hilfiger Canvas Dog Tote Bag \| Designer Dog Carrier | Kanine \| Premium Designer Dog Apparel & Accessories | $145 | — | [Image](https://cdn.shopify.com/s/files/1/0573/8849/9033/files/Blue_396384b1-7edb-4a74-803b-f51c45b48ba7.jpg) | `shelf-shop-kanine-premium-designer-dog-apparel-accessories-434c801` / `8242183689012992714` |
| 5 | Baron Double Diner - Modern Wrought Iron, Mission Style Elevated Dog Bowl Stand (5.5" / 8" / 10" / 15" / 18") | NMN Designs | $85 | — | [Image](https://cdn.shopify.com/s/files/1/2493/0462/products/Baron-Modern-Elevated-Dog-Bowl-Stand-with-Slow-Feed-Dog-Bowl-Stainless-Steel-with_RDB13_with_slow_feed_bowl_-_72dpi.jpg) | `shelf-shop-nmn-designs-a3cca23` / `4349762680257856639` |
| 6 | Pranzo | MiaCara | $95 | — | [Image](https://cdn.shopify.com/s/files/1/0762/1656/6036/files/Unbena43nnt-1.jpg) | `shelf-shop-miacara-f37ed40` / `2925405406044189770` |
| 7 | Chew Proof Armored™ Ripstop Elevated Dog Bed | K9 Ballistics | $120 | — | [Image](https://cdn.shopify.com/s/files/1/0061/5553/4407/files/K9-0100-CPA-Rip-Stop-Elevated-Dog-Bed-S-BLK.jpg) | `shelf-shop-k9-ballistics-8fc4951` / `3180906233077149327` |
| 8 | Freeze Dried Premium Mix | BJ's Raw Pet Food | $38.99 | — | [Image](https://cdn.shopify.com/s/files/1/0698/4341/9441/files/4141_BJsRaw_14oz_ProductRendering_PremiumMix.png) | `shelf-shop-bj-s-raw-pet-food-2d25b1f` / `3724195631792357875` |

<a id="shelf-luke-14-sculptural-bath-finishing-touches"></a>

## 14. Sculptural Bath Finishing Touches

Elevated lights, mats and countertop accessories

- **Category:** living
- **Shelf ID:** `shelf-luke-14-sculptural-bath-finishing-touches`
- **Shelf type:** exploit · household persona
- **Price band:** $40–$800
- **App route:** `HomeRoute.topicExpanded(topicId: "living", sourceStoryId: "shelf-luke-14-sculptural-bath-finishing-touches")`
- **Related collections:** [Modern bathroom fixtures](#shelf-luke-1-modern-bathroom-fixtures) · [Sculptural Living Room Pieces](#shelf-luke-2-sculptural-living-room-pieces)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Elyse Portable Lamp - Deep Lichen Green | Forom | $215 | — | [Image](https://cdn.shopify.com/s/files/1/0356/2795/8403/files/elyse_portable_freen_studio.png) | `shelf-shop-forom-330c94c` / `3608965473022767590` |
| 2 | Bath Stone™ Mat - Rain | Dorai Home | $75 | — | [Image](https://cdn.shopify.com/s/files/1/0055/2445/5542/files/100-10008_BS-Rain_Slate_PDP_Q32024_1.jpg) | `shelf-shop-dorai-home-bbcec4b` / `1912763172331222661` |
| 3 | Molto Bath Mat | Society Limonta - US store | $250 | — | [Image](https://cdn.shopify.com/s/files/1/0067/5568/0341/files/MOLTO-TAPPETINO_BIANCO_01.jpg) | `shelf-shop-society-limonta-us-store-5c04139` / `8070289664195573452` |
| 4 | Slate Bath Accessories | Kassatex | $24 | — | [Image](https://cdn.shopify.com/s/files/1/0002/9910/6314/products/SLATE_LOTIONDISPENSER_1283.jpg) | `shelf-shop-kassatex-86600ad` / `8605206801568290887` |
| 5 | Gabriella Bath Mat | Sage and Clare | $58 | — | [Image](https://cdn.shopify.com/s/files/1/0156/7216/files/islabtmt_5_1.jpg) | `shelf-shop-sage-and-clare-8732e87` / `6393861409859765847` |
| 6 | Hidden Towel Holder Set (ball-catch) | EdPlit | $56.69 | — | [Image](https://cdn.shopify.com/s/files/1/0655/1463/5402/files/Set_1pcs.jpg) | `shelf-shop-edplit-d978f37` / `5741098783317741310` |
| 7 | HERU - Natural \| Wall-Mounted Light | Upton | $129 | — | [Image](https://cdn.shopify.com/s/files/1/d/65f3/0079/3545/9401/files/sconce-heru-natural-1-upton.jpg) | `shelf-shop-upton-ff049dd` / `1360197513559918501` |

<a id="shelf-luke-15-elevated-winter-knits"></a>

## 15. Elevated Winter Knits

Cozy sweaters, knit joggers and fleece hoodies

- **Category:** style
- **Shelf ID:** `shelf-luke-15-elevated-winter-knits`
- **Shelf type:** exploit · self persona
- **Price band:** $80–$220
- **App route:** `HomeRoute.topicExpanded(topicId: "style", sourceStoryId: "shelf-luke-15-elevated-winter-knits")`
- **Related collections:** [Neutral Activewear Essentials](#shelf-luke-11-neutral-activewear-essentials) · [Stylish travel essentials](#shelf-luke-7-stylish-travel-essentials)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Cable Knit Winter Bliss Hoodie - Ivory | Alo Yoga | $158 | — | [Image](https://cdn.shopify.com/s/files/1/2185/2813/files/W3783R_03299_b1_s1_a1_1_m177.jpg) | `shelf-shop-alo-yoga-561ac5f` / `5790741028039858671` |
| 2 | Roxy Midweight Fleece Hoodie | Madhappy | $195 | — | [Image](https://cdn.shopify.com/s/files/1/2554/3534/files/Madhappy-Roxy-Hoodie-Flat-Pineapple-01.jpg) | `shelf-shop-madhappy-063b805` / `938284826115102395` |
| 3 | COTTON FLEECE CLASSIC HOODIE \| LIGHT HEATHER GREY | SKIMS | $98 | — | [Image](https://cdn.shopify.com/s/files/1/0259/5448/4284/files/SKIMS-LOUNGEWEAR-TP-PLO-4475-LHG.jpg) | `shelf-shop-skims-ea54323` / `8688619307981730890` |
| 4 | The Japan Knit Jogger | The Folklore | $115 | — | [Image](https://cdn.shopify.com/s/files/1/0635/3344/9453/files/418591ed-ee0d-4dc7-a471-f5312af3a55e.webp) | `shelf-shop-the-folklore-9e5b76b` / `4145733242543846833` |
| 5 | Soft Oversized Knitted Straight Leg Joggers - Seasalt | AYBL | $90 | — | [Image](https://cdn.shopify.com/s/files/1/3000/0340/files/10.11---WOMENS3466.jpg) | `shelf-shop-aybl-c824fcc` / `5644823468946063190` |
| 6 | Deena Balloon Knit Jogger | Z SUPPLY | $98 | — | [Image](https://cdn.shopify.com/s/files/1/0076/7075/9477/files/ZP263737_AHK_FRONT.jpg) | `shelf-shop-z-supply-8bbf52c` / `1249889576824524084` |

<a id="shelf-luke-16-artist-collab-tees-hoodies-prints"></a>

## 16. Artist-Collab Tees, Hoodies & Prints

Limited-edition apparel and wall art by artists

- **Category:** style
- **Shelf ID:** `shelf-luke-16-artist-collab-tees-hoodies-prints`
- **Shelf type:** adjacent_leap · self persona
- **Price band:** $60–$300
- **App route:** `HomeRoute.topicExpanded(topicId: "style", sourceStoryId: "shelf-luke-16-artist-collab-tees-hoodies-prints")`
- **Related collections:** [Streetwear caps and tees](#shelf-luke-9-streetwear-caps-and-tees) · [Modernist Graphic Design Library](#shelf-luke-5-modernist-graphic-design-library)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Artist Collaboration Heavyweight Print T-Shirt - Yamalin Limited Edition | Yamalinclothes | $93.53 | — | [Image](https://cdn.shopify.com/s/files/1/0711/8720/2331/files/88426faf_b1eafafe-89b0-4a52-9a69-284d6ea75d8c.jpg) | `shelf-shop-yamalinclothes-75f01eb` / `7079345399695861705` |
| 2 | Dark Legacy (Edicion Especial) | MZHATSS INC USA | $60 | — | [Image](https://cdn.shopify.com/s/files/1/0793/8175/8204/files/45743496-90E2-41BE-B141-7978F80CF7C8.png) | `shelf-shop-mzhatss-inc-usa-35f4d53` / `7990717516674538091` |
| 3 | XOXO (Full Set) | MZHATSS INC USA | $125 | — | [Image](https://cdn.shopify.com/s/files/1/0793/8175/8204/files/79939445-A415-47E8-9780-31E5A5594C36.jpg) | `shelf-shop-mzhatss-inc-usa-35f4d53` / `102268630138580710` |
| 4 | MARIO PICARDO | CLASSIC Paris | $80 | — | [Image](https://cdn.shopify.com/s/files/1/0446/3653/6994/files/IMG_2943.jpg) | `shelf-shop-classic-paris-249db76` / `4066842927228705409` |
| 5 | EIGHT BLESSINGS | DROOL | $63 | — | [Image](https://cdn.shopify.com/s/files/1/0623/5367/0303/files/req-97f4f30c-a63e-4037-81a5-50bc9382e19e.jpg) | `shelf-shop-drool-4aef397` / `1086140446811542117` |
| 6 | Risograph Print: Ethereal (2nd Edition) | Suparom Store | $44 | — | [Image](https://cdn.shopify.com/s/files/1/0655/0781/9582/files/Ethereal.jpg) | `shelf-shop-suparom-store-c97b8ef` / `2448042281808192459` |
| 7 | Anna M. Cullen x Black Maple Trading - Artist Collab: Snail Mail Stamp Sweatshirt or Hoodie | Black Maple Trading Co. | $44 | — | [Image](https://cdn.shopify.com/s/files/1/0623/3767/9615/files/AnnaM.CullenSnailMailStampCrewneckSweatshirtWhite.jpg) | `shelf-shop-black-maple-trading-co-cf9b652` / `2294582115984818684` |
| 8 | Artist Collab: Ex-Crisis Unisex Hoodie | Sundays Best | $55 | — | [Image](https://cdn.shopify.com/s/files/1/0592/3976/0043/files/unisex-premium-hoodie-black-back-675761a614e7d.jpg) | `shelf-shop-sundays-best-29e19f8` / `4052299475639425148` |

<a id="shelf-luke-17-pro-level-painting-essentials"></a>

## 17. Pro-Level Painting Essentials

Trays, protection, tape, and tools for clean repaints

- **Category:** design
- **Shelf ID:** `shelf-luke-17-pro-level-painting-essentials`
- **Shelf type:** anniversary · household persona
- **Price band:** $120–$800
- **App route:** `HomeRoute.topicExpanded(topicId: "design", sourceStoryId: "shelf-luke-17-pro-level-painting-essentials")`
- **Related collections:** None authored
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Plastic Canvas, Leak Proof, 9x12 ft., PK10 | The Tools Man | $479.99 | — | [Image](https://cdn.shopify.com/s/files/1/0611/6609/2465/files/Z_uu5vkcpEx_99f3e7f7-42b3-4aa9-ac82-f0eda0045e41.jpg) | `shelf-shop-the-tools-man-a7f94d7` / `6356290083489300799` |
| 2 | Heavy Duty Canvas Drop Cloth For Painting And Home Projects, Cotton Duck Tarp Protects Floors, Furniture, Curtains, Tables, And Backdrops, Washable And Reusable Dust Sheet, Floor Cover, 4 Piece Set, 4 By 15 Feet | VXB Bearings | $173.95 | — | [Image](https://cdn.shopify.com/s/files/1/0662/3268/0683/files/71rpkaCOHOL.jpg) | `shelf-shop-vxb-bearings-b59f981` / `705055298078391351` |
| 3 | Repaint Studios Repaint Tray Metal 11.5 in. W X 16 in. L 1 qt Paint Tray Set (Pack of 5) | Max Warehouse | $162.75 | — | [Image](https://cdn.shopify.com/s/files/1/1405/6268/files/image_7cfa8fcc-7ee3-46fe-b27a-1aedd56f4bfd.jpg) | `shelf-shop-max-warehouse-597f8f9` / `1472477000213476607` |
| 4 | Handy Tek 1.5 gal 2-In-1 Gray Plastic Paint Tray - For Roller and Brush - 17 3/4" x 13" x 3" - 36 count box | Restaurantware | $149.65 | — | [Image](https://cdn.shopify.com/s/files/1/0785/3155/9744/files/RWT2133GR-MC-2-LR.jpg) | `shelf-shop-restaurantware-5015daf` / `5928223595067261091` |
| 5 | Alloyman 1050W Electric Drywall Sander with Vacuum, 7-Speed, 2100RPM | Alloyman | $139 | — | [Image](https://cdn.shopify.com/s/files/1/0746/4049/0804/files/1050WElectricDrywallSander-1.jpg) | `shelf-shop-alloyman-616a921` / `1404113596623275537` |
| 6 | ScotchBlue Sharp Lines Painter's Tape - 1.88 in x 60 yd, 12 Rolls, Edge-Lock | TaskHolt | $76.96 | — | [Image](https://cdn.shopify.com/s/files/1/0725/0598/3087/files/scotchblue-sharp-lines-painter-tape-edge-lock-technology.jpg) | `shelf-shop-taskholt-c68da47` / `5870311492681944385` |

<a id="shelf-luke-18-elevated-classics"></a>

## 18. Elevated Classics

Made in USA runners and iconic collab Dunks and Sambas

- **Category:** style
- **Shelf ID:** `shelf-luke-18-elevated-classics`
- **Shelf type:** trajectory · self persona
- **Price band:** $130–$260
- **App route:** `HomeRoute.topicExpanded(topicId: "style", sourceStoryId: "shelf-luke-18-elevated-classics")`
- **Related collections:** [Performance sneakers edit](#shelf-luke-10-performance-sneakers-edit) · [Race-Day And Daily Trainers](#shelf-luke-19-race-day-and-daily-trainers)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | New Balance 993 Made in USA | AFEW STORE | $229.99 | — | [Image](https://cdn.shopify.com/s/files/1/2718/4356/files/new-balance-mr-993-gl-grey-mr993gl-footwear_20_3E_20sneaker.jpg) | `shelf-shop-afew-store-45dd60a` / `1901147158835366865` |
| 2 | New Balance M990GL6 - Made in USA Men's Running Shoes Grey Suede/Mesh | Footwear etc. | $199.95 | — | [Image](https://cdn.shopify.com/s/files/1/0507/1349/3690/files/Autogenerated_b0c88d68027d44298623a0fb5d22f6e2.jpg) | `shelf-shop-footwear-etc-33fa114` / `5432880776547621152` |
| 3 | New Balance Made in USA 990v6 in Black | Todd Snyder | $200 | — | [Image](https://cdn.shopify.com/s/files/1/0186/1574/files/new-balance-made-in-usa-990v6-in-blacknew-balance-638607.jpg) | `shelf-shop-todd-snyder-ddb956e` / `2591328743845637797` |
| 4 | New Balance Mens Made In USA 993 Core Shoes | Extra Butter | $200 | — | [Image](https://cdn.shopify.com/s/files/1/0236/4333/files/MR993GL-1.jpg) | `shelf-shop-extra-butter-4dfaf3d` / `1918421493834371604` |
| 5 | Nike Dunk Low Retro Premium 'Light British Tan' Men's Shoes | Millennium Shoes | $129.99 | — | [Image](https://cdn.shopify.com/s/files/1/0297/2762/1253/files/AURORA_IB7746-201_PHSRH000-2000.jpg) | `shelf-shop-millennium-shoes-678d341` / `6129307147183494025` |
| 6 | Nike Dunk Low Retro SE 'Pale Ivory Baroque Brown' Men's Shoes | Millennium Shoes | $129.99 | — | [Image](https://cdn.shopify.com/s/files/1/0297/2762/1253/files/AURORA_FQ8249-104_PHSRH000-2000.jpg) | `shelf-shop-millennium-shoes-678d341` / `1385232634353115085` |
| 7 | Adidas Samba OG Fifa World Cup Argentina | Oneness Boutique | $110 | — | [Image](https://cdn.shopify.com/s/files/1/0187/5180/files/oneness-adidas-samba-og-fifa-world-cup-argentina-01.jpg) | `shelf-shop-oneness-boutique-f42af7f` / `7077750219738426832` |
| 8 | adidas Samba Bape World Cup Pack White Forest | The Last Step | $200 | — | [Image](https://cdn.shopify.com/s/files/1/0900/7834/7530/files/KJ8852-1.jpg) | `shelf-shop-the-last-step-a09d453` / `6816743935851899061` |

<a id="shelf-luke-19-race-day-and-daily-trainers"></a>

## 19. Race-Day And Daily Trainers

Carbon super shoes plus cushioned road and trail options

- **Category:** style
- **Shelf ID:** `shelf-luke-19-race-day-and-daily-trainers`
- **Shelf type:** decision · self persona
- **Price band:** $110–$300
- **App route:** `HomeRoute.topicExpanded(topicId: "style", sourceStoryId: "shelf-luke-19-race-day-and-daily-trainers")`
- **Related collections:** [Performance sneakers edit](#shelf-luke-10-performance-sneakers-edit) · [Elevated Classics](#shelf-luke-18-elevated-classics)
- **Page structure:** Hero → New this week → Featured deals (when available) → Best sellers → Top merchants (when available) → Related collections (when available) → Recent posts (when available) → Explore more

### Products

| # | Product | Merchant | Price | Signals | Links | App product key |
|---:|---|---|---:|---|---|---|
| 1 | Men's Vaporfly 4 | Mill City Running | $270 | — | [Image](https://cdn.shopify.com/s/files/1/0969/3046/4107/files/1_HF6414-112.png) | `shelf-shop-mill-city-running-3358fc4` / `1606573038044571537` |
| 2 | Men's Alphafly 3 Running Shoes In White/black-Volt-Barely Volt | NIO | $184 | — | [Image](https://cdn.shopify.com/s/files/1/0716/2164/0266/files/1aa02317557d46218f988f70afd156d3.jpg) | `shelf-shop-nio-b28dc9d` / `1175312343797521384` |
| 3 | Salomon Aero Glide 4 GRVL Mens Trail Running Shoes - White | Start Fitness | $216 | — | [Image](https://cdn.shopify.com/s/files/1/0564/9521/0704/files/Salomon-Aero-Glide-4-GRVL-L49174900.jpg) | `shelf-shop-start-fitness-f9ed665` / `1859956107200231107` |
| 4 | Salomon S/Lab Ultra Glide 2 Men's Trail Running Shoes | Ridge & River | $249.95 | — | [Image](https://cdn.shopify.com/s/files/1/0580/1295/8858/files/PNG-2000px-max-72dpi_41.webp) | `shelf-shop-ridge-river-a623c7f` / `4848730482042724034` |
| 5 | S/LAB Ultra Glide 2 - Unisex | Vancouver Running Company Inc. | $221 | — | [Image](https://cdn.shopify.com/s/files/1/0741/1015/files/s_labultraglide2croppedelad.png) | `shelf-shop-vancouver-running-company-inc-31c4128` / `8761182776701772665` |
| 6 | Salomon S/Lab Spectur Men's Road Running Shoes | Ridge & River | $219.95 | — | [Image](https://cdn.shopify.com/s/files/1/0580/1295/8858/files/PNG-2000px-max-72dpi_9a13bf50-fdfe-4cfb-b3d5-f048f3088e55.png) | `shelf-shop-ridge-river-a623c7f` / `9164147126189486421` |
| 7 | New Balance Fuel Cell SuperComp Elite V5 | Fit2Run | $199.95 | — | [Image](https://cdn.shopify.com/s/files/1/0878/6811/3205/files/MRCELLR5_203.png) | `shelf-shop-fit2run-fcb2caa` / `103979277804239604` |
| 8 | New Balance FuelCell SuperComp Elite v6 Men | Snoqualmie Running | $275 | — | [Image](https://cdn.shopify.com/s/files/1/0756/1959/8641/files/rs-2026-07-24T230240.393.webp) | `shelf-shop-snoqualmie-running-d002b4d` / `4248737246144516903` |
