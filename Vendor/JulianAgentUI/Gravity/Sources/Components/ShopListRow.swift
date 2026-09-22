import SwiftUI

public enum ShopListRowInsets {
    public static let none = EdgeInsets()
    public static let item = EdgeInsets(
        top: GravitySpacing.space8,
        leading: GravitySpacing.screenMargin,
        bottom: GravitySpacing.space8,
        trailing: GravitySpacing.screenMargin
    )
}

public struct ShopItemLockup<Leading: View>: View {
    private let title: String
    private let subtitle: String?
    private let subtitleAttributed: AttributedString?
    private let subtitleIcon: GravityIconName?
    private let subtitleIconColor: Color
    private let titleColor: Color
    private let subtitleColor: Color
    private let isDisabled: Bool
    private let leadingSpacing: CGFloat
    private let titleSubtitleSpacing: CGFloat
    private let titleLineLimit: Int?
    private let subtitleLineLimit: Int?
    private let leading: Leading

    public init(
        title: String,
        subtitle: String? = nil,
        subtitleAttributed: AttributedString? = nil,
        subtitleIcon: GravityIconName? = nil,
        subtitleIconColor: Color = GravityColor.textTertiary,
        titleColor: Color = GravityColor.text,
        subtitleColor: Color = GravityColor.textTertiary,
        isDisabled: Bool = false,
        leadingSpacing: CGFloat = GravitySpacing.space12,
        titleSubtitleSpacing: CGFloat = GravitySpacing.space2,
        titleLineLimit: Int? = nil,
        subtitleLineLimit: Int? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleAttributed = subtitleAttributed
        self.subtitleIcon = subtitleIcon
        self.subtitleIconColor = subtitleIconColor
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.isDisabled = isDisabled
        self.leadingSpacing = leadingSpacing
        self.titleSubtitleSpacing = titleSubtitleSpacing
        self.titleLineLimit = titleLineLimit
        self.subtitleLineLimit = subtitleLineLimit
        self.leading = leading()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: leadingSpacing) {
            leading

            VStack(alignment: .leading, spacing: titleSubtitleSpacing) {
                ShopText(title, style: .bodySmallBold, color: resolvedTitleColor)
                    .lineLimit(titleLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if subtitleAttributed != nil || subtitle != nil {
                    HStack(alignment: .center, spacing: GravitySpacing.space4) {
                        subtitleContent

                        if let subtitleIcon {
                            ShopIcon(subtitleIcon, size: .small, color: subtitleIconColor)
                                .padding(.top, GravitySpacing.space4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var resolvedTitleColor: Color {
        isDisabled ? GravityColor.textPlaceholder : titleColor
    }

    @ViewBuilder
    private var subtitleContent: some View {
        if let subtitleAttributed {
            SwiftUI.Text(subtitleAttributed)
                .gravityTextStyle(.caption, color: resolvedSubtitleColor)
                .lineLimit(subtitleLineLimit)
        } else if let subtitle {
            ShopText(subtitle, style: .caption, color: resolvedSubtitleColor)
                .lineLimit(subtitleLineLimit)
        }
    }

    private var resolvedSubtitleColor: Color {
        isDisabled ? GravityColor.textPlaceholder : subtitleColor
    }
}

public extension ShopItemLockup where Leading == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        titleColor: Color = GravityColor.text,
        subtitleColor: Color = GravityColor.textTertiary,
        isDisabled: Bool = false,
        titleSubtitleSpacing: CGFloat = GravitySpacing.space2,
        titleLineLimit: Int? = nil,
        subtitleLineLimit: Int? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            isDisabled: isDisabled,
            titleSubtitleSpacing: titleSubtitleSpacing,
            titleLineLimit: titleLineLimit,
            subtitleLineLimit: subtitleLineLimit
        ) {
            EmptyView()
        }
    }
}

public struct ShopListRow<Leading: View, Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let subtitleAttributed: AttributedString?
    private let subtitleIcon: GravityIconName?
    private let subtitleIconColor: Color
    private let titleColor: Color
    private let subtitleColor: Color
    private let isDisabled: Bool
    private let contentInsets: EdgeInsets
    private let leadingSpacing: CGFloat
    private let titleSubtitleSpacing: CGFloat
    private let trailingSpacing: CGFloat
    private let titleLineLimit: Int?
    private let subtitleLineLimit: Int?
    private let action: (() -> Void)?
    private let leading: Leading
    private let trailing: Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        subtitleAttributed: AttributedString? = nil,
        subtitleIcon: GravityIconName? = nil,
        subtitleIconColor: Color = GravityColor.textTertiary,
        titleColor: Color = GravityColor.text,
        subtitleColor: Color = GravityColor.textTertiary,
        isDisabled: Bool = false,
        contentInsets: EdgeInsets = ShopListRowInsets.none,
        leadingSpacing: CGFloat = GravitySpacing.space12,
        titleSubtitleSpacing: CGFloat = GravitySpacing.space2,
        trailingSpacing: CGFloat = GravitySpacing.space12,
        titleLineLimit: Int? = nil,
        subtitleLineLimit: Int? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleAttributed = subtitleAttributed
        self.subtitleIcon = subtitleIcon
        self.subtitleIconColor = subtitleIconColor
        self.titleColor = titleColor
        self.subtitleColor = subtitleColor
        self.isDisabled = isDisabled
        self.contentInsets = contentInsets
        self.leadingSpacing = leadingSpacing
        self.titleSubtitleSpacing = titleSubtitleSpacing
        self.trailingSpacing = trailingSpacing
        self.titleLineLimit = titleLineLimit
        self.subtitleLineLimit = subtitleLineLimit
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        Group {
            if let action {
                SwiftUI.Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: trailingSpacing) {
            ShopItemLockup(
                title: title,
                subtitle: subtitle,
                subtitleAttributed: subtitleAttributed,
                subtitleIcon: subtitleIcon,
                subtitleIconColor: subtitleIconColor,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                isDisabled: isDisabled,
                leadingSpacing: leadingSpacing,
                titleSubtitleSpacing: titleSubtitleSpacing,
                titleLineLimit: titleLineLimit,
                subtitleLineLimit: subtitleLineLimit
            ) {
                leading
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(contentInsets)
        .contentShape(Rectangle())
    }
}

public extension ShopListRow where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        subtitleAttributed: AttributedString? = nil,
        titleColor: Color = GravityColor.text,
        subtitleColor: Color = GravityColor.textTertiary,
        isDisabled: Bool = false,
        contentInsets: EdgeInsets = ShopListRowInsets.none,
        leadingSpacing: CGFloat = GravitySpacing.space12,
        titleSubtitleSpacing: CGFloat = GravitySpacing.space2,
        titleLineLimit: Int? = nil,
        subtitleLineLimit: Int? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            subtitleAttributed: subtitleAttributed,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            isDisabled: isDisabled,
            contentInsets: contentInsets,
            leadingSpacing: leadingSpacing,
            titleSubtitleSpacing: titleSubtitleSpacing,
            titleLineLimit: titleLineLimit,
            subtitleLineLimit: subtitleLineLimit,
            action: action,
            leading: leading
        ) {
            EmptyView()
        }
    }
}

public extension ShopListRow where Leading == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        titleColor: Color = GravityColor.text,
        subtitleColor: Color = GravityColor.textTertiary,
        isDisabled: Bool = false,
        contentInsets: EdgeInsets = ShopListRowInsets.none,
        titleSubtitleSpacing: CGFloat = GravitySpacing.space2,
        trailingSpacing: CGFloat = GravitySpacing.space12,
        titleLineLimit: Int? = nil,
        subtitleLineLimit: Int? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            isDisabled: isDisabled,
            contentInsets: contentInsets,
            titleSubtitleSpacing: titleSubtitleSpacing,
            trailingSpacing: trailingSpacing,
            titleLineLimit: titleLineLimit,
            subtitleLineLimit: subtitleLineLimit,
            action: action
        ) {
            EmptyView()
        } trailing: {
            trailing()
        }
    }
}

public extension ShopListRow where Leading == EmptyView, Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        titleColor: Color = GravityColor.text,
        subtitleColor: Color = GravityColor.textTertiary,
        isDisabled: Bool = false,
        contentInsets: EdgeInsets = ShopListRowInsets.none,
        titleSubtitleSpacing: CGFloat = GravitySpacing.space2,
        titleLineLimit: Int? = nil,
        subtitleLineLimit: Int? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            isDisabled: isDisabled,
            contentInsets: contentInsets,
            titleSubtitleSpacing: titleSubtitleSpacing,
            titleLineLimit: titleLineLimit,
            subtitleLineLimit: subtitleLineLimit,
            action: action
        ) {
            EmptyView()
        } trailing: {
            EmptyView()
        }
    }
}

public extension ShopListRow where Leading == AnyView, Trailing == AnyView {
    @available(*, deprecated, message: "Use init(title:subtitle:contentInsets:action:leading:trailing:) with ShopItemLockup-style slots.")
    init(
        _ title: String,
        subtitle: String? = nil,
        icon: GravityIconName? = nil,
        showsChevron: Bool = false,
        titleColor: Color = GravityColor.text,
        subtitleColor: Color = GravityColor.textTertiary,
        iconColor: Color = GravityColor.text,
        action: (() -> Void)? = nil
    ) {
        let leadingView: AnyView = if let icon {
            AnyView(
                ShopIcon(icon, size: .large, color: iconColor)
                    .frame(width: GravitySpacing.space24, height: GravitySpacing.space24)
            )
        } else {
            AnyView(EmptyView())
        }

        let trailingView: AnyView = showsChevron
            ? AnyView(ShopListRowDisclosureIndicator())
            : AnyView(EmptyView())

        self.init(
            title: title,
            subtitle: subtitle,
            titleColor: titleColor,
            subtitleColor: subtitleColor,
            contentInsets: EdgeInsets(top: GravitySpacing.space8, leading: 0, bottom: GravitySpacing.space8, trailing: 0),
            leadingSpacing: icon == nil ? 0 : GravitySpacing.space12,
            trailingSpacing: showsChevron ? GravitySpacing.space12 : 0,
            action: action
        ) {
            leadingView
        } trailing: {
            trailingView
        }
    }
}

public struct ShopListRowDisclosureIndicator: View {
    public init() {}

    public var body: some View {
        ShopIcon(.rightChevron, size: .small, color: GravityColor.textSecondary)
    }
}

#Preview("List Rows") {
    VStack(spacing: GravitySpacing.space16) {
        VStack(spacing: 0) {
            ShopListRow(
                title: "Notifications",
                subtitle: "Manage your alerts",
                contentInsets: ShopListRowInsets.item
            ) {
                ShopIcon(.bellFilled, size: .large, color: GravityColor.text)
                    .frame(width: GravitySpacing.space24, height: GravitySpacing.space24)
            } trailing: {
                ShopListRowDisclosureIndicator()
            }

            ShopDivider()

            ShopListRow(
                title: "Snow Peak",
                subtitle: "New arrivals",
                contentInsets: ShopListRowInsets.item
            ) {
                ShopAvatar(name: "Snow Peak", size: .m)
            } trailing: {
                ShopBadge("New")
            }

            ShopDivider()

            ShopListRow(
                title: "Settings",
                contentInsets: ShopListRowInsets.item,
                trailing: {
                    ShopListRowDisclosureIndicator()
                }
            )
        }

        ShopCard {
            VStack(spacing: GravitySpacing.space16) {
                ShopListRow(title: "Product thumbnail", subtitle: "44px fixed-size leading content", leading: {
                    ShopProductImageTile(displayWidth: 44, cornerRadius: GravityRadius.radius12) {
                        GravityColor.bgFillBrandSecondary
                    }
                    .frame(width: 44, height: 44)
                })

                ShopListRow(title: "Product thumbnail", subtitle: "44px fixed-size leading content", leading: {
                    ShopProductImageTile(displayWidth: 44, cornerRadius: GravityRadius.radius12) {
                        GravityColor.bgFillBrandSecondary
                    }
                    .frame(width: 44, height: 44)
                })

                ShopListRow(title: "Product thumbnail", subtitle: "44px fixed-size leading content", isDisabled: true, leading: {
                    ShopProductImageTile(displayWidth: 44, cornerRadius: GravityRadius.radius12) {
                        GravityColor.bgFillBrandSecondary
                    }
                    .frame(width: 44, height: 44)
                })
            }
        }

        SwiftUI.Button {} label: {
            ShopItemLockup(title: "Reusable item lockup", subtitle: "Used without the full row", leading: {
                ShopAvatar(name: "Shop", size: .m)
            })
        }
        .buttonStyle(.plain)
    }
    .background(GravityColor.bg)
}
