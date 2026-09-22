# CEO demo candidate — 2026-09-16

## Working copy

- Directory: `/Users/lukedupont/bento-shop-feed-ceo-demo`
- Branch: `ceo-demo-hardening`, based on public `main` at `c92a7dc`.
- Existing working copies and their uncommitted changes were not modified.
- This is a focused demo-hardening pass, not a redesign or production-commerce implementation.

## Changes

- Catalog search tokenizes each merchant snapshot once and reuses the index across suggested collections/custom feeds. Existing relevance weights, synonyms, ranking, and assortment are retained.
- Feed plans compare complete immutable inputs instead of IDs/product counts, with a bounded eight-entry cache for returning to recently visited feeds.
- Bundled merchants and the supplemental catalog merge are reused instead of repeatedly decoded/reassembled during view evaluation.
- Returning to bundled feed data publishes a revision so Home refreshes its lookup graph.
- Reused image cells clear a previous product's image while the new URL loads. Prefetching cancels obsolete batches when leaving/changing the feed.
- Reused video surfaces update their source and pause autoplay while the scene is inactive or Reduce Motion is enabled.
- Cart and Favorites now route to their existing prototype pages instead of a blank root. Bottom tabs have accessibility names and stable identifiers.
- Local environment files are copied only for Debug; all other configurations remove a prior copy and reject environment files/test runtimes in the product.
- Added version `1.0` / build `1`, plus a reproducible Release artifact script.
- Only the six used GT Standard fonts ship. Unused kit font files remain in source, excluded from the target. The validator verifies the actual Info.plist font manifest.
- Added hosted data/state regression tests and UI smoke tests. The existing shipping size budget remains 180 MiB. Apple-injected Debug test runtimes are reported separately rather than charged to the shipping app budget.

## Verification

- Personalized-feed validation passed: 11 base topics, 31 base stories, 340 base catalog products, and 287 frozen media files. Supplemental buyer catalogs are additional to those base counts.
- Eight data/state tests and two UI tests passed twice: **20 executions, no failures**.
- UI checks exercise lead collection open/close and Home → Cart → Favorites → Home.
- The first UI run caught a source-view state mutation during a shared zoom. The cancellation path no longer clears observed view state on disappearance. The corrected transition then passed the targeted run and both full-suite repetitions.
- Debug app budget passed with test-runner overhead separately accounted for.
- iPhone Release archive succeeded. The final archived app occupies **136,896 KiB (~134 MiB)** after archive stripping, below the unchanged 180 MiB budget.
- Archive inspected: iPhoneOS, minimum iOS 26.0, version 1.0 (1), six fonts, no ShopServer.env, no XCTest framework.
- Final Release simulator build and artifact copy succeeded; the simulator candidate was installed, launched, and visually inspected.
- One warm Release build/artifact cycle took **13.34 seconds**, including validation, Xcode, cached media copying, and artifact copying.
- After Home settled, simulator `footprint` reported **68 MB physical footprint / 86 MB process peak**. This is a resting Home sample, not a scrolling stress test or a physical-iPhone measurement.
- Shell syntax and `git diff --check` passed.
- Synthetic Debug → Release and Debug → AdHoc checks confirm developer environment files are removed without reading real credentials.

## Video-first For You edit — build 2

Luke's For You feed now opens with these five existing video-led stories:

1. Warm designer lighting (`warm-designer-lighting.mp4`)
2. Streetwear staples from caps to tees (`streetwear-staples.mp4`)
3. Sculptural Living Room Pieces (`sculptural-living-room.mp4`)
4. Your performance sneaker edit (`stadium-sneakers.mp4`)
5. Stylish travel essentials (`olend-travel.mp4`)

The demo-only ordering lives in `HomeFeedPlanner`. It runs after mixed-format
and campaign insertion so those formats cannot interrupt the opening. The
story/prefetch order is kept aligned. Existing cards are moved, not duplicated
or fabricated; explicit card-type switches remain respected. Other buyers,
topic feeds, custom feeds, and the utility rail retain their previous behavior.

Placing video Worlds next to each other exposed an existing oversized hit area:
clipping a lifted offscreen foreground did not prevent it intercepting taps on
the card above. `StoryFeedCard` now constrains interaction to the same shape as
its visible card. The lead and second video World are covered by UI navigation
checks, alongside data tests for the five-card prefix, real video resources,
scoping, and composition settings.

Verification: all **14 tests passed twice (28 executions)**. The signed Release
build **1.0 (2)** passed signature/resource checks and was installed over build 1
on Luke's iPhone, then successfully launched. The current signed artifact is
`DemoArtifacts/ShopFeedSummer26-iPhone.app`; build 1 is retained as
`DemoArtifacts/ShopFeedSummer26-iPhone-build1.app`. The earlier unsigned archive
and Release simulator artifact remain build 1; the running simulator preview
uses the tested build 2 Debug product. Installation/launch JSON and the updated
test summary are in `DemoArtifacts/Verification/`.

## Performance measurement (initial hardening build 1)

Measured on the same fresh iPhone 17 Pro / iOS 26.5 simulator, using Release builds. Timing runs from `simctl launch` to a screenshot containing the unchanged Home gift-guide CTA; it **includes simulator and screenshot-tool overhead**, not just app execution. Three process launches per variant, with persistent simulator caches left intact.

| Variant | Launch samples (seconds) | Median |
| --- | --- | --- |
| Original main, Release | 4.380, 3.490, 4.320 | 4.320 s |
| Search indexing only, Release | 3.555, 3.139, 3.007 | 3.139 s |
| Final candidate, Release | 3.733, 2.799, 2.826 | 2.826 s |

The final candidate improved this check by about **35%** versus the original main. The exploratory two-second end-to-end harness target was **not** reached; its recorded `passed: false` is retained rather than weakening the target. No physical-device frame-rate or launch-time claim is made.

A screenshot, measurement JSON, and the test summary are preserved in `DemoArtifacts/Verification/`. Local raw profiles, full test logs, the fixture-specific timing harness, and `.xcresult` files are in `/tmp/bento-ceo-performance/`. Performance numbers should be rechecked on the intended physical phone before a live presentation.

## Artifacts and commands

```sh
Scripts/build_demo.sh simulator <exact-simulator-UUID>
Scripts/build_demo.sh archive-unsigned
```

Artifacts are in ignored `DemoArtifacts/`:

- `ShopFeedSummer26-Simulator.app` — Release simulator app; not an iPhone install.
- `ShopFeedSummer26-Unsigned.xcarchive` — device archive, **not installable until signed/provisioned**.

Use `BUILD_NUMBER=<number>` to increment the build for a subsequent distribution. `DERIVED_DATA_PATH` and `SOURCE_PACKAGES_DIR` can reuse existing local build/package caches.

Tests:

```sh
xcodebuild -project ShopFeedSummer26.xcodeproj -scheme ShopFeedSummer26 \
  -destination 'platform=iOS Simulator,id=<exact-simulator-UUID>' \
  -parallel-testing-enabled NO test
```

## Direct install on Luke’s phone — 2026-09-16

- Built and signed the optimized Release app with the existing Apple Development identity and an automatically generated profile for the paired iPhone 16 Pro (iOS 26.5.2).
- Installed **Shop Feed Summer 26 1.0 (1)** over the existing bundle ID using CoreDevice. No uninstall or app-data reset was performed.
- Verified the signature recursively, the signed application/team identities against the embedded profile, and inclusion of the connected device in that profile.
- The first launch required developer trust. After Luke trusted the developer entry, CoreDevice successfully launched the app in the foreground; a follow-up process check confirmed it remained running. On-device interaction/performance checks still require using the phone.
- This personal development profile expires **2026-09-23 at 18:37:46 UTC**. Re-sign/reinstall after expiration. It is not a general-purpose distribution build for other phones.
- Signed local artifact: `DemoArtifacts/ShopFeedSummer26-iPhone.app`. Installation and launch results are in `DemoArtifacts/Verification/phone-install.json`, `phone-launch.json` (initial trust failure), and `phone-launch-trusted.json` (successful launch).

## Before sending to the CEO

1. Choose TestFlight or a direct development/ad-hoc installation. The archive is deliberately unsigned; no upload or provisioning changes have been performed.
2. Select the correct Apple developer team and provisioning/distribution method. A local Apple Development identity exists, but that alone is not a TestFlight distribution setup.
3. Install the signed candidate on the intended iPhone and check Home, vertical/horizontal scrolling, a collection drill-in/Close, and returning from the bottom tabs.
4. Keep a reliable network connection for remote merchant imagery. Bundled feed data opens without an account, but not every CDN image is bundled.
5. Leave experimental Worlds disabled unless their required setup has been verified. Live camera/AI generation needs a safe authenticated token endpoint/session; developer proxy keys do not ship in Release. These workflows were not exercised by this pass.

Existing camera-SDK Sendable/actor-isolation and API-deprecation warnings remain. This pass does not attempt a Swift 6 concurrency migration or certify the unexercised live-camera path.

Cart/Favorites now display their existing prototype empty states; this pass does not add checkout, cart persistence, or a cross-screen favorites backend. Some feedback/share controls remain intentionally local-only prototype interactions. Do not present the candidate as production-complete commerce.
