import SwiftUI

/// A circular favorite/heart toggle button used as an overlay on product images.
///
/// ```swift
/// ShopFavoriteButton(isFavorite: isFavorite) {
///     toggleFavorite()
/// }
/// ```
///
/// If no action is provided, the control renders as a static badge. This keeps
/// product-cell overlays out of nested `ShopButton`/gesture hierarchies while still
/// allowing PDP or other real favorite affordances to opt into interactivity.
public struct ShopFavoriteButton: View {
    private let isFavorite: Bool
    private let size: CGFloat
    private let accessibilityLabel: String?
    private let action: (() -> Void)?

    public init(
        isFavorite: Bool,
        size: CGFloat = 32,
        accessibilityLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.isFavorite = isFavorite
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    @ViewBuilder
    public var body: some View {
        if let action {
            SwiftUI.Button {
                ShopHaptics.light()
                action()
            } label: {
                favoriteBadge
            }
            .buttonStyle(.plain)
            .accessibilityLabel(SwiftUI.Text(accessibilityLabel ?? (isFavorite ? "Remove favorite" : "Add favorite")))
        } else {
            favoriteBadge
                .accessibilityHidden(true)
        }
    }

    private var favoriteBadge: some View {
        ZStack {
            if isFavorite {
                Circle().fill(ShopColor.fillBrand)
            } else {
                ShopImageOverlayBlurBackground(tint: Color.black.opacity(0.3))
                    .clipShape(Circle())
            }

            ShopIcon(
                isFavorite ? .navigationFavoritesFilled : .navigationFavorites,
                size: .small,
                color: ShopColor.textFixedLight
            )
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

#Preview {
    HStack(spacing: 24) {
        ShopFavoriteButton(isFavorite: false)
        ShopFavoriteButton(isFavorite: true)
    }
    .padding()
}
