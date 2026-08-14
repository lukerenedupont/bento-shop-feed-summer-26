# Pre-dossier card data

This directory preserves the feed and merchant/product payload that powered the
cards before Home switched to `dossier-feed-bundle`.

- `pre-dossier-feed.json` — original topics, stories, and each story's product references.
- `pre-dossier-merchants.json` — original merchant and full product records joined by those references.

The same payload remains compiled in `Assets.xcassets` as the app's offline
fallback. These explicit copies are kept outside the asset catalog so the old
card contents are easy to inspect, diff, or restore without extracting an
`NSDataAsset`.
