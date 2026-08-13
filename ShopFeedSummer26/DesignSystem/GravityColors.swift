import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color Palette

/// Raw color palette matching Gravity's palette.ts.
/// Never use these directly in views — use GravityColors semantic tokens instead.
enum Palette {

    enum Purple {
        static let d80 = Color(hex: 0x1B163B)
        static let d60 = Color(hex: 0x322C7D)
        static let d50 = Color(hex: 0x4524DB)
        static let p40 = Color(hex: 0x5433EB)
        static let l30 = Color(hex: 0x6445ED)
        static let l20 = Color(hex: 0x9C83F8)
        static let l10 = Color(hex: 0xDBD1FF)
        static let l5 = Color(hex: 0xEEEAFF)
        static let l2 = Color(hex: 0xF7F5FF)
    }

    enum Grayscale {
        static let d100 = Color(hex: 0x000000)
        static let d93 = Color(hex: 0x121212)
        static let d90 = Color(hex: 0x1A1A1A)
        static let d80 = Color(hex: 0x2A2A2A)
        static let d70 = Color(hex: 0x404040)
        static let d60 = Color(hex: 0x656667)
        static let d50 = Color(hex: 0x6F7071)
        static let l40 = Color(hex: 0xA6A8A9)
        static let l20 = Color(hex: 0xC9CBCC)
        static let l10 = Color(hex: 0xE1E4E5)
        static let l6 = Color(hex: 0xEEF0F1)
        static let l5 = Color(hex: 0xF2F4F5)
        static let l2 = Color(hex: 0xFCFCFC)
        static let l0 = Color(hex: 0xFFFFFF)
    }

    enum GrayscaleOpacity {
        static let d93 = Color.black.opacity(0.93)
        static let d90 = Color.black.opacity(0.9)
        static let d80 = Color.black.opacity(0.83)
        static let d70 = Color.black.opacity(0.75)
        static let d60 = Color.black.opacity(0.6)
        static let d50 = Color.black.opacity(0.56)
        static let d40 = Color.black.opacity(0.4)
        static let d35 = Color.black.opacity(0.35)
        static let d30 = Color.black.opacity(0.3)
        static let d20 = Color.black.opacity(0.2)
        static let d10 = Color.black.opacity(0.1)
        static let d6 = Color(red: 24/255, green: 59/255, blue: 78/255).opacity(0.06)
        static let d5 = Color.black.opacity(0.04)
        static let g4 = Color(red: 40/255, green: 40/255, blue: 40/255).opacity(0.3)
        static let l93 = Color.white.opacity(0.93)
        static let l90 = Color.white.opacity(0.9)
        static let l80 = Color.white.opacity(0.83)
        static let l70 = Color.white.opacity(0.75)
        static let l60 = Color.white.opacity(0.6)
        static let l50 = Color.white.opacity(0.56)
        static let l40 = Color.white.opacity(0.4)
        static let l35 = Color.white.opacity(0.35)
        static let l30 = Color.white.opacity(0.3)
        static let l20 = Color.white.opacity(0.2)
        static let l10 = Color.white.opacity(0.1)
        static let l6 = Color.white.opacity(0.06)
        static let l5 = Color.white.opacity(0.04)
    }

    enum Green {
        static let d90 = Color(hex: 0x002E24)
        static let d80 = Color(hex: 0x004839)
        static let d70 = Color(hex: 0x008552)
        static let l30 = Color(hex: 0x92D08D)
        static let l20 = Color(hex: 0xBAEBCB)
        static let l10 = Color(hex: 0xD2F2DE)
        static let l5 = Color(hex: 0xE4F6EB)
    }

    enum Poppy {
        static let d80 = Color(hex: 0x481609)
        static let d70 = Color(hex: 0x832711)
        static let d50 = Color(hex: 0xD92A0F)
        static let l40 = Color(hex: 0xF05D38)
        static let l20 = Color(hex: 0xFF967D)
        static let l10 = Color(hex: 0xFFD2C2)
        static let l4 = Color(hex: 0xFFECE9)
    }

    enum Ochre {
        static let d90 = Color(hex: 0x443600)
        static let d70 = Color(hex: 0x8C6E01)
        static let d60 = Color(hex: 0xC29D05)
        static let l50 = Color(hex: 0xE3BE2B)
        static let l30 = Color(hex: 0xF8DB67)
        static let l20 = Color(hex: 0xFFEC9F)
        static let l10 = Color(hex: 0xFFF4CB)
        static let l6 = Color(hex: 0xFFF9E2)
    }

    enum Brand {
        static let aqua = Color(hex: 0x8DC0C6)
        static let violet = Color(hex: 0xA327C2)
        static let magenta = Color(hex: 0xD354FF)
        static let olive = Color(hex: 0x8B8F01)
        static let lime = Color(hex: 0xC7DE00)
        static let sage = Color(hex: 0xD8E59D)
        static let sand = Color(hex: 0xF4F4ED)
    }

    enum OxBlood {
        static let d80 = Color(hex: 0x3D0517)
        static let d70 = Color(hex: 0x5A071F)
        static let d60 = Color(hex: 0x6F0929)
        static let d50 = Color(hex: 0x830B31)
        static let p40 = Color(hex: 0x970D38)
        static let l30 = Color(hex: 0xB8456A)
        static let l20 = Color(hex: 0xD97B9E)
        static let l10 = Color(hex: 0xEDB3CD)
        static let l5 = Color(hex: 0xF6D9E6)
        static let l2 = Color(hex: 0xFCF1F5)
    }
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// Creates an adaptive color that automatically switches between light and dark variants.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Semantic Color Tokens

/// Semantic color tokens that adapt to light/dark mode.
/// Maps 1:1 to Gravity's themeColors.ts.
struct GravityColors {

    // MARK: Text

    static let text = Color(light: Palette.Grayscale.d100, dark: Palette.Grayscale.l0)
    static let textSecondary = Color(light: Palette.GrayscaleOpacity.d70, dark: Palette.GrayscaleOpacity.l70)
    static let textTertiary = Color(light: Palette.GrayscaleOpacity.d50, dark: Palette.GrayscaleOpacity.l50)
    static let textPlaceholder = Color(light: Palette.GrayscaleOpacity.d40, dark: Palette.GrayscaleOpacity.l40)
    static let textSecondaryInverse = Color(light: Palette.GrayscaleOpacity.l70, dark: Palette.GrayscaleOpacity.d70)
    static let textInverse = Color(light: Palette.Grayscale.l0, dark: Palette.Grayscale.d100)
    static let textBrand = Color(light: Palette.Purple.p40, dark: Palette.Purple.l20)
    static let textBrandSecondary = Color(light: Palette.Purple.l20, dark: Palette.Purple.l10)
    static let textSuccess = Palette.Green.d80
    static let textSuccessSecondary = Color(light: Palette.Green.d70, dark: Palette.Green.l30)
    static let textSuccessTertiary = Palette.Green.l20
    static let textCaution = Palette.Poppy.d70
    static let textCritical = Color(light: Palette.Poppy.d50, dark: Palette.Poppy.l40)
    static let textFixedDark = Palette.Grayscale.d100
    static let textFixedLight = Palette.Grayscale.l0
    static let textFixedLightSecondary = Palette.Grayscale.l20
    static let textFixedBrand = Palette.Purple.p40
    static let iconStars = Palette.Ochre.l50
    static let textAgent = Color(hex: 0x77728D)
    static let textAgentEmphasis = Color(light: Color(hex: 0x545071), dark: Color(hex: 0xBAB3D5))

    // MARK: Background

    static let bg = Color(light: Palette.Grayscale.l2, dark: Palette.Grayscale.d93)
    static let bgBrand = Palette.Purple.p40
    static let bgInverse = Color(light: Palette.Grayscale.d93, dark: Palette.Grayscale.l0)

    // MARK: Background Fill

    static let bgFill = Color(light: Palette.Grayscale.l0, dark: Palette.Grayscale.d93)
    static let bgFillSecondary = Color(light: Palette.Grayscale.l5, dark: Palette.Grayscale.d80)
    static let bgFillTertiary = Color(light: Palette.Grayscale.l20, dark: Palette.Grayscale.d70)
    static let bgFillPlaceholder = Color(light: Palette.Grayscale.l6, dark: Palette.Grayscale.d70)
    static let bgFillActive = Color(light: Palette.Grayscale.d50, dark: Palette.Grayscale.l20)
    static let bgFillInverse = Color(light: Palette.Grayscale.d93, dark: Palette.Grayscale.l0)
    static let bgFillBrand = Palette.Purple.p40
    static let bgFillBrandSecondary = Color(light: Palette.Purple.l5, dark: Palette.Purple.d80)
    static let bgFillBrandTertiary = Palette.Brand.sand
    static let bgFillSuccess = Palette.Green.d70
    static let bgFillSuccessSecondary = Palette.Green.l30
    static let bgFillSuccessTertiary = Palette.Green.l20
    static let bgFillSuccessInverse = Color(light: Palette.Green.l5, dark: Palette.Green.d80)
    static let bgFillCaution = Palette.Ochre.l6
    static let bgFillCritical = Palette.Poppy.d50
    static let bgFillCriticalSecondary = Palette.Poppy.l4
    static let bgFillFixedHighlight = Palette.Purple.l10
    static let bgFillFixedDark = Palette.Grayscale.d100
    static let bgFillFixedDusk = Palette.Grayscale.d70
    static let bgFillFixedLight = Palette.Grayscale.l0
    static let bgFillAgent = Color(light: Color(hex: 0xF7F7F8), dark: Color(hex: 0x26262C))

    // MARK: Background Fill Hover

    static let bgFillHover = Color(light: Palette.Grayscale.l5, dark: Palette.Grayscale.d80)
    static let bgFillSecondaryHover = Color(light: Palette.Grayscale.l10, dark: Palette.Grayscale.d70)
    static let bgFillInverseHover = Color(light: Palette.Grayscale.d80, dark: Palette.Grayscale.l20)
    static let bgFillBrandHover = Palette.Purple.d50
    static let bgFillSuccessHover = Palette.Green.d80
    static let bgFillFloat = Color(light: Palette.Grayscale.l0, dark: Palette.Grayscale.d90)
    static let bgFillCriticalHover = Palette.Poppy.d70
    static let bgFillOutlinedCriticalHover = Color(light: Palette.Poppy.l4, dark: Palette.Poppy.d80)

    // MARK: Overlays

    static let bgOverlayFixedDark04 = Palette.GrayscaleOpacity.d5
    static let bgOverlayFixedDark06 = Palette.GrayscaleOpacity.d6
    static let bgOverlayFixedDark10 = Palette.GrayscaleOpacity.d10
    static let bgOverlayFixedDark20 = Palette.GrayscaleOpacity.d20
    static let bgOverlayFixedDark30 = Palette.GrayscaleOpacity.d30
    static let bgOverlayFixedDark40 = Palette.GrayscaleOpacity.d40
    static let bgOverlayFixedDark60 = Palette.GrayscaleOpacity.d60
    static let bgOverlayFixedDark75 = Palette.GrayscaleOpacity.d70
    static let bgOverlayFixedLight04 = Palette.GrayscaleOpacity.l5
    static let bgOverlayFixedLight10 = Palette.GrayscaleOpacity.l10
    static let bgOverlayFixedLight20 = Palette.GrayscaleOpacity.l20
    static let bgOverlayFixedLight40 = Palette.GrayscaleOpacity.l40
    static let bgOverlayFixedLight60 = Palette.GrayscaleOpacity.l60
    static let bgOverlayFixedLight75 = Palette.GrayscaleOpacity.l70
    static let bgOverlayFixedIcon = Palette.GrayscaleOpacity.g4
    static let bgOverlayInverse04 = Color(light: Palette.GrayscaleOpacity.d5, dark: Palette.GrayscaleOpacity.l5)
    static let bgOverlayInverse06 = Color(light: Palette.GrayscaleOpacity.d6, dark: Palette.GrayscaleOpacity.l6)
    static let bgOverlayHighlight = Color(light: Palette.GrayscaleOpacity.d10, dark: Palette.GrayscaleOpacity.l10)
    static let bgOverlayHighlightHover = Color(light: Palette.GrayscaleOpacity.d20, dark: Palette.GrayscaleOpacity.l20)
    static let bgOverlayHighlightInverse = Color(light: Palette.GrayscaleOpacity.l10, dark: Palette.GrayscaleOpacity.d10)

    // MARK: Shadows

    static let shadow100 = Color(light: Palette.GrayscaleOpacity.d6, dark: Palette.GrayscaleOpacity.d5)
    static let shadow200 = Color(light: Color.black.opacity(0.12), dark: Color.black.opacity(0.48))
    static let shadow300 = Color(light: Color.black.opacity(0.16), dark: Color.black.opacity(0.64))
    static let shadow400 = Color(light: Color.black.opacity(0.24), dark: Color.black.opacity(0.80))

    // MARK: Borders

    static let border = Color(light: Palette.GrayscaleOpacity.d10, dark: Palette.GrayscaleOpacity.l20)
    static let borderSecondary = Color(light: Palette.GrayscaleOpacity.d6, dark: Palette.GrayscaleOpacity.l10)
    static let borderTertiary = Color(light: Palette.GrayscaleOpacity.d5, dark: Palette.GrayscaleOpacity.l5)
    static let borderBrand = Palette.Purple.p40
    static let borderBrandSecondary = Palette.Purple.l10
    static let borderCritical = Color(light: Palette.Poppy.d50, dark: Palette.Poppy.l40)
    static let borderImage = Color(light: Color(red: 5/255, green: 41/255, blue: 77/255).opacity(0.1), dark: Color.white.opacity(0.15))
    static let borderInput = Color(light: Palette.GrayscaleOpacity.d20, dark: Palette.GrayscaleOpacity.l40)
    static let borderInputActive = Color(light: Palette.Grayscale.d100, dark: Palette.Grayscale.l0)
    static let borderInputBrandFocus = Palette.Purple.p40
}

#Preview("Semantic tokens") {
    struct Swatch: View {
        let name: String
        let color: Color
        var body: some View {
            HStack(spacing: GravitySpacing.space12) {
                RoundedRectangle(cornerRadius: GravityRadius.r8)
                    .fill(color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: GravityRadius.r8)
                            .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
                    )
                Text(name)
                    .gravityTextStyle(GravityTypography.bodySmall)
                    .foregroundStyle(GravityColors.text)
                Spacer()
            }
        }
    }

    return ScrollView {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            Group {
                Text("Text").gravityTextStyle(GravityTypography.subtitle)
                Swatch(name: "text", color: GravityColors.text)
                Swatch(name: "textSecondary", color: GravityColors.textSecondary)
                Swatch(name: "textTertiary", color: GravityColors.textTertiary)
                Swatch(name: "textBrand", color: GravityColors.textBrand)
                Swatch(name: "textCritical", color: GravityColors.textCritical)
                Swatch(name: "textSuccess", color: GravityColors.textSuccess)
            }
            Group {
                Text("Background").gravityTextStyle(GravityTypography.subtitle)
                Swatch(name: "bg", color: GravityColors.bg)
                Swatch(name: "bgFill", color: GravityColors.bgFill)
                Swatch(name: "bgFillSecondary", color: GravityColors.bgFillSecondary)
                Swatch(name: "bgFillTertiary", color: GravityColors.bgFillTertiary)
                Swatch(name: "bgFillBrand", color: GravityColors.bgFillBrand)
                Swatch(name: "bgFillCritical", color: GravityColors.bgFillCritical)
                Swatch(name: "bgFillSuccess", color: GravityColors.bgFillSuccess)
            }
            Group {
                Text("Border").gravityTextStyle(GravityTypography.subtitle)
                Swatch(name: "border", color: GravityColors.border)
                Swatch(name: "borderSecondary", color: GravityColors.borderSecondary)
                Swatch(name: "borderBrand", color: GravityColors.borderBrand)
                Swatch(name: "borderCritical", color: GravityColors.borderCritical)
            }
        }
        .padding(GravitySpacing.space16)
    }
    .background(GravityColors.bg)
}
