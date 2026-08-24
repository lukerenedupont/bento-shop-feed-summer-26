# Shop Feed Summer 26 architecture

## Product model

The prototype is a personalized, media-led commerce feed. Topics are authored
merchandising destinations assembled from a finite block system. New content
should normally require catalog or recipe changes, not another SwiftUI page.

## Data flow

```text
prototype-merchants.json + personalized-feed.json + frozen dossier bundle
                                |
                  Local/remote catalog services
                                |
             Buyer personalization + stable product references
                                |
                  HomePage -> StoryFeedCard
                                |
               StoryTopicPage -> TopicDetailPage
                                |
                      Store / PDP / Try-on
```

- Merchant/product identity is always `merchantID + productID`.
- `RemoteMerchantService` publishes one merged lookup graph while retaining
  the authenticated followed-merchant collection separately.
- `SampleMerchant` caches merchant and product indexes per catalog generation.
- The app renders bundled data immediately and hydrates followed shops, posts,
  and account history independently.
- The frozen feed bundle is optimized to 540p video and phone-sized imagery at
  build time. A persistent fingerprinted cache prevents clean device builds
  from recompressing unchanged media.

## Live UI layers

- `Pages/HomePage.swift` owns feed selection and orchestration.
- `Pages/FeedScrollInfrastructure.swift` owns high-frequency paging and
  utility-belt gesture state.
- `Pages/HomeFeedModels.swift` owns feed entry and seasonal placement models.
- `Components/StoryFeedCard.swift` is the shared media-led feed card.
- `Pages/StoryTopicPage.swift` owns topic navigation chrome.
- `Pages/TopicDetailPage.swift` resolves content and renders a recipe.
- `Pages/TopicPageRecipe.swift` is the finite, validated recipe catalog.
- `Pages/TopicPageBlocks.swift` contains reusable topic card components.
- `Navigation/RootView.swift` is the only route-to-destination switch.

The removed `TopicPage`, `TopicLandingView`, `ExpandedTopicPage`, and
masonry stack are not alternate extension points. All live topic routes use
the shared detail renderer.

## Topic recipes

The four recipe families are:

1. Sculptural living — the authored lighting/home sequence.
2. Hypebeast — the authored sneaker/apparel sequence.
3. Merchant — a tighter store-led sequence.
4. Standard — a context-aware fallback shared by every other topic.

Recipes use only the block primitives documented in
[`docs/TOPIC_PAGE_BLOCK_SYSTEM.md`](docs/TOPIC_PAGE_BLOCK_SYSTEM.md).
Each recipe validates its spacing, titles, card geometry, category depth,
filters, and minimum product query size in Debug builds.

## Media runtime

- `CachedAsyncImage` is the only URL/file image pipeline.
- Images are downsampled off-main-thread and cached with fixed memory/disk
  budgets; duplicate requests coalesce and network concurrency is capped.
- Feed prefetching is limited to the current and next two stories.
- `LoopingVideoPlayer` detaches its player when a lazy cell leaves the window,
  shares playback during feed-to-topic transitions, and disables autoplay for
  Reduce Motion.
- Local dossier images bypass URLSession to avoid buffering source files twice.

## Navigation

Top-level feeds move horizontally. Feed/topic drill-ins use the system shared
zoom transition. Product and store pushes use the centralized `HomeRoute`.
The bottom navigation is hidden only for immersive topic/try-on destinations
and restored by the coordinator.

## Validation and budgets

Every build runs:

```bash
Scripts/validate_personalized_feed.py
Scripts/optimize_feed_bundle.sh
Scripts/validate_build_product.sh
```

Validation covers stable IDs, product references, block items, dossier
manifests, cover assets, frozen media references, minimum story depth, source
file line budgets, the generated media inventory, and product-size budgets.

Current hard limits:

- Built app: 180 MB
- Optimized frozen feed: 100 MB
- `HomePage.swift`: 1,900 lines
- `TopicDetailPage.swift`: 1,200 lines
- `TopicPageBlocks.swift`: 1,100 lines

## Adding content

1. Add or update real merchant/products in the catalog.
2. Reference products by stable IDs in the story.
3. Select an existing recipe family.
4. Add an authored recipe only when block order or shopping intent differs.
5. Add a block primitive only for a genuinely new interaction.
6. Run validation and verify the simulator/physical-phone build.

## Security boundary

Secrets remain in `.env.local` and are copied only into local debug products.
Decart/FAL token minting stays behind the Shopify AI proxy. No long-lived
vendor credential belongs in source control or the app bundle.
