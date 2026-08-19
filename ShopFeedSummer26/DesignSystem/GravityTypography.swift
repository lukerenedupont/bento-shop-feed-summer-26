import SwiftUI

/// Shared editorial display type for feed cards and their expanded topic
/// surfaces. Compact enough for short titles to remain on one line.
enum FeedEditorialTypography {
    private static let titleStyle = GravityTypography.expressiveH7Heavy
    private static let homeCardTitleStyle = GravityTypography.expressiveH7Heavy
    private static let sectionStyle = GravityTypography.header

    static let titleFont = titleStyle.swiftUIFont
    static let titleTracking = titleStyle.letterSpacing
    /// GT Standard L carries generous built-in leading in SwiftUI. Pull
    /// multiline editorial headers back together so they read as one title.
    static let titleLineSpacing: CGFloat = -14

    static let homeCardTitleFont = homeCardTitleStyle.swiftUIFont
    static let homeCardTitleTracking = homeCardTitleStyle.letterSpacing
    static let homeCardTitleLineSpacing: CGFloat = -14

    static let sectionFont = sectionStyle.swiftUIFont
    static let sectionTracking = sectionStyle.letterSpacing
    static let sectionLineSpacing: CGFloat = -10
    static let titleLineTightening: CGFloat = 8
    static let homeCardTitleLineTightening: CGFloat = 4
    static let sectionLineTightening: CGFloat = 6
}

/// SwiftUI clamps large negative `lineSpacing` values. Draw each subsequent
/// line slightly higher instead so GT Standard keeps the compact leading used
/// by Shop's editorial headers even when the title wraps dynamically.
private struct TightLineHeightRenderer: TextRenderer {
    let tightening: CGFloat

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for (index, line) in layout.enumerated() {
            var lineContext = context
            lineContext.translateBy(
                x: 0,
                y: -CGFloat(index) * tightening
            )
            lineContext.draw(line)
        }
    }
}

extension View {
    /// The single display treatment for titles on every full-height feed card.
    /// Keeping this at the design-system layer prevents buyer, topic, merchant,
    /// and post variants from drifting away from the original Luke treatment.
    func feedCardTitleStyle() -> some View {
        self
            .font(FeedEditorialTypography.homeCardTitleFont)
            .tracking(FeedEditorialTypography.homeCardTitleTracking)
            .lineSpacing(FeedEditorialTypography.homeCardTitleLineSpacing)
            .tightMultilineLeading(FeedEditorialTypography.homeCardTitleLineTightening)
    }

    func tightMultilineLeading(_ tightening: CGFloat) -> some View {
        textRenderer(TightLineHeightRenderer(tightening: tightening))
    }
}

// MARK: - Font Weights

/// GT Standard font family weights.
/// TODO: Bundle GT Standard font files in the app target or ensure they're installed on the system.
enum GravityFont: String {
    case regular = "GTStandard-MRegular"
    case medium = "GTStandard-MMedium"
    case semiBold = "GTStandard-MSemibold"
    case bold = "GTStandard-MBold"
    case expressiveSemiBold = "GTStandard-LSemibold"
    case expressiveBold = "GTStandard-LHeavy"

    func font(size: CGFloat) -> Font {
        .custom(rawValue, size: size, relativeTo: .body)
    }

    func fixedFont(size: CGFloat) -> Font {
        .custom(rawValue, fixedSize: size)
    }
}

// MARK: - Letter Spacing

enum GravityLetterSpacing {
    static let loose: CGFloat = 0.15
    static let none: CGFloat = 0
    static let cozy: CGFloat = -0.2
    static let tight: CGFloat = -0.5
    static let tighter: CGFloat = -1.0
    static let slammed: CGFloat = -1.5
    static let superTight: CGFloat = -1.75
}

// MARK: - Text Style

struct GravityTextStyle {
    let font: GravityFont
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let letterSpacing: CGFloat
    let textCase: Text.Case?

    init(
        font: GravityFont,
        fontSize: CGFloat,
        lineHeight: CGFloat,
        letterSpacing: CGFloat,
        textCase: Text.Case? = nil
    ) {
        self.font = font
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.letterSpacing = letterSpacing
        self.textCase = textCase
    }

    /// Line spacing = lineHeight - fontSize (clamped to 0)
    var lineSpacing: CGFloat {
        max(lineHeight - fontSize, 0)
    }

    var swiftUIFont: Font {
        font.fixedFont(size: fontSize)
    }
}

// MARK: - Text Variants

/// All text style variants from Gravity's textVariants.ts.
/// Uses "phone" sizes (not smallPhone).
enum GravityTypography {

    // MARK: Expressive (GT Standard L)

    /// Expressive Semibold h7 from Gravity: GT Standard L Semibold, 32/36, -0.5.
    static let expressiveH7 = GravityTextStyle(
        font: .expressiveSemiBold, fontSize: 32, lineHeight: 36, letterSpacing: GravityLetterSpacing.tight
    )
    static let expressiveH7Heavy = GravityTextStyle(
        font: .expressiveBold, fontSize: 32, lineHeight: 36, letterSpacing: GravityLetterSpacing.tight
    )
    /// Compact utility-rail title from the top-of-feed card specification.
    static let utilityCardTitle = GravityTextStyle(
        font: .expressiveBold, fontSize: 24, lineHeight: 26, letterSpacing: GravityLetterSpacing.tight
    )

    static let posterLarge = GravityTextStyle(
        font: .expressiveBold, fontSize: 64, lineHeight: 58, letterSpacing: GravityLetterSpacing.tighter
    )
    static let posterMedium = GravityTextStyle(
        font: .expressiveBold, fontSize: 54, lineHeight: 54, letterSpacing: GravityLetterSpacing.tighter
    )
    static let posterSmall = GravityTextStyle(
        font: .expressiveBold, fontSize: 48, lineHeight: 50, letterSpacing: GravityLetterSpacing.tighter
    )
    static let posterXS = GravityTextStyle(
        font: .expressiveBold, fontSize: 36, lineHeight: 38, letterSpacing: GravityLetterSpacing.tighter
    )
    static let posterLargeWeightMedium = GravityTextStyle(
        font: .expressiveBold, fontSize: 64, lineHeight: 56, letterSpacing: GravityLetterSpacing.tighter
    )
    static let brandTextLarge = GravityTextStyle(
        font: .expressiveBold, fontSize: 16, lineHeight: 22, letterSpacing: GravityLetterSpacing.tighter
    )
    static let brandTextSmall = GravityTextStyle(
        font: .expressiveBold, fontSize: 14, lineHeight: 18, letterSpacing: GravityLetterSpacing.tighter
    )

    // MARK: Headers

    static let heroBold = GravityTextStyle(
        font: .bold, fontSize: 36, lineHeight: 42, letterSpacing: GravityLetterSpacing.slammed
    )
    static let heroNormal = GravityTextStyle(
        font: .semiBold, fontSize: 36, lineHeight: 42, letterSpacing: GravityLetterSpacing.slammed
    )
    static let header = GravityTextStyle(
        font: .bold, fontSize: 28, lineHeight: 30, letterSpacing: GravityLetterSpacing.superTight
    )
    static let heroSmall = GravityTextStyle(
        font: .semiBold, fontSize: 24, lineHeight: 42, letterSpacing: GravityLetterSpacing.slammed
    )
    static let headerExtraBold = GravityTextStyle(
        font: .bold, fontSize: 24, lineHeight: 24, letterSpacing: GravityLetterSpacing.tighter
    )
    static let headerBold = GravityTextStyle(
        font: .semiBold, fontSize: 24, lineHeight: 26, letterSpacing: GravityLetterSpacing.tighter
    )
    static let headerNormal = GravityTextStyle(
        font: .regular, fontSize: 24, lineHeight: 26, letterSpacing: GravityLetterSpacing.tighter
    )
    static let sectionTitle = GravityTextStyle(
        font: .semiBold, fontSize: 20, lineHeight: 22, letterSpacing: GravityLetterSpacing.tighter
    )
    static let subtitle = GravityTextStyle(
        font: .semiBold, fontSize: 18, lineHeight: 20, letterSpacing: GravityLetterSpacing.tight
    )
    static let subtitleSmall = GravityTextStyle(
        font: .semiBold, fontSize: 14, lineHeight: 18, letterSpacing: GravityLetterSpacing.cozy
    )
    // MARK: Body

    static let bodyTitleLarge = GravityTextStyle(
        font: .semiBold, fontSize: 16, lineHeight: 22, letterSpacing: GravityLetterSpacing.tight
    )
    static let bodyTitleSmall = GravityTextStyle(
        font: .semiBold, fontSize: 14, lineHeight: 18, letterSpacing: GravityLetterSpacing.cozy
    )
    static let bodyLarge = GravityTextStyle(
        font: .regular, fontSize: 16, lineHeight: 22, letterSpacing: GravityLetterSpacing.tight
    )
    static let bodyLargeBold = GravityTextStyle(
        font: .medium, fontSize: 16, lineHeight: 22, letterSpacing: GravityLetterSpacing.tight
    )
    static let bodySmall = GravityTextStyle(
        font: .regular, fontSize: 14, lineHeight: 18, letterSpacing: GravityLetterSpacing.cozy
    )
    /// Editorial Curation mobile supporting copy: Text/body, 14/20.
    static let editorialBody = GravityTextStyle(
        font: .regular, fontSize: 14, lineHeight: 20, letterSpacing: GravityLetterSpacing.cozy
    )
    static let bodySmallBold = GravityTextStyle(
        font: .medium, fontSize: 14, lineHeight: 18, letterSpacing: GravityLetterSpacing.cozy
    )

    // MARK: Supporting

    static let caption = GravityTextStyle(
        font: .regular, fontSize: 12, lineHeight: 16, letterSpacing: GravityLetterSpacing.cozy
    )
    static let captionMedium = GravityTextStyle(
        font: .medium, fontSize: 12, lineHeight: 16, letterSpacing: GravityLetterSpacing.cozy
    )
    static let captionBold = GravityTextStyle(
        font: .semiBold, fontSize: 12, lineHeight: 16, letterSpacing: GravityLetterSpacing.cozy
    )
    static let label = GravityTextStyle(
        font: .semiBold, fontSize: 11, lineHeight: 14, letterSpacing: GravityLetterSpacing.tight, textCase: .uppercase
    )
    static let badge = GravityTextStyle(
        font: .regular, fontSize: 10, lineHeight: 13, letterSpacing: GravityLetterSpacing.cozy
    )
    static let badgeBold = GravityTextStyle(
        font: .semiBold, fontSize: 10, lineHeight: 13, letterSpacing: GravityLetterSpacing.cozy
    )

    // MARK: Interactive

    static let buttonLarge = GravityTextStyle(
        font: .semiBold, fontSize: 16, lineHeight: 20, letterSpacing: GravityLetterSpacing.tight
    )
    static let buttonMedium = GravityTextStyle(
        font: .semiBold, fontSize: 14, lineHeight: 16, letterSpacing: GravityLetterSpacing.cozy
    )
    static let buttonSmall = GravityTextStyle(
        font: .semiBold, fontSize: 12, lineHeight: 16, letterSpacing: GravityLetterSpacing.cozy
    )
    static let navigationTitle = GravityTextStyle(
        font: .medium, fontSize: 18, lineHeight: 24, letterSpacing: GravityLetterSpacing.cozy
    )
}

// MARK: - GoodSans Font Family

enum GoodSansFont: String {
    case regular = "GoodSans-Regular"
    case medium = "GoodSans-Medium"
    case bold = "GoodSans-Bold"

    func font(size: CGFloat) -> Font {
        .custom(rawValue, size: size, relativeTo: .body)
    }

    func fixedFont(size: CGFloat) -> Font {
        .custom(rawValue, fixedSize: size)
    }
}

// MARK: - GoodSans Text Font Family

enum GoodSansTextFont: String {
    case regular = "GoodSansText-Regular"
    case medium = "GoodSansText-Medium"
    case bold = "GoodSansText-Bold"

    func font(size: CGFloat) -> Font {
        .custom(rawValue, size: size, relativeTo: .body)
    }

    func fixedFont(size: CGFloat) -> Font {
        .custom(rawValue, fixedSize: size)
    }
}

// MARK: - Shopify Sans Font Family

enum ShopifySansFont: String {
    case light = "ShopifySans-Light"
    case lightItalic = "ShopifySans-LightItalic"
    case regular = "ShopifySans-Regular"
    case regularItalic = "ShopifySans-RegularItalic"
    case medium = "ShopifySans-Medium"
    case mediumItalic = "ShopifySans-MediumItalic"
    case bold = "ShopifySans-Bold"
    case boldItalic = "ShopifySans-BoldItalic"
    case black = "ShopifySans-Black"
    case blackItalic = "ShopifySans-BlackItalic"

    func font(size: CGFloat) -> Font {
        .custom(rawValue, size: size, relativeTo: .body)
    }

    func fixedFont(size: CGFloat) -> Font {
        .custom(rawValue, fixedSize: size)
    }
}

// MARK: - View Extension

extension View {
    /// Applies a Gravity text style (font, tracking, line spacing, text case).
    func gravityTextStyle(_ style: GravityTextStyle) -> some View {
        self
            .font(style.swiftUIFont)
            .tracking(style.letterSpacing)
            .lineSpacing(style.lineSpacing)
            .textCase(style.textCase)
    }
}

#Preview("Type specimen") {
    struct Specimen: View {
        let name: String
        let style: GravityTextStyle
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(GravityColors.textTertiary)
                    .textCase(.uppercase)
                Text("The quick brown fox jumps")
                    .gravityTextStyle(style)
                    .foregroundStyle(GravityColors.text)
            }
        }
    }

    return ScrollView {
        VStack(alignment: .leading, spacing: GravitySpacing.space20) {
            Group {
                Text("Expressive (GT Standard L Heavy)").gravityTextStyle(GravityTypography.bodyTitleSmall)
                Specimen(name: "posterLarge / 64", style: GravityTypography.posterLarge)
                Specimen(name: "posterMedium / 54", style: GravityTypography.posterMedium)
                Specimen(name: "posterSmall / 48", style: GravityTypography.posterSmall)
                Specimen(name: "posterXS / 36", style: GravityTypography.posterXS)
            }
            Group {
                Text("Headers").gravityTextStyle(GravityTypography.bodyTitleSmall)
                Specimen(name: "heroBold / 36", style: GravityTypography.heroBold)
                Specimen(name: "header / 28 bold", style: GravityTypography.header)
                Specimen(name: "headerExtraBold / 24 bold", style: GravityTypography.headerExtraBold)
                Specimen(name: "headerBold / 24 semibold", style: GravityTypography.headerBold)
                Specimen(name: "headerNormal / 24 regular", style: GravityTypography.headerNormal)
                Specimen(name: "sectionTitle / 20", style: GravityTypography.sectionTitle)
                Specimen(name: "subtitle / 18", style: GravityTypography.subtitle)
                Specimen(name: "subtitleSmall / 14", style: GravityTypography.subtitleSmall)
            }
            Group {
                Text("Body").gravityTextStyle(GravityTypography.bodyTitleSmall)
                Specimen(name: "bodyTitleLarge / 16", style: GravityTypography.bodyTitleLarge)
                Specimen(name: "bodyTitleSmall / 14", style: GravityTypography.bodyTitleSmall)
                Specimen(name: "bodyLarge / 16", style: GravityTypography.bodyLarge)
                Specimen(name: "bodyLargeBold / 16", style: GravityTypography.bodyLargeBold)
                Specimen(name: "bodySmall / 14", style: GravityTypography.bodySmall)
                Specimen(name: "bodySmallBold / 14", style: GravityTypography.bodySmallBold)
            }
            Group {
                Text("Supporting & Interactive").gravityTextStyle(GravityTypography.bodyTitleSmall)
                Specimen(name: "caption / 12", style: GravityTypography.caption)
                Specimen(name: "captionBold / 12", style: GravityTypography.captionBold)
                Specimen(name: "label / 11 uppercase", style: GravityTypography.label)
                Specimen(name: "badge / 10", style: GravityTypography.badge)
                Specimen(name: "buttonLarge / 16", style: GravityTypography.buttonLarge)
                Specimen(name: "buttonMedium / 14", style: GravityTypography.buttonMedium)
                Specimen(name: "buttonSmall / 12", style: GravityTypography.buttonSmall)
                Specimen(name: "navigationTitle / 18", style: GravityTypography.navigationTitle)
            }
        }
        .padding(GravitySpacing.space16)
    }
    .background(GravityColors.bg)
}
