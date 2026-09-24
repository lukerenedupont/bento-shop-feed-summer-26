# Shop Library Preview handoff

Updated: 2026-09-23. This document describes the active library experiment,
not the older personalized-feed/phone demo.

## Start here

- Branch: `experiment/shop-agent-world-lab`.
- Shareable repository: https://github.com/lukerenedupont/bento-shop-feed-summer-26
  (the original public repository, published here at the user's explicit direction).
- `origin` is the public handoff destination. `private-backup` retains the prior
  private checkpoint; it is not required for teammates to clone this branch.
  Public visibility does not establish additional source or media reuse rights.
- The branch includes the shared feed/World/navigation refactor and the Norda
  price-research World. Keep this history; the original phone demo is preserved
  separately. No phone installation is needed for this handoff.

## Run on another Mac

Use Xcode 26.5 with an iOS 26 simulator (the tested configuration), Git, and
Python 3. Xcode resolves the pinned Swift packages; JulianAgentUI is vendored.
The Xcode project is committed. Install XcodeGen only when regenerating it
with `xcodegen generate` after adding/removing Swift files or changing project
configuration.

```sh
git clone --depth 1 --branch experiment/shop-agent-world-lab \
  https://github.com/lukerenedupont/bento-shop-feed-summer-26.git
cd bento-shop-feed-summer-26
xcrun simctl list devices available
# Replace this with an available iOS 26 simulator's exact UUID on your Mac.
export SIMULATOR_ID='YOUR-EXACT-SIMULATOR-UUID'
Scripts/run_library_preview.sh home
```

The launcher validates, builds, installs and opens the preview. `host` and
`self-care` are alternate destinations. Without an override it uses Luke's
Bento Architecture Review simulator, `A802FE07-B2DD-4AE9-9B6F-8D99335BD1D8`.
Bundle ID: `com.shopify.purl.prototype.shop.feed.library.preview`.

The normal library/Norda journey needs no private credentials, backend,
external source checkout, or price re-import. Catalog data and fallback media
are committed. Internet is needed for package resolution, remote product
images, cover video and source pages. Optional generation/camera integrations
have separate service/hardware requirements and are not established end-to-end
by the library smoke tests. Keep local credentials in ignored `.env.local`;
never put them in a commit or shared app artifact.

## What is implemented

- First For You card: **Your trail-running price edit**. Same muted 8-second
  Norda 055 loop in the card and compact World header, with shared native zoom,
  actual first-frame fallback, offscreen/background pause and motion/power policy.
- Seventeen sourced USD offers across six merchants; exact model/color/available
  US men's size comparison. Shipping/rating modes disclose missing evidence.
- Fixed product-card geometry, native PDP/back and merchant source sheets,
  persistent product hearts/preferences, and Julian's continuously mounted dock.
- One confirmed-Shopify publication path for feed, search, products, merchants
  and Ask context: 230 products / 83 merchants. Base source snapshot is immutable.
- Shared feed presentation, finite editorial recipes, and navigation-owned
  shopping context. Existing interactive Worlds remain in the project.

This is an authored, locally persistent price snapshot. Live research jobs,
monitoring, price history, conversation-generated artifacts, account sync and
comparable delivery/rating rankings are not implemented. Editorial media is
internal-reference-only, not permission-cleared for production redistribution.

## Work in the existing seams

- `HomeFeedPlanner` / `FeedCardPresentation` / `StoryFeedCard`: feed ordering and
  finite presentation. `TopicDetailPage` remains the shared World host.
- `NavigationCoordinator`: canonical routes and Ask context; keep product/back
  behavior here rather than repairing context in destination lifecycle hooks.
- `Worlds/ShoppingResearch.swift`: source-backed offer/catalog model.
  `ShoppingResearchContent.swift` and `ResearchMerchantComparison.swift`: UI.
- `ResearchCoverFilm.swift` and `Components/LoopingVideoPlayer.swift`: shared
  bounded movie playback. Film provenance is in
  `LibraryAssets/catalog/research-media/cover-film.json`.
- `Scripts/import_running_research.py`: deliberate live refresh, not a build
  dependency. Changing availability can invalidate fixture-specific tests.
  Preserve source checks and review refreshed observations before committing.

Keep unknown prices as “Price at shop,” the confirmed-Shopify gate, reviewed
media associations, minimal copy, heavy shared headings, square offer images,
visible products on arrival and native navigation. Retain the vendored dock
and interactive experiences; older Canvas/Try-on adapters still need dedicated
hardening rather than being silently republished.

## Verify before handing off

```sh
python3 -m unittest discover -s Scripts -p 'test_*import.py'
python3 Scripts/validate_shop_canvas_snapshot.py ShopFeedSummer26/LibraryAssets
xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath .build/Tests -clonedSourcePackagesDirPath .build/SourcePackages \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES SWIFT_OPTIMIZATION_LEVEL=-O \
  -only-testing:ShopFeedSummer26Tests \
  -only-testing:ShopFeedSummer26UITests/LibrarySmokeTests test
Scripts/run_library_preview.sh home
git diff --check
```

Keep shipping and hosted-test derived-data directories separate. Test runtime
injection is not shipping size. The build enforces **184,320 KB**; preserve that
limit. Five existing clips are compressed, the new full cover film stays
remote, and an unused Try Faves cutout was removed. Active avatar/environment
assets remain. Further meaningful size/performance work needs measurement,
not wholesale deletion of existing experiences.

Current measured build size and verification results are in
[`LIBRARY_PREVIEW.md`](LIBRARY_PREVIEW.md). Read
[`docs/NORDA_WORLD_MEDIA_RESEARCH.md`](docs/NORDA_WORLD_MEDIA_RESEARCH.md) for
source provenance, film refresh/expiry, rights and commerce evidence;
[`CONTEXT.md`](CONTEXT.md) for World terminology; and
[`ARCHITECTURE.md`](ARCHITECTURE.md) before changing shared boundaries.
