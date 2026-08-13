---
name: swiftui-previews
description: "Add Xcode #Preview blocks to every UI-driven SwiftUI file in this prototype. Use when creating new components, pages, sheets, or visual surfaces, or when reviewing a prototype to ensure preview coverage. Trigger on: 'add a preview', 'preview this component', 'why doesn't the preview show data', 'wire up previews', or when scaffolding a new SwiftUI View."
---

# SwiftUI Previews

Every UI-driven SwiftUI file in this prototype kit ships with at least one `#Preview` block so designers can hot-reload tweaks in the Xcode canvas without building the full app or signing in. New files should follow that same pattern.

## When to add a preview

| File kind | Preview required? |
|---|---|
| Page / screen (`base/Pages/*.swift`) | ✅ Yes |
| Component with a `var body: some View` (`base/Components/**`) | ✅ Yes |
| Multi-variant component | ✅ Yes — one `#Preview("name")` per major variant |
| Pure utility / infrastructure primitive | ❌ Skip (e.g. `FloatingPanelSheet`) |
| `UIViewRepresentable` / `UIViewControllerRepresentable` | ✅ When practical — see `LoopingVideoPlayer` for a pattern |
| Service / model / coordinator (no `View`) | ❌ Skip |

If a file has `struct Foo: View`, it almost certainly needs a preview.

## Preview data — always offline, never network

**Don't write previews that depend on network, auth, or runtime state.** Use the shared offline fixture data in `base/SampleData/PreviewData.swift`:

### Merchant data
```swift
SampleMerchant.preview           // single merchant
SampleMerchant.previews          // all bundled merchants
SampleMerchant.previewWithVideo  // first merchant that ships with video
SampleMerchant.synthetic         // hard-coded fallback if asset load fails
```

`SampleMerchant.all` also auto-falls-back to `.previews` inside Xcode previews (detected via `XCODE_RUNNING_FOR_PREVIEWS=1`), so anything that reads `SampleMerchant.all` "just works" in the canvas — including `DeliveryItem.active` / `.past`, `ExplorePage`, `StorePage`, etc.

### Agent data
```swift
AgentProduct.previews()                  // 6 products from .preview merchant
AgentProduct.previews(from: merchant)    // custom merchant source
AgentProduct.previews(limit: 12)         // larger set
AgentProduct.comparisonPreviews          // 3 products with descriptors + labels
AgentProductSection.preview              // standard shelf section
AgentProductSection.comparisonPreview    // comparison shelf
```

### Search data
```swift
SearchSuggestion.previews        // mixed shop + query rows
RecentConversation.previews      // 3 history entries with thumbnails
SuggestionItem.previews          // follow-up chips
```

### When fixtures don't cover your case
Extend `PreviewData.swift` rather than inlining synthetic data in the preview block. Keeps the canvas data consistent across files and makes it easy to swap in real-looking data later.

## Standard patterns

### Simple component
```swift
#Preview {
    MyComponent(title: "Example")
        .padding()
        .background(GravityColors.bg)
}
```

### Component with multiple variants
```swift
#Preview("Default") {
    MyCard(state: .default)
        .padding()
        .background(GravityColors.bg)
}

#Preview("Selected") {
    MyCard(state: .selected)
        .padding()
        .background(GravityColors.bg)
}

#Preview("Loading skeleton") {
    MyCardSkeleton()
        .padding()
        .background(GravityColors.bg)
}
```

### Component using `@Binding` / `@FocusState`
Use `@Previewable` to hoist state into the preview closure:
```swift
#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    ComposerBar(text: $text, isFocused: $focused)
        .padding()
        .background(GravityColors.bg)
}
```

### Page / screen
Pages need the `NavigationCoordinator` environment. Pages that take a `Namespace.ID` for zoom transitions need `@Previewable @Namespace`:
```swift
#Preview {
    @Previewable @Namespace var ns
    NavigationStack {
        ProductPage(merchantId: SampleMerchant.preview.id,
                    productId: SampleMerchant.preview.products.first!.id,
                    namespace: ns)
    }
    .environment(NavigationCoordinator())
}
```

### Setting up local state without explicit `return`
`#Preview` bodies are single-expression view closures. Local `let`s are fine but **don't use `return`** unless every branch returns — it conflicts with the implicit `ViewBuilder` form. If you need an `if`/`switch`, wrap branches in `AnyView` or `Group`:
```swift
#Preview {
    let merchant = SampleMerchant.preview
    ScrollView {
        // …use merchant…
    }
    .background(GravityColors.bg)
}
```

### `UIViewRepresentable` / video / heavy primitives
Provide a minimal-cost preview when possible. Reuse bundled assets — e.g. the `map` `NSDataAsset` powers `LoopingVideoPlayer`'s preview without any network.

## Anti-patterns

```swift
// ❌ Force-unwrapping SampleMerchant.all — crashes in previews if the
//    fallback hasn't loaded.
let merchant = SampleMerchant.all.first!

// ✅ Use the preview helpers — guaranteed to return data.
let merchant = SampleMerchant.preview
```

```swift
// ❌ Pulling live state from a singleton service in a preview.
let history = ConversationHistoryClient.shared.conversations  // empty in previews

// ✅ Use the fixture data.
let history = RecentConversation.previews
```

```swift
// ❌ Inlining synthetic JSON / hard-coded URLs per file.
// ✅ Extend PreviewData.swift with a new `static var ...Previews`.
```

## Note on token-derived files

Files in `base/DesignSystem/` that mirror Gravity tokens from `shop-client`
(`GravityColors`, `GravityTypography`, `GravitySpacing`, `GravityBorderRadii`,
`GravityShadows`) keep their previews inline. If those files ever get
regenerated from a future sync script the previews would be lost — that's
an accepted tradeoff for keeping each token file self-contained. Just
re-add the preview when re-running the kit's preview audit.

## Checklist for new SwiftUI files

When you add or edit a UI-driven SwiftUI file:

1. Does it have at least one `#Preview` block? If no — add one.
2. Does it depend on `NavigationCoordinator`? Inject it with `.environment(NavigationCoordinator())`.
3. Does it take a `Namespace.ID`? Use `@Previewable @Namespace var ns`.
4. Does it need bindings? Use `@Previewable @State` / `@Previewable @FocusState`.
5. Does it have meaningfully distinct states / variants? Add one `#Preview("name")` per state.
6. Is the data sourced from `PreviewData.swift` (not network / singletons / hardcoded JSON)? If your case isn't covered, extend `PreviewData.swift` and reference it.
7. Background is `GravityColors.bg` so it matches the in-app surface.
8. `xcodebuild` is still clean.
