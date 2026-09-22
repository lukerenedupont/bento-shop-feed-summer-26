import SwiftUI
import UIKit

// Compatibility aliases for Gravity tokens used by Gravity and native app code.
public typealias ShopColor = GravityColor
public typealias ShopSpacing = GravitySpacing
public typealias ShopRadius = GravityRadius
public typealias ShopTextStyle = GravityTextStyle
public typealias ShopButtonVariant = GravityButtonVariant
public typealias ShopIconName = GravityIconName
public typealias ShopShadow = GravityShadowLevel
public typealias ShopShadowLevel = GravityShadowLevel
public typealias ShopFonts = GravityFonts

public enum GravityPathShadowShape: Sendable, Equatable {
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case circle
}

private struct GravityPathShadowView: UIViewRepresentable {
    let level: GravityShadowLevel
    let shape: GravityPathShadowShape

    func makeUIView(context: Context) -> GravityPathShadowUIView {
        let view = GravityPathShadowUIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: GravityPathShadowUIView, context: Context) {
        view.configure(level: level, shape: shape)
    }
}

private final class GravityPathShadowUIView: UIView {
    private var level: GravityShadowLevel = .none
    private var shape: GravityPathShadowShape = .roundedRectangle(cornerRadius: 0)
    private var lastShadowPathBounds: CGRect = .null
    private var lastShadowPathShape: GravityPathShadowShape = .roundedRectangle(cornerRadius: -1)

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = false
        layer.masksToBounds = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(level: GravityShadowLevel, shape: GravityPathShadowShape) {
        guard self.level != level || self.shape != shape else {
            return
        }

        self.level = level
        self.shape = shape

        let attributes = level.attributes
        layer.shadowColor = UIColor(attributes.color).cgColor
        layer.shadowOpacity = level == .none ? 0 : 1
        layer.shadowRadius = attributes.radius
        layer.shadowOffset = CGSize(width: attributes.x, height: attributes.y)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        guard lastShadowPathBounds != bounds || lastShadowPathShape != shape else {
            return
        }

        lastShadowPathBounds = bounds
        lastShadowPathShape = shape
        layer.shadowPath = shadowPath(in: bounds, shape: shape)
    }

    private func shadowPath(in bounds: CGRect, shape: GravityPathShadowShape) -> CGPath? {
        guard bounds.width > 0, bounds.height > 0 else {
            return nil
        }

        switch shape {
        case let .roundedRectangle(cornerRadius):
            return UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        case .capsule:
            return UIBezierPath(roundedRect: bounds, cornerRadius: min(bounds.width, bounds.height) / 2).cgPath
        case .circle:
            return UIBezierPath(ovalIn: bounds).cgPath
        }
    }
}

public extension ShopColor {
    static var background: Color { bg }

    static var fill: Color { bgFill }
    static var fillSecondary: Color { bgFillSecondary }
    static var fillTertiary: Color { bgFillTertiary }
    static var fillPlaceholder: Color { bgFillPlaceholder }
    static var fillBrand: Color { bgFillBrand }
    static var fillBrandSecondary: Color { bgFillBrandSecondary }
    static var fillCritical: Color { bgFillCritical }
    static var fillFixedDark: Color { bgFillFixedDark }
    static var fillFixedDusk: Color { bgFillFixedDusk }
    static var fillFixedLight: Color { bgFillFixedLight }

    static var overlayInverse04: Color { bgOverlayInverse04 }
    static var overlayHighlightHover: Color { bgOverlayHighlightHover }
}

public extension ShopRadius {
    static var r8: CGFloat { radius8 }
    static var r12: CGFloat { radius12 }
    static var r16: CGFloat { radius16 }
    static var r20: CGFloat { radius20 }
    static var r28: CGFloat { radius28 }
    static var max: CGFloat { radiusMax }
}

public extension SwiftUI.Text {
    @MainActor
    func shopTextStyle(
        _ style: ShopTextStyle,
        color: Color = ShopColor.text,
        alignment: TextAlignment = .leading
    ) -> some View {
        gravityTextStyle(style, color: color, alignment: alignment)
    }
}

public extension View {
    func shopShadow(_ level: ShopShadowLevel = .none) -> some View {
        gravityShadow(level)
    }

    func shopShadow(_ level: ShopShadowLevel?) -> some View {
        gravityShadow(level ?? .none)
    }

    @ViewBuilder
    func gravityPathShadow(
        _ level: GravityShadowLevel = .none,
        shape: GravityPathShadowShape
    ) -> some View {
        if level == .none {
            self
        } else {
            background {
                GravityPathShadowView(level: level, shape: shape)
                    .allowsHitTesting(false)
            }
        }
    }
}

public enum ShopMotion {
    public static var press: Animation { .spring(response: 0.20, dampingFraction: 0.72) }
    public static var snappy: Animation { .spring(response: 0.25, dampingFraction: 0.75) }
    public static var responsive: Animation { .spring(response: 0.35, dampingFraction: 0.78) }
    public static var standard: Animation { .spring(response: 0.40, dampingFraction: 0.85) }
    public static var entrance: Animation { .spring(response: 0.55, dampingFraction: 0.78) }
    public static var fade: Animation { .easeInOut(duration: 0.16) }
}
