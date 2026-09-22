import SwiftUI

/// A single action rendered by `ShopStateCard` (for example "Try again" or "Connect account").
public struct ShopStateCardAction {
    let title: String
    let variant: GravityButtonVariant
    let size: ShopButtonSize
    let wrapsTitleAtAccessibilitySizes: Bool
    let action: () -> Void

    public init(
        title: String,
        variant: GravityButtonVariant = .primary,
        size: ShopButtonSize = .large,
        wrapsTitleAtAccessibilitySizes: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.wrapsTitleAtAccessibilitySizes = wrapsTitleAtAccessibilitySizes
        self.action = action
    }
}

/// A reusable empty / error state card: a leading icon, a title, an optional message, and
/// optional actions, wrapped in a `ShopCard`.
///
/// Business-agnostic on purpose — callers supply the icon, copy, and actions. It is the shared
/// content for `ShopCollectionList` empty/error slots (Orders root + filtered Past/Archived
/// lists) and is suitable for other list/detail surfaces that need a centered message card.
/// Callers own outer placement (insets, background) so the card stays layout-agnostic.
public struct ShopStateCard: View {
    private let icon: GravityIconName
    private let iconColor: Color
    private let iconSize: ShopIconSize
    private let title: String
    private let message: String?
    private let messageStyle: GravityTextStyle
    private let messageLineLimit: Int?
    private let contentSpacing: CGFloat
    private let actions: [ShopStateCardAction]

    public init(
        icon: GravityIconName,
        iconColor: Color = GravityColor.textTertiary,
        iconSize: ShopIconSize = .xLarge,
        title: String,
        message: String? = nil,
        messageStyle: GravityTextStyle = .bodyLarge,
        messageLineLimit: Int? = nil,
        contentSpacing: CGFloat = GravitySpacing.space12,
        actions: [ShopStateCardAction] = []
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.title = title
        self.message = message
        self.messageStyle = messageStyle
        self.messageLineLimit = messageLineLimit
        self.contentSpacing = contentSpacing
        self.actions = actions
    }

    public var body: some View {
        ShopCard {
            VStack(alignment: .leading, spacing: contentSpacing) {
                ShopIcon(icon, size: iconSize, color: iconColor)
                ShopText(title, style: .sectionTitle)
                if let message {
                    ShopText(message, style: messageStyle, color: GravityColor.textSecondary)
                        .lineLimit(messageLineLimit)
                }
                if actions.isEmpty == false {
                    VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                            ShopButton(
                                action.title,
                                variant: action.variant,
                                size: action.size,
                                wrapsTitleAtAccessibilitySizes: action.wrapsTitleAtAccessibilitySizes,
                                action: action.action
                            )
                        }
                    }
                    .padding(.top, GravitySpacing.space4)
                }
            }
        }
    }
}

#Preview("Empty + actions") {
    ShopStateCard(
        icon: .order,
        title: "Track all your orders here",
        message: "Connect your account, and Shop will automatically track your orders.",
        contentSpacing: GravitySpacing.space16,
        actions: [
            ShopStateCardAction(title: "Connect account", variant: .primary, size: .large, action: {}),
            ShopStateCardAction(title: "Add a package manually", variant: .tertiary, size: .large, action: {}),
        ]
    )
    .padding(GravitySpacing.screenMargin)
}

#Preview("Error + retry") {
    ShopStateCard(
        icon: .alertTriangleFilled,
        iconColor: GravityColor.textCritical,
        iconSize: .large,
        title: "Your orders couldn't load",
        message: "Couldn't load orders. Please try again.",
        messageStyle: .bodySmall,
        messageLineLimit: 4,
        actions: [
            ShopStateCardAction(title: "Try again", variant: .secondary, size: .medium, action: {}),
        ]
    )
    .padding(GravitySpacing.screenMargin)
}
