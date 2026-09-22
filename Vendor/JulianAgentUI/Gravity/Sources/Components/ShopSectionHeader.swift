import SwiftUI

public struct ShopSectionHeaderAction {
    fileprivate let perform: () -> Void
    fileprivate let accessibilityHint: String?

    public init(
        onPress: @escaping () -> Void,
        accessibilityHint: String? = nil
    ) {
        self.perform = onPress
        self.accessibilityHint = accessibilityHint
    }
}

public struct ShopSectionHeader<Leading: View, Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let titleStyle: GravityTextStyle
    private let subtitleStyle: GravityTextStyle
    private let textSpacing: CGFloat
    private let action: ShopSectionHeaderAction?
    private let leading: Leading
    private let trailing: Trailing
    private let hasLeading: Bool
    private let hasTrailing: Bool

    private static var hasLeadingContent: Bool { Leading.self != EmptyView.self }
    private static var hasTrailingContent: Bool { Trailing.self != EmptyView.self }

    public init(
        _ title: String,
        subtitle: String? = nil,
        titleStyle: GravityTextStyle = .sectionTitle,
        subtitleStyle: GravityTextStyle = .bodySmall,
        textSpacing: CGFloat = GravitySpacing.space2,
        action: ShopSectionHeaderAction? = nil
    ) where Leading == EmptyView, Trailing == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.titleStyle = titleStyle
        self.subtitleStyle = subtitleStyle
        self.textSpacing = textSpacing
        self.action = action
        self.leading = EmptyView()
        self.trailing = EmptyView()
        self.hasLeading = false
        self.hasTrailing = false
    }

    public init(
        _ title: String,
        subtitle: String? = nil,
        titleStyle: GravityTextStyle = .sectionTitle,
        subtitleStyle: GravityTextStyle = .bodySmall,
        textSpacing: CGFloat = GravitySpacing.space2,
        action: ShopSectionHeaderAction? = nil,
        @ViewBuilder leading: () -> Leading
    ) where Trailing == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.titleStyle = titleStyle
        self.subtitleStyle = subtitleStyle
        self.textSpacing = textSpacing
        self.action = action
        self.leading = leading()
        self.trailing = EmptyView()
        self.hasLeading = Self.hasLeadingContent
        self.hasTrailing = false
    }

    public init(
        _ title: String,
        subtitle: String? = nil,
        titleStyle: GravityTextStyle = .sectionTitle,
        subtitleStyle: GravityTextStyle = .bodySmall,
        textSpacing: CGFloat = GravitySpacing.space2,
        @ViewBuilder trailing: () -> Trailing
    ) where Leading == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.titleStyle = titleStyle
        self.subtitleStyle = subtitleStyle
        self.textSpacing = textSpacing
        self.action = nil
        self.leading = EmptyView()
        self.trailing = trailing()
        self.hasLeading = false
        self.hasTrailing = Self.hasTrailingContent
    }

    public init(
        _ title: String,
        subtitle: String? = nil,
        titleStyle: GravityTextStyle = .sectionTitle,
        subtitleStyle: GravityTextStyle = .bodySmall,
        textSpacing: CGFloat = GravitySpacing.space2,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleStyle = titleStyle
        self.subtitleStyle = subtitleStyle
        self.textSpacing = textSpacing
        self.action = nil
        self.leading = leading()
        self.trailing = trailing()
        self.hasLeading = Self.hasLeadingContent
        self.hasTrailing = Self.hasTrailingContent
    }

    private var showsChevron: Bool {
        action != nil && !hasLeading && !hasTrailing
    }

    public var body: some View {
        if let action {
            SwiftUI.Button(action: action.perform) {
                row
            }
            .buttonStyle(SectionHeaderPressOpacityButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .optionalAccessibilityHint(action.accessibilityHint)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space0) {
            if hasLeading {
                leading
            }

            textColumn
                .padding(.leading, hasLeading ? GravitySpacing.space8 : GravitySpacing.space0)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hasTrailing {
                trailing
            }
        }
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: textSpacing) {
            titleRow
            if let subtitle {
                SwiftUI.Text(subtitle)
                    .gravityTextStyle(subtitleStyle, color: GravityColor.textTertiary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: GravitySpacing.space8) {
            SwiftUI.Text(title)
                .gravityTextStyle(titleStyle)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityAddTraits(.isHeader)

            if showsChevron {
                chevronPill
            }
        }
    }

    private var chevronPill: some View {
        ShopIcon(.boldRightChevron, size: .small, color: GravityColor.text)
            .padding(GravitySpacing.space2)
            .background(Circle().fill(GravityColor.bgFillSecondary))
            .offset(y: SectionHeaderMetrics.chevronOpticalOffsetY)
            .accessibilityHidden(true)
    }
}

private enum SectionHeaderMetrics {
    static let chevronOpticalOffsetY = GravitySpacing.space2 / 2
    static let pressedOpacity: Double = 0.2
    static let pressReleaseDuration: TimeInterval = 0.25
}

private struct SectionHeaderPressOpacityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? SectionHeaderMetrics.pressedOpacity : 1)
            .animation(
                .linear(duration: configuration.isPressed ? 0 : SectionHeaderMetrics.pressReleaseDuration),
                value: configuration.isPressed
            )
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityHint(_ hint: String?) -> some View {
        if let hint {
            accessibilityHint(SwiftUI.Text(hint))
        } else {
            self
        }
    }
}

#Preview("ShopSectionHeader") {
    VStack(alignment: .leading, spacing: GravitySpacing.space32) {
        ShopSectionHeader("Featured brands")

        ShopSectionHeader(
            "Recent orders",
            action: ShopSectionHeaderAction(onPress: {}, accessibilityHint: "View all orders")
        )

        ShopSectionHeader(
            "Recent orders",
            subtitle: "Last 30 days",
            action: ShopSectionHeaderAction(onPress: {})
        )

        ShopSectionHeader(
            "Acme Goods",
            subtitle: "shop.acme.com",
            action: ShopSectionHeaderAction(onPress: {}),
            leading: {
                ShopAvatar(size: .m)
            }
        )

        ShopSectionHeader(
            "Payment methods",
            trailing: {
                ShopButton("Add card", variant: .secondary, isFullWidth: false) {}
            }
        )
    }
    .padding(GravitySpacing.space16)
}
