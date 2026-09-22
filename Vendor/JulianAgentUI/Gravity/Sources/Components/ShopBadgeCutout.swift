import SwiftUI

private enum ShopBadgeCutoutMetrics {
    static let cutoutGap: CGFloat = GravitySpacing.space2
    static let animationDuration: TimeInterval = 0.24
    static let exitAnimation = Animation.timingCurve(0.45, 0, 1, 1, duration: animationDuration)

    static func incomingAnimation(delay: TimeInterval) -> Animation {
        let animation = Animation.timingCurve(0, 0, 0.15, 1, duration: animationDuration)
        return delay > 0 ? animation.delay(delay) : animation
    }

    /// RN IconWithBadgeCutout nudges the badge slightly outside the icon's top-right edge.
    static let baseBadgeOffset = CGSize(width: 2, height: -GravitySpacing.space2)
}

/// Overlays a circular activity badge on top-trailing content while cutting a
/// transparent hole out of the content underneath the badge.
///
/// The cutout is always transparent. Do not replace it with a background-colored
/// circle: this component is used over glass and translucent surfaces where a
/// painted backing would be visible.
public struct ShopBadgeCutout<Content: View>: View {
    private let showsBadge: Bool
    private let badgeSize: CGFloat
    private let badgeColor: Color
    private let badgeAdditionalOffset: CGSize
    private let badgeAppearanceDelay: TimeInterval
    private let badgeAccessibilityLabel: String?
    private let content: Content

    @Environment(\.layoutDirection) private var layoutDirection

    @State private var badgeProgress: CGFloat

    public init(
        showsBadge: Bool,
        badgeSize: CGFloat,
        badgeColor: Color = GravityColor.bgFillCritical,
        badgeAdditionalOffset: CGSize = .zero,
        badgeAppearanceDelay: TimeInterval = 0,
        badgeAccessibilityLabel: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.showsBadge = showsBadge
        self.badgeSize = badgeSize
        self.badgeColor = badgeColor
        self.badgeAdditionalOffset = badgeAdditionalOffset
        self.badgeAppearanceDelay = badgeAppearanceDelay
        self.badgeAccessibilityLabel = badgeAccessibilityLabel
        self.content = content()
        _badgeProgress = State(initialValue: showsBadge && badgeAppearanceDelay == 0 ? 1 : 0)
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            content
                .mask {
                    ShopBadgeCutoutMask(
                        badgeSize: badgeSize,
                        badgeAdditionalOffset: badgeAdditionalOffset,
                        layoutDirection: layoutDirection,
                        progress: badgeProgress
                    )
                    .fill(style: FillStyle(eoFill: true))
                }

            Circle()
                .fill(badgeColor)
                .frame(width: badgeSize, height: badgeSize)
                .scaleEffect(visibleBadgeScale)
                .opacity(badgeProgress)
                .offset(resolvedBadgeOffset)
                .accessibilityHidden(badgeAccessibilityLabel == nil || showsBadge == false)
                .accessibilityLabel(SwiftUI.Text(badgeAccessibilityLabel ?? ""))
        }
        .onAppear {
            guard showsBadge else {
                badgeProgress = 0
                return
            }

            withAnimation(ShopBadgeCutoutMetrics.incomingAnimation(delay: badgeAppearanceDelay)) {
                badgeProgress = 1
            }
        }
        .onChange(of: showsBadge) { _, newValue in
            let animation = newValue
                ? ShopBadgeCutoutMetrics.incomingAnimation(delay: badgeAppearanceDelay)
                : ShopBadgeCutoutMetrics.exitAnimation
            withAnimation(animation) {
                badgeProgress = newValue ? 1 : 0
            }
        }
    }

    private var visibleBadgeScale: CGFloat {
        sqrt(max(badgeProgress, 0))
    }

    private var badgeOffset: CGSize {
        CGSize(
            width: ShopBadgeCutoutMetrics.baseBadgeOffset.width
                - ShopBadgeCutoutMetrics.cutoutGap
                + badgeAdditionalOffset.width,
            height: ShopBadgeCutoutMetrics.cutoutGap
                + ShopBadgeCutoutMetrics.baseBadgeOffset.height
                + badgeAdditionalOffset.height
        )
    }

    private var resolvedBadgeOffset: CGSize {
        CGSize(
            width: layoutDirection == .rightToLeft ? -badgeOffset.width : badgeOffset.width,
            height: badgeOffset.height
        )
    }
}

private struct ShopBadgeCutoutMask: Shape {
    let badgeSize: CGFloat
    let badgeAdditionalOffset: CGSize
    let layoutDirection: LayoutDirection
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        guard progress > 0 else {
            return path
        }

        let badgeRadius = badgeSize / 2
        let baseCutoutRadius = badgeRadius + ShopBadgeCutoutMetrics.cutoutGap
        let cutoutRadius = baseCutoutRadius * progress
        let horizontalOffset = ShopBadgeCutoutMetrics.baseBadgeOffset.width + badgeAdditionalOffset.width
        let centerX = switch layoutDirection {
        case .rightToLeft:
            rect.minX + baseCutoutRadius - horizontalOffset
        default:
            rect.maxX - baseCutoutRadius + horizontalOffset
        }
        let center = CGPoint(
            x: centerX,
            y: rect.minY + baseCutoutRadius
                + ShopBadgeCutoutMetrics.baseBadgeOffset.height
                + badgeAdditionalOffset.height
        )
        path.addEllipse(
            in: CGRect(
                x: center.x - cutoutRadius,
                y: center.y - cutoutRadius,
                width: cutoutRadius * 2,
                height: cutoutRadius * 2
            )
        )

        return path
    }
}

#Preview("ShopBadgeCutout") {
    VStack(spacing: GravitySpacing.space24) {
        HStack(spacing: GravitySpacing.space24) {
            ShopBadgeCutout(showsBadge: true, badgeSize: GravitySpacing.space6) {
                ShopIcon(.bellFilled, pointSize: GravitySpacing.space20, color: GravityColor.text)
                    .frame(width: GravitySpacing.space20, height: GravitySpacing.space20)
            }

            ShopBadgeCutout(showsBadge: true, badgeSize: GravitySpacing.space8) {
                ShopIcon(.orderFilled, size: .large, color: GravityColor.text)
                    .frame(width: GravitySpacing.space24, height: GravitySpacing.space24)
            }

            ShopBadgeCutout(showsBadge: false, badgeSize: GravitySpacing.space8) {
                ShopIcon(.orderFilled, size: .large, color: GravityColor.text)
                    .frame(width: GravitySpacing.space24, height: GravitySpacing.space24)
            }
        }

        ShopBadgeCutout(
            showsBadge: true,
            badgeSize: GravitySpacing.space10,
            badgeAdditionalOffset: CGSize(
                width: GravitySpacing.space4,
                height: -GravitySpacing.space4
            )
        ) {
            RoundedRectangle(cornerRadius: GravityRadius.radius8, style: .continuous)
                .fill(GravityColor.bgFillSecondary)
                .frame(width: GravitySpacing.space44, height: GravitySpacing.space44)
                .overlay {
                    ShopIcon(.noImage, size: .large, color: GravityColor.textTertiary)
                }
        }
    }
    .padding(GravitySpacing.space24)
    .background(.ultraThinMaterial)
}
