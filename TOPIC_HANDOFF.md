# Personalized Feed Topics

This is the simple handoff list for the 10 personalized content topics currently being built for Luke.

## How to use this file

- Treat each numbered section as one **content world / jumping-off point**, not a merchant shelf.
- Use the **Why it is showing** section as the relevance signal for the visual or graph.
- Product links below are real merchant PDPs.
- The stable graph key for a product is `merchantID + productID`.
- Merchants and products may appear in more than one topic when the context is meaningfully different.
- The separate **Keep shopping** card is retargeting infrastructure, not one of these 10 editorial topics.
- Each topic's lead story carries a `coverImageName` (`cover-birding`, `cover-coffee-counter`, …) that renders as both the Made for You card atmosphere and the topic header background. Source art is in `covers/<topic>/` — use the highest version (`v3` over `v2` over `v1`), downscale to ~2200px JPEG, and drop it into `Assets.xcassets/cover-<topic>.imageset/`. The validator enforces that covers and stories stay in sync.

---

## 1. City-to-trail birding

**Feed title:** A field kit for city-to-trail birding  
**Why it is showing:** Luke recently searched for “bird watching” and “bird watching binoculars.” The footwear connection comes from his sustained interest in trail-to-lifestyle Salomons.  
**Relevant merchants:** Nocs Provisions, Feature, Extra Butter

### Products

- [Pro Issue 8x42 Waterproof Binoculars](https://nocsprovisions.com/products/pro-issue) — Nocs Provisions  
  `merchantID: nocs` · `productID: 10432692846871`
- [Zoom Tube 8x32](https://nocsprovisions.com/products/zoom-tube-8x32-monocular-telescope) — Nocs Provisions  
  `merchantID: nocs` · `productID: 6591770722382`
- [XT-6 GTX — White/White/Footwear Silver](https://feature.com/products/salomon-xt-6-gtx-white-white-ftw-silver) — Feature / Salomon  
  `merchantID: feature-salomon` · `productID: 7029064368199`
- [Salomon XT-Quest](https://extrabutterny.com/products/salomon-mens-xt-quest-shoes-l49125800) — Extra Butter / Salomon  
  `merchantID: extra-butter-salomon` · `productID: 8151144530103`

---

## 2. Sculptural mirror hunt

**Feed title:** Four mirrors that change the whole wall  
**Why it is showing:** Mirrors are one of Luke’s deepest active hunts. He has an Amorphous Mirror in his Forom cart and recently searched for an amorphous wavy wall mirror.  
**Relevant merchants:** Forom, Coming Soon

### Products

- [Lemieux Et Cie Amorphous Mirror Collection](https://foromshop.com/products/lemieux-et-cie-amorphous-mirror-collection) — Forom  
  `merchantID: forom` · `productID: 7914833051779`
- [Elyse Wall Mirror — Mahogany](https://foromshop.com/products/elyse-wall-mirror-mahogany) — Forom  
  `merchantID: forom` · `productID: 9080102322307`
- [Jelly Mirror](https://comingsoonnewyork.com/products/jelly-mirror) — Coming Soon  
  `merchantID: coming-soon` · `productID: 9908030275890`
- [Gemini Mirror](https://comingsoonnewyork.com/products/gemini-mirror-5) — Coming Soon  
  `merchantID: coming-soon` · `productID: 9603148841266`

---

## 3. Type systems

**Feed title:** Type systems worth keeping nearby  
**Why it is showing:** Luke repeatedly browses and carts authoritative graphic-design manuals, typography references, transit graphics, and independent design publications.  
**Relevant merchants:** Standards Manual, Draw Down

### Products

- [NYCTA Graphics Standards Manual — Compact Edition](https://standardsmanual.com/products/nyctacompactedition) — Standards Manual  
  `merchantID: standards-manual` · `productID: 1424479363`
- [NASA Graphics Standards Manual](https://standardsmanual.com/products/nasa-graphics-standards-manual) — Standards Manual  
  `merchantID: standards-manual` · `productID: 5842516163`
- [Theory of Type Design](https://draw-down.com/products/theory-of-type-design) — Draw Down  
  `merchantID: draw-down` · `productID: 1591926554714`
- [New Aesthetic 1](https://draw-down.com/products/new-aesthetic-1-a-collection-of-experimental-and-independent-type-design) — Draw Down  
  `merchantID: draw-down` · `productID: 8336413458686`

---

## 4. Coffee counter

**Feed title:** Precision brewing without the visual noise  
**Why it is showing:** Luke repeatedly engages with Fellow’s Aiden, Stagg kettle, tasting glasses, and Carter mug, and recently searched for a coffee grinder. He values a precise workflow and coherent countertop design.  
**Relevant merchants:** Fellow, KINTO

### Products

- [Aiden Precision Coffee Maker](https://fellowproducts.com/products/aiden-precision-coffee-maker) — Fellow  
  `merchantID: fellow` · `productID: 7507479003236`
- [Stagg EKG Electric Kettle](https://fellowproducts.com/products/stagg-ekg-electric-pour-over-kettle) — Fellow  
  `merchantID: fellow` · `productID: 2055410221171`
- [SCS-S02 Coffee Server, 2 cups](https://kinto-usa.com/products/27576) — KINTO  
  `merchantID: kinto` · `productID: 2214011961392`
- [KRONOS Double Wall Coffee Cup, 250 ml](https://kinto-usa.com/products/23108) — KINTO  
  `merchantID: kinto` · `productID: 2214023331888`

---

## 5. Tabletop objects

**Feed title:** Objects that make the table stranger  
**Why it is showing:** Luke has a deep interest in ceramic vessels, tactile tabletop pieces, and playful art objects, as long as they still have a strong material or design point of view.  
**Relevant merchants:** DOIY, MoMA Design Store

### Products

- [Goldfish Vase](https://doiydesign.com/products/goldfish-vase) — DOIY  
  `merchantID: doiy` · `productID: 8491003314332`
- [Sun Vase](https://doiydesign.com/products/sun) — DOIY  
  `merchantID: doiy` · `productID: 8300748931228`
- [Virgil Abloh Conversational Objects Flatware](https://store.moma.org/products/virgil-abloh-conversational-objects-flatware-set-of-4) — MoMA Design Store / Alessi  
  `merchantID: moma` · `productID: 8909829603558`
- [Alessi Vite 3-Cup Stovetop Espresso Maker — Red](https://store.moma.org/products/alessi-vite-3-cup-stovetop-espresso-maker-red) — MoMA Design Store  
  `merchantID: moma` · `productID: 9787655160038`

---

## 6. Design for kids

**Feed title:** A nursery that still feels like your home  
**Why it is showing:** Luke has sustained, high-intent activity around Babyletto, Lalo, Stokke, and Cozoni. The specific need is safe, practical child gear that remains coherent with a considered adult interior.  
**Relevant merchants:** Babyletto, Lalo

### Products

- [Swell Changing Table](https://babyletto.com/products/swell-changing-table) — Babyletto  
  `merchantID: babyletto` · `productID: 7652167942198`
- [Yuzu 8-in-1 Convertible Crib](https://babyletto.com/products/yuzu-8-in-1-convertible-crib-with-all-stages-r-conversion-kits) — Babyletto  
  `merchantID: babyletto` · `productID: 6867000164406`
- [The Chair](https://meetlalo.com/products/the-chair) — Lalo  
  `merchantID: lalo` · `productID: 4363480432704`
- [The Booster](https://meetlalo.com/products/the-booster) — Lalo  
  `merchantID: lalo` · `productID: 6603936137280`

---

## 7. Trail to street

**Feed title:** Salomons that work after the trail ends  
**Why it is showing:** Luke has sustained interest in Salomon, New Balance, Hoka, running, walking, and trail-to-lifestyle footwear. Neutral palettes and clear use-case distinctions are especially relevant.  
**Relevant merchants:** Feature, Extra Butter, Salomon

### Products

- [XT-6 GTX — White/White/Footwear Silver](https://feature.com/products/salomon-xt-6-gtx-white-white-ftw-silver) — Feature / Salomon  
  `merchantID: feature-salomon` · `productID: 7029064368199`
- [XT-4 OG — Black/Ebony/Silver Metallic](https://feature.com/products/salomon-xt-4-og-black-ebony-silver-metallic) — Feature / Salomon  
  `merchantID: feature-salomon` · `productID: 6753846919239`
- [Salomon XT-Quest](https://extrabutterny.com/products/salomon-mens-xt-quest-shoes-l49125800) — Extra Butter / Salomon  
  `merchantID: extra-butter-salomon` · `productID: 8151144530103`
- [Salomon XA Pro 3D GTX](https://extrabutterny.com/products/salomon-mens-xa-pro-3d-gtx-shoes-l49111700) — Extra Butter / Salomon  
  `merchantID: extra-butter-salomon` · `productID: 8349773922487`

---

## 8. New York graphics

**Feed title:** New York graphics, off the wall  
**Why it is showing:** New York, transit identity, typography, city imagery, music, and graphic headwear recur throughout Luke’s profile. This topic deliberately connects books, objects, accessories, and publishing rather than staying in one retail category.  
**Relevant merchants:** Standards Manual, Lichen, MoMA Design Store, Draw Down

### Products

- [NYCTA Graphics Standards Manual — Compact Edition](https://standardsmanual.com/products/nyctacompactedition) — Standards Manual  
  `merchantID: standards-manual` · `productID: 1424479363`
- [OUR FLOORS ARE UNEVEN](https://lichennyc.com/products/our-floors-are-uneven-1) — Lichen  
  `merchantID: lichen` · `productID: 11009838154046`
- [Swatch Neon Flumotions Watch](https://store.moma.org/products/swatch-neon-flumotions-watch) — MoMA Design Store  
  `merchantID: moma` · `productID: 9604489248998`
- [Designing Type Revivals](https://draw-down.com/products/designing-type-revivals) — Draw Down  
  `merchantID: draw-down` · `productID: 7804062892286`

---

## 9. Scalp reset

**Feed title:** A scalp-first reset for the full week  
**Why it is showing:** Luke repeatedly views and carts Ceremonia products for scalp health, anti-frizz repair, leave-in conditioning, and wash-day accessories. This is a regimen story rather than a generic beauty shelf.  
**Relevant merchants:** Ceremonia

### Products

- [Papaya Scalp Scrub](https://ceremonia.com/products/scalp-scrub) — Ceremonia  
  `merchantID: ceremonia` · `productID: 7219216580772`
- [Guava Leave-In Conditioner](https://ceremonia.com/products/guava-leave-in-conditioner) — Ceremonia  
  `merchantID: ceremonia` · `productID: 6060165300388`
- [Dry Shampoo con Arrowroot](https://ceremonia.com/products/dry-shampoo-con-arrowroot) — Ceremonia  
  `merchantID: ceremonia` · `productID: 14886355796337`
- [Hair Towel](https://ceremonia.com/products/hair-towel) — Ceremonia  
  `merchantID: ceremonia` · `productID: 15369056321905`

---

## 10. Black and silver material study

**Feed title:** Black, silver, and one electric signal  
**Why it is showing:** Luke consistently responds to black, silver, chrome, strong proportions, and material honesty across otherwise unrelated categories. This is a taste-based adjacency story rather than a category.  
**Relevant merchants:** House of Leon, MoMA Design Store, Fellow, Feature

### Products

- [Chair #1 — Black Leather](https://houseofleon.com/products/gordon-chair-black-leather) — House of Leon  
  `merchantID: house-of-leon` · `productID: 7873592721581`
- [Swatch Neon Flumotions Watch](https://store.moma.org/products/swatch-neon-flumotions-watch) — MoMA Design Store  
  `merchantID: moma` · `productID: 9604489248998`
- [Stagg EKG Electric Kettle](https://fellowproducts.com/products/stagg-ekg-electric-pour-over-kettle) — Fellow  
  `merchantID: fellow` · `productID: 2055410221171`
- [XT-4 OG — Black/Ebony/Silver Metallic](https://feature.com/products/salomon-xt-4-og-black-ebony-silver-metallic) — Feature / Salomon  
  `merchantID: feature-salomon` · `productID: 6753846919239`

---

## Separate retargeting card: Keep shopping

This is not one of the 10 editorial topics. It is a behavioral module using recent views, carts, favorites, and active hunts.

Current examples:

- [Forom Amorphous Mirror](https://foromshop.com/products/lemieux-et-cie-amorphous-mirror-collection)
- [Ceremonia Dry Shampoo](https://ceremonia.com/products/dry-shampoo-con-arrowroot)
- [Swatch Neon Flumotions Watch](https://store.moma.org/products/swatch-neon-flumotions-watch)
- [Fellow Aiden](https://fellowproducts.com/products/aiden-precision-coffee-maker)

## Source files

- Feed definitions: `ShopFeedSummer26/Assets.xcassets/personalized-feed.dataset/personalized-feed.json`
- Product and merchant data: `ShopFeedSummer26/Assets.xcassets/prototype-merchants.dataset/prototype-merchants.json`
- Feed architecture: `ARCHITECTURE.md`
- Data validation: `Scripts/validate_personalized_feed.py`
