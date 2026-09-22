import SwiftUI

/// A rounded product image tile with placeholder fill, image border, and shadow.
///
/// The image content and overlay are both provided as view builders, keeping this
/// component free of app-level image types (e.g. `ShopRemoteImage`).
///
/// ```swift
/// ShopProductImageTile(displayWidth: 160) {
///     ShopRemoteImage(image: model, displaySize: ...)
/// } overlay: {
///     ShopFavoriteButton(isFavorite: true)
/// }
/// ```
public struct ShopProductImageTile<ImageContent: View, Overlay: View>: View {
    private let displayWidth: CGFloat
    private let aspectRatio: CGFloat?
    private let scalesToFit: Bool
    private let cornerRadius: CGFloat
    private let shadow: GravityShadowLevel
    private let imageContent: ImageContent
    private let overlay: Overlay

    /// - Parameter aspectRatio: Width-to-height ratio. Defaults to `1` (square).
    ///   Pass `nil` to let the image content determine the height.
    public init(
        displayWidth: CGFloat,
        aspectRatio: CGFloat? = 1,
        scalesToFit: Bool = false,
        cornerRadius: CGFloat = GravityRadius.radius20,
        shadow: GravityShadowLevel = .s,
        @ViewBuilder image: () -> ImageContent,
        @ViewBuilder overlay: () -> Overlay
    ) {
        self.displayWidth = displayWidth
        self.aspectRatio = aspectRatio
        self.scalesToFit = scalesToFit
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.imageContent = image()
        self.overlay = overlay()
    }

    public var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(GravityColor.fillFixedLight)

                imageContent

                GravityColor.overlayInverse04
                    .allowsHitTesting(false)
            }

            overlay
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .modifier(ProductImageTileScaleModifier(displayWidth: displayWidth, aspectRatio: aspectRatio, scalesToFit: scalesToFit))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(
            .contextMenuPreview,
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay(ShopImageBorderOverlay(cornerRadius: cornerRadius))
        .gravityPathShadow(shadow, shape: .roundedRectangle(cornerRadius: cornerRadius))
    }
}

// Convenience: no overlay.
public extension ShopProductImageTile where Overlay == EmptyView {
    init(
        displayWidth: CGFloat,
        aspectRatio: CGFloat? = 1,
        scalesToFit: Bool = false,
        cornerRadius: CGFloat = GravityRadius.radius20,
        shadow: GravityShadowLevel = .s,
        @ViewBuilder image: () -> ImageContent
    ) {
        self.init(
            displayWidth: displayWidth,
            aspectRatio: aspectRatio,
            scalesToFit: scalesToFit,
            cornerRadius: cornerRadius,
            shadow: shadow,
            image: image,
            overlay: { EmptyView() }
        )
    }
}

public extension ShopProductImageTile where ImageContent == EmptyView, Overlay == EmptyView {
    init(
        displayWidth: CGFloat,
        aspectRatio: CGFloat? = 1,
        scalesToFit: Bool = false,
        cornerRadius: CGFloat = GravityRadius.radius20,
        shadow: GravityShadowLevel = .s
    ) {
        self.init(
            displayWidth: displayWidth,
            aspectRatio: aspectRatio,
            scalesToFit: scalesToFit,
            cornerRadius: cornerRadius,
            shadow: shadow,
            image: { EmptyView() },
            overlay: { EmptyView() }
        )
    }
}

private struct ProductImageTileScaleModifier: ViewModifier {
    let displayWidth: CGFloat
    let aspectRatio: CGFloat?
    let scalesToFit: Bool

    func body(content: Content) -> some View {
        if scalesToFit {
            // Cap width and height at the natural size but let the tile shrink below it (down-only),
            // so an over-tall slot compresses the image instead of clipping it. The parent decides
            // the final width: full card width for a vertical card, an aspect-locked square for a
            // horizontal line item.
            content
                .frame(
                    maxWidth: displayWidth,
                    maxHeight: aspectRatio.map { displayWidth / $0 } ?? displayWidth
                )
        } else if let aspectRatio {
            content
                .frame(width: displayWidth, height: displayWidth / aspectRatio)
        } else {
            content
                .frame(width: displayWidth)
        }
    }
}

// MARK: - Previews

#Preview("Placeholder") {
    ShopProductImageTile(displayWidth: 160)
        .padding()
}

#Preview("With Overlay") {
    ShopProductImageTile(displayWidth: 160) {
        Color.gray.opacity(0.3)
    } overlay: {
        ShopProductImageOverlayLayout {
            ShopProductImageOverlayItem(.bottomTrailing) {
                ShopFavoriteButton(isFavorite: true)
            }
        }
    }
    .padding()
}

#Preview("Aspect Ratios") {
    HStack(spacing: 12) {
        VStack {
            ShopProductImageTile(displayWidth: 100, aspectRatio: 1) {
                Color.blue.opacity(0.2)
            }
            ShopText("1:1").font(.caption)
        }
        VStack {
            ShopProductImageTile(displayWidth: 100, aspectRatio: 0.75) {
                Color.green.opacity(0.2)
            }
            ShopText("3:4").font(.caption)
        }
        VStack {
            ShopProductImageTile(displayWidth: 100, aspectRatio: 1.5) {
                Color.orange.opacity(0.2)
            }
            ShopText("3:2").font(.caption)
        }
    }
    .padding()
}
