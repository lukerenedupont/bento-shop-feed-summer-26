import SwiftUI
import UIKit

public enum ShopAvatarSize: CGFloat, CaseIterable, Sendable {
    case xs = 24
    case s = 32
    case m = 44
    case l = 56
    case xl = 72
    case xxl = 96

    public var points: CGFloat {
        rawValue
    }

    static func nearest(to pointSize: CGFloat) -> ShopAvatarSize {
        allCases.min { lhs, rhs in
            abs(lhs.points - pointSize) < abs(rhs.points - pointSize)
        } ?? .m
    }
}

public enum ShopAvatarFallbackStyle: Sendable {
    case buyer
    case merchant
}

public func shopAvatarShowsInitials(dynamicTypeSize: DynamicTypeSize) -> Bool {
    !dynamicTypeSize.isAccessibilitySize
}

func shopAvatarDerivedInitials(name: String?) -> String? {
    guard let name else {
        return nil
    }

    let value = name
        .split(separator: " ")
        .prefix(2)
        .compactMap(\.first)
        .map { String($0).uppercased() }
        .joined()

    return value.isEmpty ? nil : value
}

func shopAvatarResolvedInitials(
    initialsOverride: String?,
    name: String?,
    showsInitials: Bool
) -> String? {
    guard showsInitials else {
        return nil
    }
    if let initialsOverride {
        return initialsOverride.isEmpty ? nil : initialsOverride
    }
    return shopAvatarDerivedInitials(name: name)
}

public struct ShopAvatar<ImageContent: View>: View {
    private let name: String?
    private let size: ShopAvatarSize
    private let pointSize: CGFloat
    private let showsTint: Bool
    private let fallbackBackgroundColor: Color
    private let showsFallbackTint: Bool
    private let placeholderIcon: ShopIconName
    private let initialsOverride: String?
    private let fallbackStyle: ShopAvatarFallbackStyle?
    private let imageContent: (() -> ImageContent)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        name: String? = nil,
        size: ShopAvatarSize = .xs,
        showsTint: Bool = true,
        fallbackBackgroundColor: Color = GravityColor.bgFillFixedDusk,
        showsFallbackTint: Bool = false,
        placeholderIcon: ShopIconName = .shopFilled,
        initials: String? = nil,
        fallbackStyle: ShopAvatarFallbackStyle? = nil,
        @ViewBuilder image: @escaping () -> ImageContent
    ) {
        self.name = name
        self.size = size
        self.pointSize = size.points
        self.showsTint = showsTint
        self.fallbackBackgroundColor = fallbackBackgroundColor
        self.showsFallbackTint = showsFallbackTint
        self.placeholderIcon = placeholderIcon
        self.initialsOverride = initials
        self.fallbackStyle = fallbackStyle
        self.imageContent = image
    }

    public init(
        name: String? = nil,
        pointSize: CGFloat,
        showsTint: Bool = true,
        fallbackBackgroundColor: Color = GravityColor.bgFillFixedDusk,
        showsFallbackTint: Bool = false,
        placeholderIcon: ShopIconName = .shopFilled,
        initials: String? = nil,
        fallbackStyle: ShopAvatarFallbackStyle? = nil,
        @ViewBuilder image: @escaping () -> ImageContent
    ) {
        self.name = name
        self.size = ShopAvatarSize.nearest(to: pointSize)
        self.pointSize = pointSize
        self.showsTint = showsTint
        self.fallbackBackgroundColor = fallbackBackgroundColor
        self.showsFallbackTint = showsFallbackTint
        self.placeholderIcon = placeholderIcon
        self.initialsOverride = initials
        self.fallbackStyle = fallbackStyle
        self.imageContent = image
    }

    public var body: some View {
        let fallbackConfig = resolvedFallbackConfig
        let visualStyle = ShopAvatarVisualStyle.resolve(
            hasImage: imageContent != nil,
            showsTint: showsTint,
            fallbackBackgroundColor: fallbackConfig?.baseColor ?? fallbackBackgroundColor,
            showsFallbackTint: showsFallbackTint
        )

        ZStack {
            Circle()
                .fill(visualStyle.backgroundColor)

            if let fallbackConfig {
                Circle()
                    .fill(fallbackConfig.overlayColor.opacity(fallbackConfig.overlayOpacity))

                ShopAvatarFallbackGlow(
                    color: fallbackConfig.glowColor,
                    opacity: fallbackConfig.glowOpacity,
                    pointSize: pointSize
                )
            }

            if let imageContent {
                imageContent()
                    .frame(width: pointSize, height: pointSize)
                    .clipShape(Circle())
            } else if let initials = resolvedInitials {
                initialsText(initials, fallbackConfig: fallbackConfig)
            } else if let fallbackConfig {
                if case .merchant = fallbackStyle {
                    ShopIcon(
                        placeholderIcon,
                        pointSize: pointSize / 2,
                        color: fallbackConfig.foregroundColor
                    )
                } else {
                    ShopAvatarFallbackSilhouette()
                        .fill(fallbackConfig.foregroundColor)
                        .frame(width: pointSize, height: pointSize)
                }
            } else {
                ShopIcon(
                    placeholderIcon,
                    pointSize: pointSize / 2,
                    color: ShopColor.textFixedLight
                )
            }

            if visualStyle.showsTint {
                Circle()
                    .fill(GravityColor.bgOverlayInverse04)
            }
        }
        .frame(width: pointSize, height: pointSize)
        .clipShape(Circle())
        .overlay {
            ShopImageBorderOverlay(cornerRadius: GravityRadius.radiusMax)
        }
        .compositingGroup()
        .accessibilityLabel(SwiftUI.Text(name ?? ""))
        .accessibilityHidden(name?.isEmpty ?? true)
    }

    private var resolvedFallbackConfig: ShopAvatarFallbackConfig? {
        guard imageContent == nil else { return nil }
        return fallbackStyle?.config
    }

    private var resolvedInitials: String? {
        shopAvatarResolvedInitials(
            initialsOverride: initialsOverride,
            name: name,
            showsInitials: shopAvatarShowsInitials(dynamicTypeSize: dynamicTypeSize)
        )
    }

    @ViewBuilder
    private func initialsText(
        _ initials: String,
        fallbackConfig: ShopAvatarFallbackConfig?
    ) -> some View {
        let color = fallbackConfig?.foregroundColor ?? ShopColor.textFixedLight

        if fallbackConfig != nil {
            ShopAvatarInitialsText(initials: initials, pointSize: pointSize, color: color)
        } else if size == .xs {
            ShopText(initials, style: .captionBold, color: color, alignment: .center)
                .frame(width: pointSize, height: pointSize)
        } else {
            let typography = standardInitialsTypography

            SwiftUI.Text(initials)
                .font(
                    GravityFonts.font(
                        name: GravityFonts.bold,
                        size: typography.fontSize,
                        relativeTo: typography.relativeTextStyle
                    )
                )
                .kerning(-0.5)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: pointSize, height: typography.lineHeight, alignment: .center)
        }
    }

    private var standardInitialsTypography: ShopAvatarStandardInitialsTypography {
        switch size {
        case .xs:
            ShopAvatarStandardInitialsTypography(fontSize: 10, lineHeight: 16, relativeTextStyle: .caption2)
        case .s:
            ShopAvatarStandardInitialsTypography(fontSize: 12, lineHeight: 20, relativeTextStyle: .caption)
        case .m:
            ShopAvatarStandardInitialsTypography(fontSize: 16, lineHeight: 30, relativeTextStyle: .body)
        case .l:
            ShopAvatarStandardInitialsTypography(fontSize: 20, lineHeight: 38, relativeTextStyle: .title3)
        case .xl, .xxl:
            ShopAvatarStandardInitialsTypography(fontSize: 32, lineHeight: 54, relativeTextStyle: .title)
        }
    }
}

struct ShopAvatarVisualStyle: Equatable, Sendable {
    let backgroundColor: Color
    let showsTint: Bool

    static func resolve(
        hasImage: Bool,
        showsTint: Bool,
        fallbackBackgroundColor: Color,
        showsFallbackTint: Bool
    ) -> Self {
        ShopAvatarVisualStyle(
            backgroundColor: hasImage ? GravityColor.bgFillFixedLight : fallbackBackgroundColor,
            showsTint: showsTint && (hasImage || showsFallbackTint)
        )
    }
}

private struct ShopAvatarStandardInitialsTypography {
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let relativeTextStyle: Font.TextStyle
}

struct ShopAvatarInitialsText: View {
    let initials: String
    let pointSize: CGFloat
    let color: Color

    var body: some View {
        let typography = ShopAvatarInitialsTypography(pointSize: pointSize)

        SwiftUI.Text(initials)
            .font(typography.font)
            .kerning(typography.textStyle.kerning)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: pointSize, height: typography.lineHeight, alignment: .center)
    }
}

struct ShopAvatarInitialsTypography {
    let textStyle: GravityTextStyle
    let lineHeight: CGFloat
    private let overridesFontWithSemibold: Bool

    init(pointSize: CGFloat) {
        switch pointSize {
        case 120...:
            textStyle = .posterSmall
            overridesFontWithSemibold = true
        case 96...:
            textStyle = .heroNormal
            overridesFontWithSemibold = false
        case 72...:
            textStyle = .header
            overridesFontWithSemibold = true
        case 56...:
            textStyle = .headerBold
            overridesFontWithSemibold = false
        case 44...:
            textStyle = .subtitle
            overridesFontWithSemibold = false
        case 32...:
            textStyle = .bodyTitleLarge
            overridesFontWithSemibold = false
        default:
            textStyle = .badgeBold
            overridesFontWithSemibold = false
        }
        lineHeight = pointSize < ShopAvatarSize.xs.points ? 7 : textStyle.lineHeight
    }

    var font: Font {
        guard overridesFontWithSemibold else { return textStyle.font }
        return GravityFonts.font(
            name: GravityFonts.semibold,
            size: textStyle.size,
            relativeTo: textStyle.relativeTextStyle
        )
    }
}

private struct ShopAvatarFallbackConfig {
    let baseColor: Color
    let overlayColor: Color
    let overlayOpacity: Double
    let glowColor: Color
    let glowOpacity: Double
    let foregroundColor: Color
}

extension ShopAvatarFallbackStyle {
    private static let buyerConfig = ShopAvatarFallbackConfig(
        baseColor: ShopColor.fillFixedLight,
        overlayColor: Color(UIColor(red: 0.6118, green: 0.5137, blue: 0.9725, alpha: 1)),
        overlayOpacity: 0.8,
        glowColor: Color(UIColor(red: 0.9686, green: 0.9608, blue: 1, alpha: 1)),
        glowOpacity: 0.38,
        foregroundColor: ShopColor.textFixedLight
    )

    private static let merchantConfig = ShopAvatarFallbackConfig(
        baseColor: .clear,
        overlayColor: Color(UIColor(red: 0.6510, green: 0.6588, blue: 0.6627, alpha: 1)),
        overlayOpacity: 1,
        glowColor: Color(UIColor(red: 0.9490, green: 0.9569, blue: 0.9608, alpha: 1)),
        glowOpacity: 0.38,
        foregroundColor: ShopColor.textFixedLight
    )

    fileprivate var config: ShopAvatarFallbackConfig {
        switch self {
        case .buyer:
            Self.buyerConfig
        case .merchant:
            Self.merchantConfig
        }
    }
}

struct ShopAvatarFallbackGlow: View {
    private static let profile: [(offset: Double, opacityFactor: Double)] = [
        (0, 0.966),
        (0.125, 0.89),
        (0.25, 0.735),
        (0.375, 0.512),
        (0.5, 0.285),
        (0.625, 0.121),
        (0.75, 0.039),
        (0.875, 0.009),
        (1, 0.002),
    ]

    private let stops: [Gradient.Stop]
    private let pointSize: CGFloat

    init(color: Color, opacity: Double, pointSize: CGFloat) {
        self.pointSize = pointSize
        self.stops = Self.profile.map { stop in
            Gradient.Stop(
                color: color.opacity(stop.opacityFactor * opacity),
                location: stop.offset
            )
        }
    }

    var body: some View {
        RadialGradient(
            stops: stops,
            center: UnitPoint(x: 0.239, y: 0.188),
            startRadius: 0,
            endRadius: pointSize * 0.8
        )
        .allowsHitTesting(false)
    }
}

private struct ShopAvatarFallbackSilhouette: Shape {
    /// Design space for the Figma person silhouette path.
    private static let designSize: CGFloat = 32

    private static let basePath: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 16.1426, y: 20.7998))
        path.addCurve(
            to: CGPoint(x: 25.2852, y: 24.959),
            control1: CGPoint(x: 19.9751, y: 20.7998),
            control2: CGPoint(x: 23.1544, y: 22.4085)
        )
        path.addCurve(
            to: CGPoint(x: 16.1426, y: 28.7998),
            control1: CGPoint(x: 22.962, y: 27.3294),
            control2: CGPoint(x: 19.7238, y: 28.7998)
        )
        path.addCurve(
            to: CGPoint(x: 7, y: 24.959),
            control1: CGPoint(x: 12.5613, y: 28.7997),
            control2: CGPoint(x: 9.32313, y: 27.3295)
        )
        path.addCurve(
            to: CGPoint(x: 16.1426, y: 20.7998),
            control1: CGPoint(x: 9.13071, y: 22.4085),
            control2: CGPoint(x: 12.3102, y: 20.7999)
        )
        path.closeSubpath()

        path.move(to: CGPoint(x: 16.1426, y: 8))
        path.addCurve(
            to: CGPoint(x: 20.9424, y: 12.7998),
            control1: CGPoint(x: 18.7935, y: 8),
            control2: CGPoint(x: 20.9423, y: 10.1489)
        )
        path.addCurve(
            to: CGPoint(x: 16.1426, y: 17.5996),
            control1: CGPoint(x: 20.9424, y: 15.4508),
            control2: CGPoint(x: 18.7935, y: 17.5996)
        )
        path.addCurve(
            to: CGPoint(x: 11.3428, y: 12.7998),
            control1: CGPoint(x: 13.4916, y: 17.5996),
            control2: CGPoint(x: 11.3428, y: 15.4508)
        )
        path.addCurve(
            to: CGPoint(x: 16.1426, y: 8),
            control1: CGPoint(x: 11.3429, y: 10.1489),
            control2: CGPoint(x: 13.4917, y: 8)
        )
        path.closeSubpath()
        return path
    }()

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / Self.designSize
        let xOffset = rect.midX - (Self.designSize / 2) * scale
        let yOffset = rect.midY - (Self.designSize / 2) * scale
        return Self.basePath.applying(
            CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: xOffset, ty: yOffset)
        )
    }
}

public extension ShopAvatar where ImageContent == EmptyView {
    init(
        name: String? = nil,
        size: ShopAvatarSize = .xs,
        showsTint: Bool = true,
        fallbackBackgroundColor: Color = GravityColor.bgFillFixedDusk,
        showsFallbackTint: Bool = false,
        placeholderIcon: ShopIconName = .shopFilled,
        initials: String? = nil,
        fallbackStyle: ShopAvatarFallbackStyle? = nil
    ) {
        self.name = name
        self.size = size
        self.pointSize = size.points
        self.showsTint = showsTint
        self.fallbackBackgroundColor = fallbackBackgroundColor
        self.showsFallbackTint = showsFallbackTint
        self.placeholderIcon = placeholderIcon
        self.initialsOverride = initials
        self.fallbackStyle = fallbackStyle
        self.imageContent = nil
    }

    public init(
        name: String? = nil,
        pointSize: CGFloat,
        showsTint: Bool = true,
        fallbackBackgroundColor: Color = GravityColor.bgFillFixedDusk,
        showsFallbackTint: Bool = false,
        placeholderIcon: ShopIconName = .shopFilled,
        initials: String? = nil,
        fallbackStyle: ShopAvatarFallbackStyle? = nil
    ) {
        self.name = name
        self.size = ShopAvatarSize.nearest(to: pointSize)
        self.pointSize = pointSize
        self.showsTint = showsTint
        self.fallbackBackgroundColor = fallbackBackgroundColor
        self.showsFallbackTint = showsFallbackTint
        self.placeholderIcon = placeholderIcon
        self.initialsOverride = initials
        self.fallbackStyle = fallbackStyle
        self.imageContent = nil
    }
}

// MARK: - Previews

#Preview("Sizes") {
    HStack(alignment: .center, spacing: 16) {
        ForEach(ShopAvatarSize.allCases, id: \.self) { size in
            VStack(spacing: 8) {
                ShopAvatar(name: "Snow Peak", size: size)
                ShopText("\(Int(size.points))", style: .caption, color: ShopColor.textSecondary)
            }
        }
    }
    .padding()
    .background(ShopColor.background)
}

#Preview("States") {
    HStack(spacing: 16) {
        ShopAvatar(name: "Snow Peak", size: .m) {
            ShopColor.fillBrand
        }
        ShopAvatar(name: "Snow Peak", size: .m)
        ShopAvatar(size: .m)
        ShopAvatar(name: "Snow Peak", size: .m, showsTint: false) {
            ShopColor.fillBrand
        }
    }
    .padding()
    .background(ShopColor.background)
}

#Preview("Image") {
    HStack(alignment: .center, spacing: 16) {
        ForEach(ShopAvatarSize.allCases, id: \.self) { size in
            VStack(spacing: 8) {
                ShopAvatar(name: "Shop", size: size) {
                    ZStack {
                        ShopColor.fillBrand
                        ShopWordmark(
                            width: size.points * 0.62,
                            height: size.points * 0.28,
                            color: ShopColor.textFixedLight,
                            accessibilityLabel: nil
                        )
                    }
                }
                ShopText("\(Int(size.points))", style: .caption, color: ShopColor.textSecondary)
            }
        }
    }
    .padding()
    .background(ShopColor.background)
}
