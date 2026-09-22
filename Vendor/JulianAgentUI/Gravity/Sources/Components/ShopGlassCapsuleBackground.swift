import SwiftUI
import UIKit

/// Which Liquid Glass material a Shop glass background renders with.
public enum ShopGlassMaterial {
    /// Frosted material, tinted at full strength. The default for every Shop glass surface.
    case regular

    /// Transparent, refractive material sandwiched between two tint layers.
    ///
    /// Mirrors the React Native `TintedGlassBox` treatment used by floating chrome
    /// (`packages/mobile/src/shared/components/TintedGlassBox`): the glassiness comes
    /// from the material and the opacity comes from flat layers around it, rather than
    /// from tinting the material itself. Expects an *opaque* tint — the layer opacities
    /// supply the translucency, so a pre-faded token double-dips and reads too thin.
    case clear

    case branded
}

public struct ShopGlassCapsuleBackground: View {
    private let tint: Color?
    private let isInteractive: Bool
    private let material: ShopGlassMaterial
    private let outline: Color?

    public init(
        tint: Color? = nil,
        isInteractive: Bool = false,
        material: ShopGlassMaterial = .regular,
        outline: Color? = nil
    ) {
        self.tint = tint
        self.isInteractive = isInteractive
        self.material = material
        self.outline = outline
    }

    public var body: some View {
        glass.shopGlassOutline(outline, in: Capsule())
    }

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *) {
            ShopLiquidGlassBackground(
                shape: Capsule(),
                tint: tint,
                isInteractive: isInteractive,
                material: material
            )
        } else {
            ShopLegacyGlassCapsuleBackground(tint: tint, material: material)
        }
    }
}

public extension View {
    /// Applies Liquid Glass to the complete capsule content so foreground labels and icons remain
    /// above the refractive surface. Use the background view only when there is no foreground
    /// content sharing the same control.
    @ViewBuilder
    func shopGlassCapsule(
        tint: Color? = nil,
        isInteractive: Bool = false,
        material: ShopGlassMaterial = .regular,
        outline: Color? = nil
    ) -> some View {
        if #available(iOS 26.0, *) {
            switch material {
            case .regular:
                background {
                    Capsule().fill(tint.map { $0.opacity(0.10) } ?? Color.white.opacity(0.08))
                }
                .shopRegularGlassEffect(tint: tint, isInteractive: isInteractive, shape: Capsule())
                .shopGlassOutline(outline, in: Capsule())

            case .clear, .branded:
                let layers = material == .branded
                    ? ShopClearGlassMetrics.brandedLayers
                    : ShopClearGlassMetrics.tabBarLayers

                background {
                    if let tint {
                        Capsule().fill(tint.opacity(layers.base))
                    }
                }
                .shopClearGlassEffect(
                    tint: tint?.opacity(layers.glassTint),
                    isInteractive: isInteractive,
                    shape: Capsule()
                )
                .overlay {
                    if let tint, layers.top > 0 {
                        Capsule()
                            .fill(tint.opacity(layers.top))
                            .allowsHitTesting(false)
                    }
                }
                .shopGlassOutline(outline, in: Capsule())
            }
        } else {
            background(ShopLegacyGlassCapsuleBackground(tint: tint, material: material))
        }
    }
}

extension View {
    @ViewBuilder
    func shopGlassOutline(_ outline: Color?, in shape: some InsettableShape) -> some View {
        if let outline {
            overlay { shape.strokeBorder(outline, lineWidth: 1) }
        } else {
            self
        }
    }
}

public struct ShopGlassCircleBackground: View {
    private let tint: Color?
    private let isInteractive: Bool
    private let material: ShopGlassMaterial
    private let outline: Color?

    public init(
        tint: Color? = nil,
        isInteractive: Bool = false,
        material: ShopGlassMaterial = .regular,
        outline: Color? = nil
    ) {
        self.tint = tint
        self.isInteractive = isInteractive
        self.material = material
        self.outline = outline
    }

    public var body: some View {
        glass.shopGlassOutline(outline, in: Circle())
    }

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *) {
            ShopLiquidGlassBackground(
                shape: Circle(),
                tint: tint,
                isInteractive: isInteractive,
                material: material
            )
        } else {
            ShopLegacyGlassCircleBackground(tint: tint, material: material)
        }
    }
}

public struct ShopGlassRoundedRectangleBackground: View {
    private let cornerRadius: CGFloat
    private let tint: Color?
    private let isInteractive: Bool
    private let material: ShopGlassMaterial

    public init(
        cornerRadius: CGFloat = ShopRadius.r20,
        tint: Color? = nil,
        isInteractive: Bool = false,
        material: ShopGlassMaterial = .regular
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.isInteractive = isInteractive
        self.material = material
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            ShopLiquidGlassBackground(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint,
                isInteractive: isInteractive,
                material: material
            )
        } else {
            ShopLegacyGlassRoundedRectangleBackground(
                cornerRadius: cornerRadius,
                tint: tint,
                material: material
            )
        }
    }
}

/// Layer opacities ported from the React Native `TintedGlassBox` values the floating
/// tab bar passes (`FloatingBottomTabBar.tsx`): `baseLayerOpacity` and
/// `topLayerOpacity` of 0.5, and a `fadeAmount` of 0.8 that leaves the glass tint at
/// 20% alpha.
private enum ShopClearGlassMetrics {
    struct Layers {
        let base: Double
        let glassTint: Double
        let top: Double
    }

    static let tabBarLayers = Layers(base: 0.5, glassTint: 0.2, top: 0.5)
    static let brandedLayers = Layers(base: 0.7, glassTint: 0.99, top: 0)

    /// Pre-iOS-26 fallback alpha for an opaque `.clear` tint.
    ///
    /// The `.clear` sandwich only exists on iOS 26+, so the legacy stack has to land the
    /// same *opaque* tint somewhere. RN solves this on its own non-Liquid-Glass path and
    /// arrives near 0.7: `GlassBox` renders `nonGlassTintColor` inside a container at
    /// `opacity: 0.85`, and the color reaches it double-faded — `TintedGlassBox` fades by
    /// `fallbackFadeAmount` (0.1) and `GlassBox` fades again by 0.1, so 0.9 × 0.9 × 0.85
    /// ≈ 0.69 (`TintedGlassBox.tsx:45-49`, `GlassBox.tsx:54-58, 77-105`).
    ///
    /// This folds RN's separate base layer into the same wash: the native legacy stack
    /// already sits on an opaque `systemChromeMaterialLight`, so a tint layer behind that
    /// blur would contribute almost nothing. RN also drops its top layer entirely on this
    /// path (`TintedGlassBox.tsx:99`) — with no refraction there are no reflections to
    /// soften — which is why this is a single value rather than a sandwich.
    static let legacyClearTintOpacity: Double = 0.7
}

@available(iOS 26.0, *)
private struct ShopLiquidGlassBackground<S: Shape>: View {
    let shape: S
    let tint: Color?
    let isInteractive: Bool
    let material: ShopGlassMaterial

    var body: some View {
        switch material {
        case .regular:
            shape
                .fill(tint.map { $0.opacity(0.10) } ?? Color.white.opacity(0.08))
                .shopRegularGlassEffect(tint: tint, isInteractive: isInteractive, shape: shape)

        case .clear, .branded:
            let layers = material == .branded
                ? ShopClearGlassMetrics.brandedLayers
                : ShopClearGlassMetrics.tabBarLayers

            ZStack {
                if let tint {
                    // Sits behind the glass; carries most of the surface's opacity.
                    shape.fill(tint.opacity(layers.base))
                }

                shape
                    .fill(Color.clear)
                    .shopClearGlassEffect(
                        tint: tint?.opacity(layers.glassTint),
                        isInteractive: isInteractive,
                        shape: shape
                    )

                if let tint, layers.top > 0 {
                    // Sits in front of the glass, softening the reflections the clear
                    // material produces without frosting it.
                    shape.fill(tint.opacity(layers.top))
                }
            }
        }
    }
}

@available(iOS 26.0, *)
private extension View {
    @ViewBuilder
    func shopRegularGlassEffect(
        tint: Color?,
        isInteractive: Bool,
        shape: some Shape
    ) -> some View {
        if let tint {
            if isInteractive {
                glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                glassEffect(.regular.tint(tint), in: shape)
            }
        } else if isInteractive {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            glassEffect(.regular, in: shape)
        }
    }

    @ViewBuilder
    func shopClearGlassEffect(
        tint: Color?,
        isInteractive: Bool,
        shape: some Shape
    ) -> some View {
        if let tint {
            if isInteractive {
                glassEffect(.clear.tint(tint).interactive(), in: shape)
            } else {
                glassEffect(.clear.tint(tint), in: shape)
            }
        } else if isInteractive {
            glassEffect(.clear.interactive(), in: shape)
        } else {
            glassEffect(.clear, in: shape)
        }
    }
}

private struct ShopLegacyGlassCapsuleBackground: View {
    let tint: Color?
    let material: ShopGlassMaterial

    var body: some View {
        ShopLegacyGlassLayers(tint: tint, material: material)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.84), lineWidth: 1))
            .overlay(Capsule().stroke(ShopColor.borderSecondary.opacity(0.7), lineWidth: 1))
            .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}

private struct ShopLegacyGlassCircleBackground: View {
    let tint: Color?
    let material: ShopGlassMaterial

    var body: some View {
        ShopLegacyGlassLayers(tint: tint, material: material)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.84), lineWidth: 1))
            .overlay(Circle().stroke(ShopColor.borderSecondary.opacity(0.7), lineWidth: 1))
            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}

private struct ShopLegacyGlassRoundedRectangleBackground: View {
    let cornerRadius: CGFloat
    let tint: Color?
    let material: ShopGlassMaterial

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ShopLegacyGlassLayers(tint: tint, material: material)
            .clipShape(shape)
            .overlay(shape.stroke(Color.white.opacity(0.84), lineWidth: 1))
            .overlay(shape.stroke(ShopColor.borderSecondary.opacity(0.7), lineWidth: 1))
            .overlay(shape.stroke(Color.black.opacity(0.08), lineWidth: 0.5))
    }
}

private struct ShopLegacyGlassLayers: View {
    let tint: Color?
    let material: ShopGlassMaterial

    @ViewBuilder
    var body: some View {
        switch material {
        case .regular: regularLayers
        case .clear, .branded: clearLayers
        }
    }

    /// Unchanged. This wash fades whatever tint it is handed to 0.14 unconditionally, so the
    /// blur and the white sheen do the work no matter what the caller passes — and callers do
    /// pass opaque semantic colors (`bgFill`, `bgFillBrand`, `bgFillInverse`). The 0.14 is
    /// this layer's, not a property of the incoming token.
    private var regularLayers: some View {
        ZStack {
            ShopBlurView(style: .systemChromeMaterialLight)

            Color.white.opacity(0.12)

            if let tint {
                tint.opacity(0.14)
            }

            LinearGradient(
                colors: [
                    Color.white.opacity(0.58),
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.06),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.03),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// `.clear` callers pass an *opaque* token, which the 0.14 wash above would flatten to
    /// near nothing — the tint would be doing no work and the surface would read as plain
    /// legacy frost. RN's own non-Liquid-Glass path is blur plus tint with no sheen and no
    /// top layer, so this mirrors that: the tint is the surface, and the blur only shows
    /// through where the tint is translucent.
    ///
    /// The white sheen is deliberately absent rather than reordered. Stacked above a 0.7
    /// tint it would fight the tint's hue for the top two thirds of the shape; stacked
    /// below, it would be invisible. RN has no analogue for it on this path.
    private var clearLayers: some View {
        ZStack {
            ShopBlurView(style: .systemChromeMaterialLight)

            if let tint {
                tint.opacity(ShopClearGlassMetrics.legacyClearTintOpacity)
            }
        }
    }
}

private struct ShopBlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

        HStack(spacing: ShopSpacing.space16) {
            ShopText("Glass Capsule", style: .buttonMedium)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(ShopGlassCapsuleBackground(isInteractive: true))
                .clipShape(Capsule())

            ShopIcon(.share, size: .medium, color: ShopColor.text)
                .frame(width: 44, height: 44)
                .background(ShopGlassCircleBackground(isInteractive: true))
                .clipShape(Circle())
        }
    }
}
