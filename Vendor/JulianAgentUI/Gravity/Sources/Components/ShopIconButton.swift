import SwiftUI

public enum ShopIconButtonVariant: CaseIterable, Sendable {
    case plain
    case secondary
    case outlined
    case glass
    case filled
    case fixedLight
    case critical
    /// Overlay affordance drawn on top of imagery, e.g. a card's remove or favorite control.
    /// Mirrors Gravity's shared `blurred` button variant (`bg-overlay-fixed-icon` +
    /// `text-fixed-light`), which RN and Compose already expose.
    case blurred
    /// Low-emphasis affordance drawn on an opaque surface, e.g. a sheet's close control.
    /// Mirrors RN's default `SheetCloseButton` styling (`bg-fill-placeholder` +
    /// `text-tertiary`).
    case subtle

    var backgroundColor: Color {
        switch self {
        case .plain, .glass: .clear
        case .secondary: GravityColor.bgFillSecondary
        case .outlined: GravityColor.bgFill
        case .filled: GravityColor.bgFillInverse
        case .fixedLight: GravityColor.bgFillFixedLight
        case .critical: GravityColor.bgFillCriticalSecondary
        case .blurred: GravityColor.bgOverlayFixedIcon
        case .subtle: GravityColor.bgFillPlaceholder
        }
    }

    var foregroundColor: Color {
        switch self {
        case .plain, .secondary, .outlined, .glass: GravityColor.text
        case .filled, .blurred: GravityColor.textFixedLight
        case .fixedLight: GravityColor.textFixedDark
        case .critical: GravityColor.textCritical
        case .subtle: GravityColor.textTertiary
        }
    }

    var borderColor: Color? {
        switch self {
        case .outlined: GravityButtonVariant.outlined.borderColor
        case .plain, .secondary, .glass, .filled, .fixedLight, .critical, .blurred, .subtle: nil
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .outlined: GravityButtonVariant.outlined.borderWidth
        case .plain, .secondary, .glass, .filled, .fixedLight, .critical, .blurred, .subtle: 0
        }
    }
}

public enum ShopIconButtonSize: CaseIterable, Sendable {
    case xSmall
    case small
    case medium
    case large

    var containerSize: CGFloat {
        switch self {
        case .xSmall: GravitySpacing.space24
        case .small: GravitySpacing.space32
        case .medium: GravitySpacing.space40
        case .large: GravitySpacing.space44
        }
    }

    var iconSize: ShopIconSize {
        switch self {
        case .xSmall: .xSmall
        case .small: .small
        case .medium: .medium
        case .large: .medium
        }
    }
}

/// Inset needed on each edge to reach `minimum`, or zero when the button is already big enough.
public func shopIconButtonHitTargetInset(minimum: CGFloat?, containerSize: CGFloat) -> CGFloat {
    guard let minimum else { return 0 }

    return max(0, (minimum - containerSize) / 2)
}

public struct ShopIconButton: View {
    private let icon: GravityIconName
    private let accessibilityLabel: String
    private let variant: ShopIconButtonVariant
    private let size: ShopIconButtonSize
    private let iconSize: ShopIconSize?
    private let foregroundColor: Color?
    private let isDisabled: Bool
    private let minimumHitTarget: CGFloat?
    private let action: () -> Void

    public init(
        _ icon: GravityIconName,
        accessibilityLabel: String,
        variant: ShopIconButtonVariant = .plain,
        size: ShopIconButtonSize = .medium,
        iconSize: ShopIconSize? = nil,
        foregroundColor: Color? = nil,
        isDisabled: Bool = false,
        minimumHitTarget: CGFloat? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.accessibilityLabel = accessibilityLabel
        self.variant = variant
        self.size = size
        self.iconSize = iconSize
        self.foregroundColor = foregroundColor
        self.isDisabled = isDisabled
        self.minimumHitTarget = minimumHitTarget
        self.action = action
    }

    public var body: some View {
        SwiftUI.Button(action: action) {
            ShopIcon(
                icon,
                size: iconSize ?? size.iconSize,
                color: isDisabled ? GravityColor.textPlaceholder : (foregroundColor ?? variant.foregroundColor),
                accessibilityLabel: accessibilityLabel
            )
            .frame(width: size.containerSize, height: size.containerSize)
            .background {
                background
            }
            .clipShape(Circle())
            .gravityShadow(variant == .glass && isDisabled == false ? .s : .none)
            .padding(hitTargetInset)
            .contentShape(Circle())
            .padding(-hitTargetInset)
        }
        .buttonStyle(IconScaleButtonStyle(isInteractive: !isDisabled))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }

    private var hitTargetInset: CGFloat {
        shopIconButtonHitTargetInset(minimum: minimumHitTarget, containerSize: size.containerSize)
    }

    @ViewBuilder
    private var background: some View {
        if isDisabled {
            GravityColor.bgFillPlaceholder
        } else {
            switch variant {
            case .glass:
                ShopGlassCircleBackground(tint: GravityColor.bgFill, isInteractive: true)
            case .outlined:
                Circle()
                    .fill(variant.backgroundColor)
                    .overlay {
                        Circle()
                            .stroke(variant.borderColor ?? .clear, lineWidth: variant.borderWidth)
                    }
            default:
                variant.backgroundColor
            }
        }
    }
}

private enum IconButtonPressMetrics {
    static let scale: CGFloat = 0.96
    static let opacity: Double = 0.2
    static let duration: TimeInterval = 0.1
}

private struct IconScaleButtonStyle: ButtonStyle {
    let isInteractive: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed && isInteractive

        return configuration.label
            .scaleEffect(isPressed ? IconButtonPressMetrics.scale : 1)
            .opacity(isPressed ? IconButtonPressMetrics.opacity : 1)
            .animation(.easeOut(duration: IconButtonPressMetrics.duration), value: configuration.isPressed)
    }
}

#Preview("ShopIconButton") {
    HStack(spacing: GravitySpacing.space12) {
        ShopIconButton(.arrowLeft, accessibilityLabel: "Back") {}
        ShopIconButton(.navigationFavorites, accessibilityLabel: "Save", variant: .outlined, size: .large) {}
        ShopIconButton(.share, accessibilityLabel: "Share", variant: .secondary) {}
        ShopIconButton(.cross, accessibilityLabel: "Close", variant: .filled) {}
        ShopIconButton(.delete, accessibilityLabel: "Delete", variant: .critical) {}
        ShopIconButton(.cross, accessibilityLabel: "Remove", variant: .blurred, size: .small) {}
    }
    .padding()
    .background(GravityColor.bgFillInverse)
}
