import SwiftUI

public enum ShopProductImageOverlayPosition: String, Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case cornerRight

    public var alignment: Alignment {
        switch self {
        case .topLeading:
            .topLeading
        case .topTrailing:
            .topTrailing
        case .bottomLeading:
            .bottomLeading
        case .bottomTrailing:
            .bottomTrailing
        case .cornerRight:
            .topTrailing
        }
    }

    public func edgeInsets(padding: CGFloat) -> EdgeInsets {
        switch self {
        case .topLeading:
            EdgeInsets(top: padding, leading: padding, bottom: 0, trailing: 0)
        case .topTrailing:
            EdgeInsets(top: padding, leading: 0, bottom: 0, trailing: padding)
        case .bottomLeading:
            EdgeInsets(top: 0, leading: padding, bottom: padding, trailing: 0)
        case .bottomTrailing:
            EdgeInsets(top: 0, leading: 0, bottom: padding, trailing: padding)
        case .cornerRight:
            EdgeInsets(
                top: GravitySpacing.space16,
                leading: 0,
                bottom: 0,
                trailing: -GravitySpacing.space20
            )
        }
    }

    var rotationDegrees: Double {
        switch self {
        case .topLeading, .topTrailing, .bottomLeading, .bottomTrailing:
            0
        case .cornerRight:
            45
        }
    }
}

public struct ShopProductImageOverlayItem {
    let position: ShopProductImageOverlayPosition
    let allowsHitTesting: Bool
    let content: AnyView

    public init<Content: View>(
        _ position: ShopProductImageOverlayPosition,
        allowsHitTesting: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.position = position
        self.allowsHitTesting = allowsHitTesting
        self.content = AnyView(content())
    }
}

private struct ShopProductImageOverlaySlot {
    let content: AnyView
    let allowsHitTesting: Bool
}

/// Positions product-image overlays consistently across product cards.
///
/// Owns placement only. Overlay meaning and actions stay with feature code.
public struct ShopProductImageOverlayLayout: View {
    public static let defaultPadding: CGFloat = GravitySpacing.space12

    private let items: [ShopProductImageOverlayItem]
    private let padding: CGFloat

    public init(
        items: [ShopProductImageOverlayItem],
        padding: CGFloat = ShopProductImageOverlayLayout.defaultPadding
    ) {
        self.items = items
        self.padding = padding
    }

    public var body: some View {
        let slots = ProductImageOverlaySlots(items: items)

        ZStack {
            overlay(slots.topLeading, position: .topLeading)
            overlay(slots.topTrailing, position: .topTrailing)
            overlay(slots.bottomLeading, position: .bottomLeading)
            overlay(slots.bottomTrailing, position: .bottomTrailing)
            overlay(slots.cornerRight, position: .cornerRight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func overlay(_ slot: ShopProductImageOverlaySlot?, position: ShopProductImageOverlayPosition) -> some View {
        if let slot {
            slot.content
                .allowsHitTesting(slot.allowsHitTesting)
                .shopProductImageOverlayItem(at: position, padding: padding)
        }
    }
}

private struct ProductImageOverlaySlots {
    var topLeading: ShopProductImageOverlaySlot?
    var topTrailing: ShopProductImageOverlaySlot?
    var bottomLeading: ShopProductImageOverlaySlot?
    var bottomTrailing: ShopProductImageOverlaySlot?
    var cornerRight: ShopProductImageOverlaySlot?

    init(items: [ShopProductImageOverlayItem]) {
        for item in items {
            assign(item)
        }
    }

    private mutating func assign(_ item: ShopProductImageOverlayItem) {
        switch item.position {
        case .topLeading:
            Self.set(&topLeading, item)
        case .topTrailing:
            Self.set(&topTrailing, item)
        case .bottomLeading:
            Self.set(&bottomLeading, item)
        case .bottomTrailing:
            Self.set(&bottomTrailing, item)
        case .cornerRight:
            Self.set(&cornerRight, item)
        }
    }

    private static func set(_ slot: inout ShopProductImageOverlaySlot?, _ item: ShopProductImageOverlayItem) {
        guard slot == nil else {
            assertionFailure("ShopProductImageOverlayLayout supports one overlay item per position. Duplicate item for \(item.position.rawValue) was ignored.")
            return
        }

        slot = ShopProductImageOverlaySlot(
            content: item.content,
            allowsHitTesting: item.allowsHitTesting
        )
    }
}

public extension ShopProductImageOverlayLayout {
    init(@ShopProductImageOverlayItemsBuilder items: () -> [ShopProductImageOverlayItem]) {
        self.init(items: items())
    }
}

@resultBuilder
public enum ShopProductImageOverlayItemsBuilder {
    public static func buildExpression(_ expression: ShopProductImageOverlayItem) -> [ShopProductImageOverlayItem] {
        [expression]
    }

    public static func buildBlock(_ components: [ShopProductImageOverlayItem]...) -> [ShopProductImageOverlayItem] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [ShopProductImageOverlayItem]?) -> [ShopProductImageOverlayItem] {
        component ?? []
    }

    public static func buildEither(first component: [ShopProductImageOverlayItem]) -> [ShopProductImageOverlayItem] {
        component
    }

    public static func buildEither(second component: [ShopProductImageOverlayItem]) -> [ShopProductImageOverlayItem] {
        component
    }

    public static func buildArray(_ components: [[ShopProductImageOverlayItem]]) -> [ShopProductImageOverlayItem] {
        components.flatMap { $0 }
    }
}

public extension View {
    /// Aligns overlay content to a product-image corner with a shared inset.
    func shopProductImageOverlayItem(
        at position: ShopProductImageOverlayPosition,
        padding: CGFloat = ShopProductImageOverlayLayout.defaultPadding
    ) -> some View {
        self
            .rotationEffect(.degrees(position.rotationDegrees))
            .padding(position.edgeInsets(padding: padding))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    }
}

#Preview("Product image overlays") {
    ZStack {
        RoundedRectangle(cornerRadius: ShopRadius.r20, style: .continuous)
            .fill(GravityColor.fillFixedDark.opacity(0.12))

        ShopProductImageOverlayLayout {
            ShopProductImageOverlayItem(.topLeading) {
                ShopBadge("Sale", variant: .critical)
            }

            ShopProductImageOverlayItem(.bottomTrailing, allowsHitTesting: true) {
                ShopFavoriteButton(isFavorite: true)
            }
        }
    }
    .frame(width: 160, height: 160)
    .padding()
}

#if DEBUG
#Preview("Direct image overlay host") {
    ShopProductImageTile(displayWidth: 220) {
        LinearGradient(
            colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    .overlay {
        ShopFavoriteButton(isFavorite: true) {}
            .shopProductImageOverlayItem(at: .bottomTrailing)
    }
    .padding()
}
#endif
