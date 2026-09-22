import SwiftUI

public enum ShopScrollEdgeEffectStyle: Sendable {
    case automatic
    case soft
}

public extension View {
    /// Applies Shop's default soft iOS 26 scroll-edge effect to a SwiftUI scroll
    /// container via SwiftUI's own `scrollEdgeEffectStyle`.
    ///
    /// SwiftUI's effect is *bar-gated*: it only renders where scroll content
    /// passes under a system bar (navigation bar / toolbar / tab bar). It is
    /// therefore effective for titled `ShopScrollScreen` surfaces (which have a
    /// navigation bar) and a no-op for bar-less custom-chrome surfaces. Those use
    /// `ShopTopScrollFade` to paint an equivalent fade manually.
    ///
    /// No-op before iOS 26, where the API and effect do not exist.
    @ViewBuilder
    func shopScrollEdgeEffect(for edges: Edge.Set = .all, isEnabled: Bool = true) -> some View {
        if #available(iOS 26.0, *) {
            if isEnabled {
                scrollEdgeEffectStyle(.soft, for: edges)
            } else {
                scrollEdgeEffectHidden(for: edges)
            }
        } else {
            self
        }
    }

    /// Applies a native iOS 26 scroll-edge treatment while allowing callers
    /// with full-bleed artwork to opt into the system's adaptive style.
    @ViewBuilder
    func shopScrollEdgeEffect(
        for edges: Edge.Set = .all,
        style: ShopScrollEdgeEffectStyle
    ) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .automatic:
                scrollEdgeEffectStyle(.automatic, for: edges)
            case .soft:
                scrollEdgeEffectStyle(.soft, for: edges)
            }
        } else {
            self
        }
    }
}

/// A top frosted-blur fade that mimics the iOS 26 soft scroll-edge effect for
/// bar-less scroll surfaces — where SwiftUI's bar-gated `scrollEdgeEffectStyle`
/// cannot render and the tab shell's safe-area stripping defeats `safeAreaBar`.
///
/// It overlays a translucent `.ultraThinMaterial` blur that is strongest at the
/// very top and fades to nothing over its height, so content gets a real frosted
/// blur as it scrolls under the status bar (and stays legible) without fully
/// hiding what's beneath. Place it in a top-aligned overlay above the scroll
/// content; it never intercepts touches.
///
/// `fadeHeight` is how far the fade extends *past* the status bar; it defaults to
/// half the status-bar height. The gradient runs from the very top of the status
/// bar down through that distance.
public struct ShopTopScrollFade: View {
    private let safeAreaInset: CGFloat
    private let fadeHeight: CGFloat?

    public init(safeAreaInset: CGFloat, fadeHeight: CGFloat? = nil) {
        self.safeAreaInset = safeAreaInset
        self.fadeHeight = fadeHeight
    }

    private var resolvedFadeHeight: CGFloat {
        fadeHeight ?? safeAreaInset / 2
    }

    public var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .frame(height: safeAreaInset + resolvedFadeHeight)
            .mask(alignment: .top) {
                // Fade from full blur at the very top to clear at the bottom.
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .ignoresSafeArea(.container, edges: .top)
            .allowsHitTesting(false)
    }
}
