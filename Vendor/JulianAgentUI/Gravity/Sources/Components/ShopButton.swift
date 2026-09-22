import Foundation
import SwiftUI

public enum ShopButtonSize: CaseIterable, Sendable {
    case small
    case medium
    case large
    case extraLarge

    var minHeight: CGFloat {
        switch self {
        case .small: 32
        case .medium: 40
        case .large: 44
        case .extraLarge: 52
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: GravitySpacing.space12
        case .medium, .large, .extraLarge: GravitySpacing.space16
        }
    }

    var textStyle: GravityTextStyle {
        switch self {
        case .small: .buttonSmall
        case .medium: .buttonMedium
        case .large, .extraLarge: .buttonLarge
        }
    }

    var iconSize: ShopIconSize {
        switch self {
        case .small: .small
        case .medium: .medium
        case .large, .extraLarge: .large
        }
    }

    var spinnerSize: ShopSpinnerSize {
        switch self {
        case .small: .small
        case .medium: .medium
        case .large, .extraLarge: .medium
        }
    }
}

/// `ShopButton` truncates its label to one line at every text size, so long
/// labels are cut at accessibility sizes.
///
/// Opting in with `wrapsTitleAtAccessibilitySizes` lets the label wrap once the
/// text reaches an accessibility size; the button grows to fit because
/// `ShopButtonSize.minHeight` is a floor rather than a fixed height.
///
/// This is opt-in rather than the default because some callers pin the button to
/// a fixed height, or budget surrounding layout against a fixed one-line button
/// height, and a wrapped label would be clipped there. Adopt it per surface once
/// the enclosing layout is known to accommodate a taller button.
public func shopButtonTitleLineLimit(
    isAccessibilitySize: Bool,
    wrapsTitleAtAccessibilitySizes: Bool
) -> Int? {
    guard wrapsTitleAtAccessibilitySizes, isAccessibilitySize else {
        return 1
    }
    return nil
}

public struct ShopButton: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: String
    private let variant: GravityButtonVariant
    private let customForegroundColor: Color?
    private let customBackgroundColor: Color?
    private let size: ShopButtonSize
    private let customMinHeight: CGFloat?
    private let customHorizontalPadding: CGFloat?
    private let customCornerRadius: CGFloat?
    private let isFullWidth: Bool
    private let wrapsTitleAtAccessibilitySizes: Bool
    private let isDisabled: Bool
    private let isLoading: Bool
    private let leadingIcon: GravityIconName?
    private let trailingIcon: GravityIconName?
    private let iconSize: ShopIconSize?
    private let iconSpacing: CGFloat
    private let customAccessibilityLabel: String?
    private let action: () -> Void

    public init(
        _ title: String,
        variant: GravityButtonVariant = .primary,
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil,
        size: ShopButtonSize = .large,
        minHeight: CGFloat? = nil,
        horizontalPadding: CGFloat? = nil,
        cornerRadius: CGFloat? = nil,
        isFullWidth: Bool = true,
        wrapsTitleAtAccessibilitySizes: Bool = false,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        leadingIcon: GravityIconName? = nil,
        trailingIcon: GravityIconName? = nil,
        iconSize: ShopIconSize? = nil,
        iconSpacing: CGFloat = GravitySpacing.space8,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.customForegroundColor = foregroundColor
        self.customBackgroundColor = backgroundColor
        self.size = size
        self.customMinHeight = minHeight
        self.customHorizontalPadding = horizontalPadding
        self.customCornerRadius = cornerRadius
        self.isFullWidth = isFullWidth
        self.wrapsTitleAtAccessibilitySizes = wrapsTitleAtAccessibilitySizes
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.iconSize = iconSize
        self.iconSpacing = iconSpacing
        self.customAccessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        let foregroundColor = foregroundColor(isEnabled: !isDisabled)
        let resolvedIconSize = iconSize ?? size.iconSize
        let shape = ShopButtonShape(cornerRadius: customCornerRadius)

        SwiftUI.Button(action: action) {
            HStack(spacing: iconSpacing) {
                if isLoading {
                    ShopSpinner(size: size.spinnerSize, color: foregroundColor, accessibilityLabel: nil)
                        .accessibilityHidden(true)
                } else {
                    if let leadingIcon {
                        ShopIcon(leadingIcon, size: resolvedIconSize, color: foregroundColor)
                            .accessibilityHidden(true)
                    }

                    ShopText(title, style: size.textStyle, color: foregroundColor, alignment: .center)
                        .lineLimit(shopButtonTitleLineLimit(
                            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                            wrapsTitleAtAccessibilitySizes: wrapsTitleAtAccessibilitySizes
                        ))

                    if let trailingIcon {
                        ShopIcon(trailingIcon, size: resolvedIconSize, color: foregroundColor)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: customMinHeight ?? size.minHeight)
            .padding(.horizontal, customHorizontalPadding ?? size.horizontalPadding)
            .contentShape(shape)
        }
        .buttonStyle(
            ScaleButtonStyle(
                shape: shape,
                backgroundColor: backgroundColor(isEnabled: !isDisabled),
                borderColor: borderColor(isEnabled: !isDisabled),
                borderWidth: variant.borderWidth,
                isDashedBorder: variant == .dashedOutlined,
                isInteractive: !isDisabled && !isLoading
            )
        )
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(SwiftUI.Text(customAccessibilityLabel ?? title))
        .accessibilityValue(isLoading ? SwiftUI.Text(localizedLoadingLabel) : SwiftUI.Text(""))
    }

    private var localizedLoadingLabel: String {
        NSLocalizedString("Products.Loading", bundle: .main, comment: "")
    }

    private func foregroundColor(isEnabled: Bool) -> Color {
        guard isEnabled else { return GravityColor.textPlaceholder }
        return customForegroundColor ?? variant.foregroundColor
    }

    private func backgroundColor(isEnabled: Bool) -> Color {
        guard isEnabled else {
            switch variant {
            case .text, .glass, .outlinedDangerous:
                return .clear
            default:
                return GravityColor.bgFillPlaceholder
            }
        }

        return customBackgroundColor ?? variant.backgroundColor
    }

    private func borderColor(isEnabled: Bool) -> Color? {
        guard isEnabled else {
            return variant.borderColor == nil ? nil : GravityColor.borderSecondary
        }

        return variant.borderColor
    }
}

private struct ShopButtonShape: Shape, InsettableShape {
    let cornerRadius: CGFloat?
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)

        guard let cornerRadius else {
            return Capsule(style: .continuous).path(in: rect)
        }

        let radius = min(max(0, cornerRadius - inset), min(rect.width, rect.height) / 2)
        return Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
    }

    func inset(by amount: CGFloat) -> ShopButtonShape {
        ShopButtonShape(cornerRadius: cornerRadius, inset: inset + amount)
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    let shape: ShopButtonShape
    let backgroundColor: Color
    let borderColor: Color?
    let borderWidth: CGFloat
    let isDashedBorder: Bool
    let isInteractive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor)
            .overlay(
                shape
                    .strokeBorder(
                        borderColor ?? .clear,
                        style: StrokeStyle(
                            lineWidth: borderColor == nil ? 0 : borderWidth,
                            dash: isDashedBorder
                                ? [GravitySpacing.space4, GravitySpacing.space2]
                                : []
                        )
                    )
            )
            .clipShape(shape)
            .scaleEffect(configuration.isPressed && isInteractive ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("ShopButton") {
    VStack(spacing: GravitySpacing.space12) {
        ShopButton("Primary") {}
        ShopButton("Secondary", variant: .secondary) {}
        ShopButton("Outlined", variant: .outlined) {}
        ShopButton("Dashed", variant: .dashedOutlined) {}
        ShopButton("Dangerous", variant: .dangerous, leadingIcon: .alertTriangle) {}
        ShopButton("Loading", isLoading: true) {}
        ShopButton("Disabled", isDisabled: true) {}
    }
    .padding()
}
