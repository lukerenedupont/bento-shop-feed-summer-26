import UIKit

public extension GravityTextStyle {
    var uiFont: UIFont {
        GravityFonts.registerIfNeeded()

        return UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
    }

    var scaledUIFont: UIFont {
        UIFontMetrics(forTextStyle: uiTextStyle).scaledFont(for: uiFont)
    }

    /// Scales the font for an explicit content size category rather than the current device setting,
    /// so layout can be measured for a size other than the one the app is running at.
    func scaledUIFont(for contentSizeCategory: UIContentSizeCategory) -> UIFont {
        UIFontMetrics(forTextStyle: uiTextStyle).scaledFont(
            for: uiFont,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: contentSizeCategory)
        )
    }

    private var uiTextStyle: UIFont.TextStyle {
        switch relativeTextStyle {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .caption: .caption1
        case .caption2: .caption2
        case .footnote: .footnote
        @unknown default: .body
        }
    }
}
