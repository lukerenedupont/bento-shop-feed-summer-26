# Shop Feed Summer 26

Project: Prototypes  
Runtime: Swift  
Status: Draft  
Visibility: Local  
Owner: Luke Dupont  
Source: Swift / shop-prototype-kit

## Getting Started

```bash
git clone <this repo>
open ShopFeedSummer26.xcodeproj   # committed — no generation step needed
```

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