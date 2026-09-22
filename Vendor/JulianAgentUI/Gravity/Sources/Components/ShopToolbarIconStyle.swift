import SwiftUI

/// Marks this style so components that create a separate SwiftUI hosting root can replay it.
private struct ShopToolbarIconStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Explicit scheme for toolbar foregrounds whose backing content differs from the screen.
    /// Screen hosts replay this value from a descendant preference so separately-owned toolbar
    /// items resolve the same foreground without recoloring ordinary content.
    @Entry public var shopToolbarForegroundColorScheme: ColorScheme?

    var shopToolbarIconStyleEnabled: Bool {
        get { self[ShopToolbarIconStyleEnvironmentKey.self] }
        set { self[ShopToolbarIconStyleEnvironmentKey.self] = newValue }
    }
}

/// Resolves the fixed foreground used by controls floating above navigation content.
///
/// `GravityColor.text` is backed by a dynamic `UIColor`. That is correct for ordinary content,
/// but it follows the host trait collection rather than a local SwiftUI `colorScheme` override.
/// Header-backed toolbars use local overrides to stay legible over hero media, so their controls
/// need an explicit fixed token derived from that SwiftUI scheme.
public enum ShopToolbarForegroundColor {
    public static func resolve(
        for colorScheme: ColorScheme,
        toolbarColorScheme: ColorScheme? = nil
    ) -> Color {
        (toolbarColorScheme ?? colorScheme) == .dark
            ? GravityColor.textFixedLight
            : GravityColor.textFixedDark
    }
}

private struct ShopToolbarForegroundStyleModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.shopToolbarForegroundColorScheme) private var toolbarColorScheme

    func body(content: Content) -> some View {
        let foregroundColor = ShopToolbarForegroundColor.resolve(
            for: colorScheme,
            toolbarColorScheme: toolbarColorScheme
        )
        content
            .foregroundStyle(foregroundColor)
            .tint(foregroundColor)
    }
}

private struct ShopToolbarIconStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.shopToolbarIconStyleEnabled, true)
            .labelStyle(.iconOnly)
            .modifier(ShopToolbarForegroundStyleModifier())
    }
}

public extension View {
    /// Applies Shop's default top-toolbar treatment for icon-only `Button` and `Menu` controls.
    ///
    /// The modifier intentionally does not add a custom background, bordered style, glass effect, or
    /// fixed frame. Native toolbar chrome owns that presentation; custom shapes can create nested
    /// pill/capsule artifacts on iOS 26 Liquid Glass. The foreground and tint resolve from the
    /// toolbar's SwiftUI color scheme so locally branded and hero-backed toolbars stay legible
    /// instead of inheriting the app accent color or the window's unrelated trait collection.
    ///
    /// Use it on a single toolbar control:
    ///
    /// ```swift
    /// ToolbarItem(placement: .topBarTrailing) {
    ///     Menu { ... } label: {
    ///         Label("More options", systemImage: "ellipsis")
    ///     }
    ///     .shopToolbarIconStyle()
    /// }
    /// ```
    ///
    /// Or on a `Group` inside `ToolbarItemGroup` when multiple icon controls share the same chrome:
    ///
    /// ```swift
    /// ToolbarItemGroup(placement: .topBarTrailing) {
    ///     Group {
    ///         Button { ... } label: { Label("Search", systemImage: "magnifyingglass") }
    ///         Menu { ... } label: { Label("More options", systemImage: "ellipsis") }
    ///     }
    ///     .shopToolbarIconStyle()
    /// }
    /// ```
    func shopToolbarIconStyle() -> some View {
        modifier(ShopToolbarIconStyleModifier())
    }

    /// Applies the same adaptive foreground treatment to a non-icon toolbar control.
    ///
    /// Use this for text buttons that sit beside controls styled with `shopToolbarIconStyle()`.
    /// It intentionally changes only foreground and tint; the system still owns toolbar chrome.
    func shopToolbarForegroundStyle() -> some View {
        modifier(ShopToolbarForegroundStyleModifier())
    }

    /// Adds one styled icon control to a toolbar.
    ///
    /// This is a convenience wrapper around `toolbar { ToolbarItem { ... } }` for screens with a
    /// single icon action/menu. If the screen already has a `.toolbar` block or needs precise item
    /// ordering, prefer writing the `ToolbarItem` explicitly and applying `shopToolbarIconStyle()` to
    /// the control.
    func shopToolbarIcon<Content: View>(
        placement: ToolbarItemPlacement = .topBarTrailing,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        toolbar {
            ToolbarItem(placement: placement) {
                content()
                    .shopToolbarIconStyle()
            }
        }
    }

    /// Adds a styled group of icon controls to a toolbar.
    ///
    /// Use this when all controls in the group should receive the same icon-only, adaptive text/tint
    /// treatment. If a group mixes text buttons with icon buttons, use an explicit `ToolbarItemGroup`
    /// and apply `shopToolbarIconStyle()` only to the icon controls.
    func shopToolbarIconGroup<Content: View>(
        placement: ToolbarItemPlacement = .topBarTrailing,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        toolbar {
            ToolbarItemGroup(placement: placement) {
                content()
                    .shopToolbarIconStyle()
            }
        }
    }
}
