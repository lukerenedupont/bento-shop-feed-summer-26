import SwiftUI

public enum ShopIconSize: CGFloat, CaseIterable, Sendable {
    case xSmall = 12
    case small = 16
    case medium = 20
    case large = 24
    case xLarge = 32

    public var points: CGFloat {
        rawValue
    }
}

public struct ShopIcon: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.shopToolbarIconStyleEnabled) private var usesToolbarIconStyle
    @Environment(\.shopToolbarForegroundColorScheme) private var toolbarColorScheme

    private let name: GravityIconName
    private let pointSize: CGFloat
    private let color: Color?
    private let renderingStyle: GravityIconRenderingStyle
    private let accessibilityLabel: String?

    public init(
        _ name: GravityIconName,
        size: ShopIconSize = .large,
        color: Color? = nil,
        renderingStyle: GravityIconRenderingStyle? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.init(
            name,
            pointSize: size.points,
            color: color,
            renderingStyle: renderingStyle,
            accessibilityLabel: accessibilityLabel
        )
    }

    public init(
        _ name: GravityIconName,
        pointSize: CGFloat,
        color: Color? = nil,
        renderingStyle: GravityIconRenderingStyle? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.name = name
        self.pointSize = pointSize
        self.color = color
        self.renderingStyle = renderingStyle ?? name.defaultRenderingStyle
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        applyAccessibility(to: renderedImage)
            .frame(width: pointSize, height: pointSize)
    }

    private var image: Image {
        Image(name.assetName, bundle: .gravityResources)
            .renderingMode(renderingStyle.templateRenderingMode)
    }

    @ViewBuilder
    private var renderedImage: some View {
        switch renderingStyle {
        case .template:
            image
                .resizable()
                .scaledToFit()
                .foregroundStyle(templateColor)
        case .original:
            image
                .resizable()
                .scaledToFit()
        }
    }

    private var templateColor: Color {
        if let color {
            return color
        }
        if usesToolbarIconStyle {
            return ShopToolbarForegroundColor.resolve(
                for: colorScheme,
                toolbarColorScheme: toolbarColorScheme
            )
        }
        return GravityColor.text
    }

    @ViewBuilder
    private func applyAccessibility<Content: View>(to content: Content) -> some View {
        if let accessibilityLabel {
            content.accessibilityLabel(SwiftUI.Text(accessibilityLabel))
        } else {
            content.accessibilityHidden(true)
        }
    }
}

#Preview("Sizes") {
    HStack(spacing: GravitySpacing.space16) {
        ShopIcon(.search, size: .xSmall)
        ShopIcon(.search, size: .small)
        ShopIcon(.search, size: .medium)
        ShopIcon(.search, size: .large)
        ShopIcon(.search, size: .xLarge)
    }
    .padding()
}
