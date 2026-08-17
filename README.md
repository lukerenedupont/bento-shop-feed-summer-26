# Shop Feed Summer 26

**A personalized, editorial home feed for the Shop app** — opening Shop feels
like opening a magazine written about your own taste, that you can buy from.

Instead of an algorithmic product grid, the feed turns real shopper signals
(searches, carts, sustained interests) into a small set of curated **content
worlds** — "City-to-trail birding" because you searched for binoculars,
"Sculptural mirror hunt" because a mirror is sitting in your cart. Each world
is a magazine-cover card in the For You feed, backed by a topic destination
with intent-grouped merchandising and real products from real merchants.

Next phase (planned, scaffolding in place): **Shopping as a Bento** — topic
pages become packed boxes of role-based compartments brought alive by ambient
product films. See [Roadmap](ARCHITECTURE.md#roadmap-shopping-as-a-bento).

Project: Prototypes  
Runtime: Swift  
Status: Draft  
Visibility: Local  
Owner: Luke Dupont  
Source: Swift / shop-prototype-kit

## Documentation map

| Doc | What it covers |
| --- | --- |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Data schema, component boundaries, navigation model, validation, catalog depth, bento/dossier roadmap |
| [`TOPIC_HANDOFF.md`](TOPIC_HANDOFF.md) | The 10 editorial topics: why each shows, its merchants, and stable product keys |
| [`VISUALS_PLAN.md`](VISUALS_PLAN.md) | Cover art direction and visual treatment plan |
| `Scripts/` | Validation (`validate_personalized_feed.py`), catalog deepening (`deepen_catalog.py`), cover color sampling (`extract_cover_color.swift`) |

## Getting Started

```bash
git clone https://github.com/apx303/bento-shop-feed-summer-26.git
git clone https://github.com/apx303/dossier-feed-bundle.git
cd bento-shop-feed-summer-26
open ShopFeedSummer26.xcodeproj   # committed — no generation step needed
```

Keep both repositories in the same parent directory. The Xcode project embeds
`../dossier-feed-bundle/bundle` as a folder reference so the complete generated
image and video library ships in the prototype without duplicating media here.

Select the **ShopFeedSummer26** scheme and run on an iOS 26 simulator. Everything
works offline out of the box: the app falls back to the bundled catalog
(`prototype-merchants.json`, 340 real products) when no Shop Server token is present.

- **Project regeneration** (only needed if you change `project.yml`):
  `xcodegen generate` (`brew install xcodegen`)
- **Data validation** (runs automatically as a pre-build phase):
  `Scripts/validate_personalized_feed.py`
- **Catalog deepening** (re-pull real merchant inventory from their storefronts):
  `Scripts/deepen_catalog.py`
- **Dossier content** (Deep Dive payloads + ambient films): drop files into
  `ShopFeedSummer26/Dossiers/` — see the "Dossier drop zone" section in
  [`ARCHITECTURE.md`](ARCHITECTURE.md)
- **Cover source art** lives outside the repo (`covers/`, gitignored); the app
  bundles downscaled versions in `Assets.xcassets/cover-*.imageset`

## Setup Notes

- Shop Prototype Kit SwiftUI project generated with XcodeGen.
- Kit cache: /Users/lukedupont/Purl/Caches/shop-prototype-kit
- Kit revision: 6ebcceb1d5fc0d7ed2b4352b45b350a530ed7f81
- Shop Server auth is optional and should live in this prototype's ignored `.env.local` file.

## Local Metadata

Purl writes prototype metadata to `purl.json` in this folder and indexes it from `~/Purl/purl-manifest.json`.

Runtime-specific metadata is stored in `purl.json`.

## Feed Development

See [`ARCHITECTURE.md`](ARCHITECTURE.md) for the personalized feed schema, component boundaries, validation command, and scaling plan. Run `Scripts/validate_personalized_feed.py` after editing catalog or story data.
