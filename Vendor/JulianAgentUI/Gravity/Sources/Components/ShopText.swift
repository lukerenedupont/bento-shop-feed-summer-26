import SwiftUI

/// Semantic text primitive. A pure value leaf: it renders exactly the string it is given,
/// stores only a `String` and a padding-free `GravityTextConfiguration`, and reads nothing from
/// the environment, so SwiftUI prunes it whenever its inputs are unchanged and no unrelated
/// update can re-evaluate it.
///
/// This is the most used view in the app, so it must stay free of dynamic properties and
/// lookups, and its stored layout must stay byte-comparable (see `GravityTextConfiguration`).
/// Merchant content that may have an on-device translation opts in explicitly via
/// `ShopTranslatableText`; `ShopText` has no translation behavior.
public struct ShopText: View, Equatable {
    private let content: String
    private let configuration: GravityTextConfiguration

    public init(
        _ content: String,
        style: GravityTextStyle = .bodyLarge,
        color: Color = GravityColor.text,
        alignment: TextAlignment = .leading,
        lineSpacing: CGFloat? = nil
    ) {
        self.content = content
        configuration = GravityTextConfiguration(
            style: style,
            color: color,
            alignment: alignment,
            lineSpacing: lineSpacing
        )
    }

    public var body: some View {
        SwiftUI.Text(configuration.style.isUppercased ? content.uppercased() : content)
            .modifier(TextModifier(configuration: configuration))
    }
}

public extension View {
    /// Applies a Gravity text style. Works on any text-bearing view: `TextModifier` uses the
    /// `View`-level `kerning`/`lineSpacing`/`multilineTextAlignment` modifiers, which `Text`
    /// resolves from the environment.
    @MainActor
    func gravityTextStyle(
        _ style: GravityTextStyle,
        color: Color = GravityColor.text,
        alignment: TextAlignment = .leading,
        lineSpacing: CGFloat? = nil
    ) -> some View {
        modifier(
            TextModifier(
                configuration: GravityTextConfiguration(
                    style: style,
                    color: color,
                    alignment: alignment,
                    lineSpacing: lineSpacing
                )
            )
        )
    }

    /// Applies an already-built configuration; prefer this when the caller stores one.
    @MainActor
    func gravityTextStyle(_ configuration: GravityTextConfiguration) -> some View {
        modifier(TextModifier(configuration: configuration))
    }
}

/// Applies a `GravityTextConfiguration`. Stores only the padding-free configuration so the
/// modifier value itself prunes when unchanged.
struct TextModifier: ViewModifier {
    let configuration: GravityTextConfiguration

    func body(content: Content) -> some View {
        content
            .font(configuration.style.font)
            .kerning(configuration.style.kerning)
            .foregroundStyle(configuration.color)
            .lineSpacing(configuration.resolvedLineSpacing)
            .multilineTextAlignment(configuration.alignment)
    }
}

#Preview("Styles") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                ShopText("Poster Large", style: .posterLarge)
                ShopText("Hero Bold", style: .heroBold)
                ShopText("Header", style: .header)
                ShopText("Header Bold", style: .headerBold)
                ShopText("Section Title", style: .sectionTitle)
                ShopText("Subtitle", style: .subtitle)
            }

            VStack(alignment: .leading, spacing: 12) {
                ShopText("Body Title Large", style: .bodyTitleLarge)
                ShopText("Body Title Small", style: .bodyTitleSmall)
                ShopText("Body Large", style: .bodyLarge)
                ShopText("Body Large Bold", style: .bodyLargeBold)
                ShopText("Body Small", style: .bodySmall)
                ShopText("Body Small Bold", style: .bodySmallBold)
            }

            VStack(alignment: .leading, spacing: 12) {
                ShopText("Caption", style: .caption)
                ShopText("Caption Medium", style: .captionMedium)
                ShopText("Caption Bold", style: .captionBold)
                ShopText("Label", style: .label)
                ShopText("ShopBadge", style: .badge)
                ShopText("ShopBadge Bold", style: .badgeBold)
            }

            VStack(alignment: .leading, spacing: 12) {
                ShopText("Navigation Title", style: .navigationTitle)
                ShopText("ShopButton Large", style: .buttonLarge)
                ShopText("ShopButton Medium", style: .buttonMedium)
                ShopText("ShopButton Small", style: .buttonSmall)
            }
        }
        .padding()
    }
    .background(GravityColor.bg)
}
