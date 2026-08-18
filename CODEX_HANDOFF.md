# Codex handoff

Updated: 2026-08-18

## Repository state

- Repository: `/Users/lukedupont/bento-shop-feed-summer-26`
- Branch: `luke/feed-topic-polish`
- Last pushed commit: `a8191a6 Polish personalized feed merchant collections`
- The worktree is intentionally dirty. Preserve all current changes.
- Current modified files:
  - `ShopFeedSummer26/Navigation/HomeRoute.swift`
  - `ShopFeedSummer26/Navigation/NavigationCoordinator.swift`
  - `ShopFeedSummer26/Navigation/RootView.swift`
  - `ShopFeedSummer26/Pages/HomePage.swift`
  - `ShopFeedSummer26/Pages/StoryTopicPage.swift`
  - `ShopFeedSummer26/Pages/TopicLandingView.swift`

## Completed but uncommitted work

### Topic-view repair

- Prevent blank topic heroes while remote media loads.
- Pass verified merchant collection covers into story drill-ins.
- Preserve personalized topic context and sibling stories.
- Keep sibling switching inside Home when appropriate.
- Rotate sibling chips so the active item follows Back cleanly.
- Preserve the top-level personalized topic rail.

### Home-card shared-view transition repair

- Home feed cards use their story ID as the matched transition source.
- Expanded topics already use the same source ID and perform the expected
  system zoom.
- Fallback story routes now carry an optional `sourceId` so they bypass the
  inline-story interception and push through `NavigationStack`.
- `StoryTopicPage` consumes that explicit source ID for its zoom transition,
  while legacy subtopic entry points retain their `subtopic-*` source IDs.
- Forward zoom and return collapse were verified in Simulator.

## Verification state

- `git diff --check` passes.
- Personalized-feed validation passes: 11 topics, 31 stories, 340 catalog
  products, 10 covers, 0 dossiers, and 2 films.
- Simulator build succeeds with Xcode 26.5.
- Simulator ID: `286EAAB0-C6BC-41CB-A40C-B84318D400D8`
- Bundle ID: `com.shopify.purl.prototype.shop.feed.summer.26`
- Existing unrelated Swift warnings may remain.
- Do not commit or push unless Luke explicitly asks.

## Active task: Figma typography audit

Figma design:

`https://www.figma.com/design/C4BVYexQO4kVthmalsQIyw/Curation-Page-Improvements?node-id=1554-26674&t=e8oVOtI9cxjnbh1F-4`

The Figma MCP server was added globally and authenticated with OAuth:

- Name: `figma`
- URL: `https://mcp.figma.com/mcp`
- Status at handoff: enabled and authenticated
- A restarted/new Codex session is required to expose its tools.
- OAuth was refreshed successfully after the initial setup, but the original
  running session retained a stale MCP client. Restart Codex before inspection.

Next steps:

1. Inspect Figma node `1554:26674` directly through the Figma MCP tools.
2. Record the exact family, weight, size, line height, and tracking for feed
   card titles and topic headers.
3. Compare those specs with the current prototype typography.
4. Propose the mapping before implementation unless Luke asks to implement it.

## Current typography audit

- `FeedEditorialTypography.titleFont` currently uses system/SF Pro at 32pt
  bold, tight leading, `-0.8` tracking, and `-5` line spacing.
- Feed titles in `StoryFeedCard`, expanded-topic titles, and several
  `TopicLandingView` titles consume that shared token.
- Compact topic headers still contain a hardcoded system 32pt bold style.
- GT Standard, Good Sans, and Shopify Sans font assets are present under
  `ShopFeedSummer26/Fonts/` and are included as project resources.
- `GravityFont` and the full Gravity type scale already map to GT Standard.
- `project.yml` currently declares an empty `UIAppFonts` array, so custom-font
  registration must be verified/fixed before relying on the bundled faces.
- Likely implementation shape: register the required faces, split the shared
  editorial token into feed-card, full-topic-header, compact-header, and
  supporting-copy roles, then migrate hardcoded header styles to those tokens.

## Product and visual intent

- Shop UI should feel direct, restrained, native, and media-led.
- Avoid tiny all-caps, widely tracked eyebrow styling.
- Use sentence case and neutral/tight tracking.
- Large editorial type should be tightly led and visually connected to media.
- Preserve typography and navigation geometry across cards and topic pages.
- Top-level tabs/categories use horizontal motion.
- Card/content drill-ins use shared-view zoom transitions.

## Useful files

- Typography: `ShopFeedSummer26/DesignSystem/GravityTypography.swift`
- Feed cards: `ShopFeedSummer26/Components/StoryFeedCard.swift`
- Merchant collection cards:
  `ShopFeedSummer26/Components/MerchantCollectionFeedCard.swift`
- Topic surface: `ShopFeedSummer26/Pages/TopicLandingView.swift`
- Expanded topic: `ShopFeedSummer26/Pages/ExpandedTopicPage.swift`
- Personalized topic content reference: `TOPIC_HANDOFF.md`
