# Shop Fisheye Canvas

A standalone SwiftUI module extracted from the globe grid in [`shopify-playground/shop-week-baskets`](https://github.com/shopify-playground/shop-week-baskets).

## Source

- Branch inspected: `main`
- Pinned commit: `16f2078037ee6325bb5dc2a5246919a09c7aee8e`
- File: [`ShopWeekBaskets/Sources/ShopWeekBaskets/Views/AddProductsView.swift`](https://github.com/shopify-playground/shop-week-baskets/blob/16f2078037ee6325bb5dc2a5246919a09c7aee8e/ShopWeekBaskets/Sources/ShopWeekBaskets/Views/AddProductsView.swift)
- Extracted sections: procedural product lookup, visible grid range, globe projection and drag/release gesture.

The upstream checkout did not include a license file. This extraction preserves provenance and does not assign a new license to the upstream implementation.

## What is included

- A buffered, procedural grid of 140pt tiles with 10pt spacing.
- The original coordinate hash, radial scale falloff, 16° tilt factor and 0.3 perspective.
- Two-dimensional dragging and the original velocity × 0.15 projection, released with a 0.5s / 0.86 damping spring.
- A caller-owned retained position and a caller-provided tile view.
- Active/interactive controls for embedding inside another scrolling surface. While exploring, pan has priority over tile buttons so a drag does not also select a product.
- Reduced Motion support: flat tiles, direct pan, no inertial projection/spring.

No baskets, product model, catalog loader, image cache, generation service, API credentials, bundled inventory, app navigation, top bar or selection tray are included. The no-op `Canvas` wrapper and unused timer/velocity fields were removed. There is no autonomous animation loop.

## Interface

```swift
import ShopFisheyeCanvas

@State private var position: CGPoint = .zero
@State private var exploring = false
@State private var selectedID: Product.ID?

// Inside your view, using your own product model and tile renderer:
FisheyeCanvas(
    items: products,
    position: $position,
    isInteractive: exploring,
    isActive: isVisible
) { product in
    Button { selectedID = product.id } label: {
        ProductTile(product: product)
    }
}
.frame(height: 340)
.background(Color(white: 0.93))
.clipShape(RoundedRectangle(cornerRadius: 24))
```

Add this directory as a local Swift package. It requires iOS 18+ and has **no package dependencies**. The app-specific example is `ShopFeedSummer26/Components/GenerativeFisheyeComposition.swift`.

### Interface contract

- Items must have stable, unique identities. Their order determines the procedural placement.
- The assortment is finite; the grid repeats it. Repeated cells do **not** represent new inventory.
- Empty assortments render an empty surface. The host owns any empty-state copy.
- Position is in canvas points, starting at `.zero`. Keep its binding above lazy feed cells if the pan must survive scrolling or composition changes.
- Drag frames are local view state. The retained position is written on release or when a drag is interrupted, avoiding host/feed updates every frame.
- `isInteractive: false` disables canvas panning but leaves the caller's tile buttons available. `isActive: false` disables hit testing for the entire canvas.
- While interactive, the canvas owns drags in both directions. The host must provide a way to exit exploration or swipe outside it. Do not silently swallow all vertical feed navigation.
- Tile views are constrained to 140×140 points. The host owns selection, prices, product destinations, imagery, radii and selection chrome.
- Buffered offscreen tiles are hidden from accessibility. Visible tiles expose the caller's own accessibility labels and actions.

## Demo in this repository

```sh
./Scripts/run_generative_feed.sh canvas
```

This opens the existing Standards Manual card using the optional **Fisheye canvas** composition. Tap **Explore library** to pan in two dimensions; **Done exploring** restores normal feed swiping. Tap a tile to focus it and the product row to inspect its canonical product details.

The default merchant composition remains available through the inspector, and both use the same twenty catalog products, prices and selected item. Pan position survives switching compositions. Leaving the card exits exploration while retaining position and product selection.

The larger, unrelated `CanvasAgentInfiniteProductCanvas.swift` engine and all full World destinations are unchanged.
