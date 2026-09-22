import SwiftUI

// MARK: - Seams

/// Injection seam for reactive on-device content translation. `Gravity` stays
/// business-logic free: it defines only this protocol and the environment accessor.
///
/// The seam is class-bound on purpose. SwiftUI compares environment values to decide which
/// readers to invalidate, and a class-bound existential compares by identity (measured in
/// `ShopTranslatableTextInvalidationTests`), so the app injects one object for the app
/// lifetime and rewriting it into the environment does not re-evaluate readers. A value type
/// carrying a closure would compare as "changed" on every write and invalidate every reader.
///
/// Only `ShopTranslatableText` and the few custom merchant-content views read this seam.
/// `ShopText` never does: it is a pure value leaf and has no translation behavior.
///
/// `translation(for:)` returns the genuine translation for a source string, or nil when the
/// feature is inactive or no translation exists. Implementations should keep the observable
/// reads made inside this method narrow (a per-key entry plus a stored availability flag), as
/// every reading text node subscribes to exactly what is read here.
@MainActor
public protocol GravityContentTranslator: AnyObject, Sendable {
    func translation(for content: String) -> String?
}

/// Per-surface "view translation / view original" toggle. Class-bound for the same identity
/// reason as `GravityContentTranslator`; the app injects the surface's own long-lived display
/// object. `showsTranslated` is read only after a genuine translation has been found, so text
/// without a translation never subscribes to the toggle.
@MainActor
public protocol GravityContentTranslationDisplay: AnyObject, Sendable {
    var showsTranslated: Bool { get }
}

private struct GravityContentTranslatorKey: EnvironmentKey {
    static let defaultValue: (any GravityContentTranslator)? = nil
}

private struct GravityContentTranslationDisplayKey: EnvironmentKey {
    static let defaultValue: (any GravityContentTranslationDisplay)? = nil
}

public extension EnvironmentValues {
    var gravityContentTranslator: (any GravityContentTranslator)? {
        get { self[GravityContentTranslatorKey.self] }
        set { self[GravityContentTranslatorKey.self] = newValue }
    }

    var gravityContentTranslationDisplay: (any GravityContentTranslationDisplay)? {
        get { self[GravityContentTranslationDisplayKey.self] }
        set { self[GravityContentTranslationDisplayKey.self] = newValue }
    }
}

// MARK: - Resolution

/// Resolution rules shared by `ShopTranslatableText` and the custom merchant-content views
/// that must transform or lay out translated content themselves (HTML descriptions, trimmed
/// variant titles, raw `SwiftUI.Text` chips). Order mirrors the RN `NativeText` translate
/// step: ask for a genuine translation first, and consult the display toggle only when one
/// exists, so text without a translation never subscribes to the toggle.
///
/// Read the two seams with plain `@Environment` properties and pass them in:
///
/// ```swift
/// @Environment(\.gravityContentTranslator) private var translator
/// @Environment(\.gravityContentTranslationDisplay) private var translationDisplay
/// …
/// GravityContentTranslation.resolve(option.value, translator: translator, display: translationDisplay)
/// ```
///
/// This is deliberately not a `DynamicProperty` wrapper: a view holding a custom dynamic
/// property re-evaluates on every parent update (measured), which defeats the pruning the
/// identity-stable seams exist to provide.
public enum GravityContentTranslation {
    /// The translation to display for `content`, or nil to render the source string.
    @MainActor
    public static func translation(
        for content: String,
        translator: (any GravityContentTranslator)?,
        display: (any GravityContentTranslationDisplay)?
    ) -> String? {
        guard let translator, let translated = translator.translation(for: content) else { return nil }
        if let display, display.showsTranslated == false { return nil }
        return translated
    }

    /// The string to display for `content`: its translation when one should be shown,
    /// otherwise `content` itself.
    @MainActor
    public static func resolve(
        _ content: String,
        translator: (any GravityContentTranslator)?,
        display: (any GravityContentTranslationDisplay)?
    ) -> String {
        translation(for: content, translator: translator, display: display) ?? content
    }
}

// MARK: - Primitive

/// Semantic text for merchant content that may have an on-device translation.
///
/// This is the explicit opt-in boundary: only strings sourced from translatable merchant
/// fields (product/variant titles, option names and values, descriptions, review titles)
/// should render through it. App copy and everything else uses `ShopText`, which is a pure
/// value leaf and never resolves translations.
///
/// Structure: this outer view has no dynamic properties and stores only a `String` and a
/// padding-free `GravityTextConfiguration`, so SwiftUI prunes it exactly like `ShopText`. It
/// delegates the environment read to `ShopTranslatedString`, whose stored value is the source
/// string plus one reference, and applies styling around it with `TextModifier`. Every value
/// on this path is byte-comparable, which is what lets a parent re-render leave the
/// environment-reading node untouched (see `GravityTextConfiguration`).
///
/// Dependency graph of the inner node, in order: the translator's stored availability flag,
/// this string's own per-key translation entry, and the surface display toggle only when a
/// genuine translation exists.
public struct ShopTranslatableText: View, Equatable {
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
        ShopTranslatedString(
            content,
            transform: configuration.style.isUppercased ? .uppercased : .none
        )
        .modifier(TextModifier(configuration: configuration))
    }
}

/// Post-resolution transform for `ShopTranslatedString`. A reference type so the stored field
/// compares by identity; a 1-byte enum here would reintroduce the padding problem described on
/// `GravityTextConfiguration`. Define transforms as shared `static let` instances (never inline
/// in a `body`) so the identity is stable across evaluations.
public final class GravityTextTransform: Sendable {
    public static let none = GravityTextTransform { $0 }
    public static let uppercased = GravityTextTransform { $0.uppercased() }

    private let apply: @Sendable (String) -> String

    public init(_ apply: @escaping @Sendable (String) -> String) {
        self.apply = apply
    }

    public func callAsFunction(_ value: String) -> String {
        apply(value)
    }
}

/// The one environment-reading node in the translatable text path. Stores only the source
/// string and a transform reference. Renders `Text`.
///
/// Always place it behind a static, padding-free outer value (`ShopTranslatableText`, or a
/// view shaped like `ShopCartVariantTitleText`: `String` + `GravityTextConfiguration`). The
/// outer value absorbs the parent's re-render compare, so this node is never re-created and
/// resolves only when its translation, availability, or display toggle changes. Placed
/// directly inside a frequently re-rendering parent it re-resolves on every parent update,
/// because SwiftUI's byte-wise compare includes padding inside `@Environment` storage
/// (measured: 6/6 re-renders bare versus 0/6 wrapped).
public struct ShopTranslatedString: View {
    private let content: String
    private let transform: GravityTextTransform

    @Environment(\.gravityContentTranslator) private var translator
    @Environment(\.gravityContentTranslationDisplay) private var display

    public init(_ content: String, transform: GravityTextTransform = .none) {
        self.content = content
        self.transform = transform
    }

    public var body: Text {
        Text(transform(GravityContentTranslation.resolve(content, translator: translator, display: display)))
    }
}
