import SwiftUI

/// Button variant types matching Gravity's buttonVariants.ts.
enum GravityButtonVariant {
    case primary
    case secondary
    case tertiary
    case dangerous
    case outlined
    case outlinedDangerous
    case text
}

/// A SwiftUI ButtonStyle that renders buttons according to Gravity design tokens.
struct GravityButtonStyle: ButtonStyle {
    let variant: GravityButtonVariant
    let size: GravityButtonSize

    enum GravityButtonSize {
        case large
        case medium
        case small

        var textStyle: GravityTextStyle {
            switch self {
            case .large: GravityTypography.buttonLarge
            case .medium: GravityTypography.buttonMedium
            case .small: GravityTypography.buttonSmall
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .large: GravitySpacing.space16
            case .medium: GravitySpacing.space12
            case .small: GravitySpacing.space8
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .large: GravitySpacing.space24
            case .medium: GravitySpacing.space20
            case .small: GravitySpacing.space16
            }
        }
    }

    init(_ variant: GravityButtonVariant, size: GravityButtonSize = .medium) {
        self.variant = variant
        self.size = size
    }

    private var backgroundColor: Color {
        switch variant {
        case .primary: GravityColors.bgFillBrand
        case .secondary: GravityColors.bgFillInverse
        case .tertiary: GravityColors.bgFillSecondary
        case .dangerous: GravityColors.bgFillCritical
        case .outlined: GravityColors.bgFill
        case .outlinedDangerous: .clear
        case .text: .clear
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary: GravityColors.textFixedLight
        case .secondary: GravityColors.textInverse
        case .tertiary: GravityColors.text
        case .dangerous: GravityColors.textFixedLight
        case .outlined: GravityColors.text
        case .outlinedDangerous: GravityColors.textCritical
        case .text: GravityColors.text
        }
    }

    private var borderColor: Color? {
        switch variant {
        case .outlined: GravityColors.border
        case .outlinedDangerous: GravityColors.borderCritical
        default: nil
        }
    }

    private var pressedBackgroundColor: Color {
        switch variant {
        case .primary: GravityColors.bgFillBrandHover
        case .secondary: GravityColors.bgFillInverseHover
        case .tertiary: GravityColors.bgFillSecondaryHover
        case .dangerous: GravityColors.bgFillCriticalHover
        case .outlined: GravityColors.bgFillHover
        case .outlinedDangerous: GravityColors.bgFillOutlinedCriticalHover
        case .text: GravityColors.bgOverlayHighlight
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let bg = configuration.isPressed ? pressedBackgroundColor : backgroundColor

        configuration.label
            .gravityTextStyle(size.textStyle)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
            .overlay(
                Group {
                    if let border = borderColor {
                        RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    }
                }
            )
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Press Scale Button Style

/// A plain button style that scales down on press for tactile feedback.
/// Use on cards, tiles, and interactive surfaces that need a press state.
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Elevated Secondary Small

struct ElevatedSecondarySmallButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .gravityTextStyle(GravityTypography.buttonSmall)
            .foregroundStyle(GravityColors.textInverse)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(GravityColors.bgFillInverse, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(GravityColors.text.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("All variants × sizes") {
    ScrollView {
        VStack(alignment: .leading, spacing: GravitySpacing.space24) {
            ForEach(["large", "medium", "small"], id: \.self) { sizeName in
                let size: GravityButtonStyle.GravityButtonSize = sizeName == "large" ? .large : sizeName == "medium" ? .medium : .small
                VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                    Text(sizeName.capitalized)
                        .gravityTextStyle(GravityTypography.bodyTitleSmall)
                        .foregroundStyle(GravityColors.textTertiary)
                    Button("Primary") {}.buttonStyle(GravityButtonStyle(.primary, size: size))
                    Button("Secondary") {}.buttonStyle(GravityButtonStyle(.secondary, size: size))
                    Button("Tertiary") {}.buttonStyle(GravityButtonStyle(.tertiary, size: size))
                    Button("Outlined") {}.buttonStyle(GravityButtonStyle(.outlined, size: size))
                    Button("Dangerous") {}.buttonStyle(GravityButtonStyle(.dangerous, size: size))
                    Button("Outlined dangerous") {}.buttonStyle(GravityButtonStyle(.outlinedDangerous, size: size))
                    Button("Text") {}.buttonStyle(GravityButtonStyle(.text, size: size))
                }
            }
        }
        .padding(GravitySpacing.space20)
    }
    .background(GravityColors.bg)
}

#Preview("Press scale") {
    VStack(spacing: GravitySpacing.space16) {
        Button("Default scale (0.96)") {}
            .buttonStyle(PressScaleButtonStyle())
            .padding(GravitySpacing.space16)
            .background(GravityColors.bgFillSecondary, in: Capsule())
        Button("Strong scale (0.85)") {}
            .buttonStyle(PressScaleButtonStyle(scale: 0.85))
            .padding(GravitySpacing.space16)
            .background(GravityColors.bgFillSecondary, in: Capsule())
    }
    .padding()
    .background(GravityColors.bg)
}
