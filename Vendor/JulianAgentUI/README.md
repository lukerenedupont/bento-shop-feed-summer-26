# Julian Agent UI — internal source port

Source: `Shopify/shop-client`, branch `feature/agent-vision-prototype-refresh`,
commit `79849f634b495df011aeefc0c4ef04a7180e633d`.

**Internal review only. This includes source from a private Shopify repository.
Do not publish this vendor directory to the public feed repository without authorization.**
No source has been pushed or uploaded by this integration.

## Ownership

- `Sources/JulianAgentUI/Upstream/` contains the original UI, motion, state and
  rendering code. Some complete declarations are extracted from larger production
  integration files. Extraction boundaries and original SHA-256 values are in
  `source-manifest.json`.
- `Gravity/` is the original Gravity component/token/icon resource module.
- `AppIcons/` contains all 14 original Icon Composer bundles.
- Nuke is pinned to the same `13.0.6` dependency used by the source branch.
- `JulianNavigationHost.swift`, `JulianShellState.swift`, `JulianSearchHeader.swift`
  and `StandaloneDependencies.swift` are **local adapters**, not Julian's source.
  They bind this app's navigation, catalog context and session drafts to the
  imported UIKit owner. The search result cards remain the library's shared cards.

## Preserved source behavior

Rodeo/Pistons geometry, tab scrubbing and long-press, tab/composer dock swaps,
native glass and shadows, first-interaction prompt/shimmer, UIKit keyboard
positioning, compact/expanded input, context lane, source Ask toolbar and curtain,
follow-up input, starter unfurl/glass, full/chip/floating/tab-bar search controls,
settings/reset and alternate-icon picker.

The library's empty cart is supplied as empty; there is no fabricated cart badge.
The source intentionally hides the cart target in that state and uses its empty-cart
chat placement. Native Agent responses, history, image uploads and production
account actions are **not connected**. Draft text is retained; opening the transcript
boundary explicitly reports that nothing has been sent. No mock assistant answers
are generated. Catalog starter titles/images are data fixtures from the curated
selection, not fetched Agent recommendations or invented order history.

## Source adaptations

- Package/module boundaries and visibility of extracted private declarations.
- `ShopFoundation` String utilities provided by the standalone adapter.
- The original remote-image URL builder also accepts the library's bundled `file:`
  URLs; Nuke already provides the file-data loading path.
- Account/avatar/cart data and route actions supplied by the host rather than
  production Shop session stores.
- The source search UITextField honors the host's disabled environment while
  obscured by Ask; otherwise it can reclaim first responder from the composer.
- The native composer remains authoritative over text/selection while editing.
  Replaying a lagging adapter render snapshot was deleting/reordering keystrokes.
  This is a state-synchronization change, not a layout, styling or motion change.

## Validation status

The imported component test suite passes: 26 tests, with parametrized width/style
cases. One production route/history-owner test is compile-gated because that
owner is not imported. Tests run serially because they create UIKit windows.

App tests verify settings access, both navigation layouts, all search placements,
local search and PDP routing. The existing World/post/merchant walkthrough passes
when its tap targets are scrolled clear of the persistent composer.

The keyboard-focus and stale-text handoff regressions are fixed and the targeted
UI test passes: type, close, reopen with exact text retained, enter the source
follow-up input and return. Temporary diagnostic logging has been removed.
Final regression: **59 passed, 0 failed, 3 intentionally skipped legacy fixtures**
(62 reported tests). This includes the imported component suite and all 8 app UI
tests. Reset is also checked across app relaunch. Results:
`/tmp/julian-port-final2.xcresult`; screenshots and summary:
`DemoArtifacts/Verification/julian-source/` in the app worktree.

Build uses optimized Debug (`SWIFT_OPTIMIZATION_LEVEL=-O`) so the complete source
UI and icons fit the unchanged 180 MiB app budget. Last successful size check:
182276 KiB excluding injected XCTest runtimes (limit: 184320 KiB). No new Release or phone
artifact has been validated.
