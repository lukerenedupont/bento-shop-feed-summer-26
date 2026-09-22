import SwiftUI

/// The styling inputs of a Gravity text node, stored without padding bytes.
///
/// SwiftUI decides whether a view's `body` must run again by comparing the previous and new
/// view values. For trivially typed fields that comparison is byte-wise and includes the
/// padding Swift inserts between fields, which is left uninitialised. A view that stores a
/// 1-byte enum (`GravityTextStyle`, `TextAlignment`) or an `Optional<CGFloat>` next to padding
/// therefore compares as "changed" on every parent update, and its `body` — and everything
/// the body re-creates — runs again even though nothing changed. This was measured with
/// `Self._printChanges()` in `ShopTranslatableTextInvalidationTests`; the same layout with the
/// padding explicitly filled compares as unchanged.
///
/// `ShopText`, `ShopTranslatableText` and `TextModifier` store their inputs as a `String`,
/// reference types, and this struct, whose three 1-byte fields share one fully initialised
/// 8-byte word with explicit filler. `MemoryLayout` assertions in the tests guard the layout.
/// Keep the field order; Swift lays structs out in declaration order.
public struct GravityTextConfiguration: Equatable, Sendable {
    public let style: GravityTextStyle
    public let alignment: TextAlignment
    private let hasLineSpacing: Bool
    // Explicit filler so bytes 3...7 of the first word are initialised (1 + 1 + 1 + 1 + 4 = 8).
    private let filler8: UInt8 = 0
    private let filler32: UInt32 = 0
    private let lineSpacingValue: CGFloat
    public let color: Color

    public init(
        style: GravityTextStyle,
        color: Color = GravityColor.text,
        alignment: TextAlignment = .leading,
        lineSpacing: CGFloat? = nil
    ) {
        self.style = style
        self.alignment = alignment
        hasLineSpacing = lineSpacing != nil
        lineSpacingValue = lineSpacing ?? 0
        self.color = color
    }

    public var lineSpacing: CGFloat? {
        hasLineSpacing ? lineSpacingValue : nil
    }

    /// Effective line spacing: the explicit value, else the style's line height minus its size.
    var resolvedLineSpacing: CGFloat {
        lineSpacing ?? max(0, style.lineHeight - style.size)
    }
}
