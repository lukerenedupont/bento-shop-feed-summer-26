import SwiftUI
import UIKit

public enum ShopBadgeTextScale {
    public static let maximumDynamicTypeSize: DynamicTypeSize = .xxLarge

    public static func range(upTo maximumDynamicTypeSize: DynamicTypeSize) -> ClosedRange<DynamicTypeSize> {
        .xSmall ... maximumDynamicTypeSize
    }

    public static func isLargeContentViewerActive(
        dynamicTypeSize: DynamicTypeSize,
        maximumDynamicTypeSize: DynamicTypeSize? = Self.maximumDynamicTypeSize,
        label: String?
    ) -> Bool {
        guard let maximumDynamicTypeSize,
              let label,
              label.isEmpty == false else {
            return false
        }

        return dynamicTypeSize > maximumDynamicTypeSize
    }
}

/// Compact, display-only pill label for status, counts, and annotations.
///
/// ShopBadge is intentionally non-interactive. Use buttons, chips, or menu items for
/// tappable pill controls.
public struct ShopBadge: View {
    private let label: String
    private let variant: ShopBadgeVariant
    private let leadingIcon: GravityIconName?
    private let accessibilityLabel: String?

    public init(
        _ label: String,
        variant: ShopBadgeVariant = .default,
        leadingIcon: GravityIconName? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.label = label
        self.variant = variant
        self.leadingIcon = leadingIcon
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        ShopBadgeSurface(
            accessibilityLabel: accessibilityLabel ?? label,
            background: { variant.backgroundColor }
        ) {
            HStack(alignment: .center, spacing: GravitySpacing.space2) {
                if let leadingIcon {
                    ShopIcon(leadingIcon, size: .xSmall, color: variant.foregroundColor)
                        .accessibilityHidden(true)
                }

                ShopText(label, style: .badgeBold, color: variant.foregroundColor)
                    .lineLimit(1)
            }
        }
    }
}

/// Shared badge chrome for feature-level badges that need ShopBadge's shape but own
/// their content or background treatment.
///
/// Prefer `ShopBadge` for generic status/count annotations. Reach for this
/// surface from feature components only when the feature owns semantic content
/// the primitive should not absorb, such as a price badge with an original-price
/// strikethrough or a product-image glass background.
public struct ShopBadgeSurface<Background: View, Content: View>: View {
    private let accessibilityLabel: String
    private let largeContentViewerLabel: String?
    private let maximumDynamicTypeSize: DynamicTypeSize?
    private let background: Background
    private let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        accessibilityLabel: String,
        largeContentViewerLabel: String? = nil,
        maximumDynamicTypeSize: DynamicTypeSize? = ShopBadgeTextScale.maximumDynamicTypeSize,
        @ViewBuilder background: () -> Background,
        @ViewBuilder content: () -> Content
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.largeContentViewerLabel = largeContentViewerLabel ?? accessibilityLabel
        self.maximumDynamicTypeSize = maximumDynamicTypeSize
        self.background = background()
        self.content = content()
    }

    public var body: some View {
        content
            .shopBadgeTextScale(maximumDynamicTypeSize: maximumDynamicTypeSize)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
            .padding(.horizontal, GravitySpacing.space6)
            .padding(.vertical, GravitySpacing.space2)
            .frame(minWidth: GravitySpacing.space24)
            .background(background)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .allowsHitTesting(showsLargeContentViewer)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(SwiftUI.Text(accessibilityLabel))
            .overlay {
                if showsLargeContentViewer {
                    ShopBadgeLargeContentViewerHost(label: largeContentViewerLabel ?? "")
                        .accessibilityHidden(true)
                }
            }
    }

    private var showsLargeContentViewer: Bool {
        ShopBadgeTextScale.isLargeContentViewerActive(
            dynamicTypeSize: dynamicTypeSize,
            maximumDynamicTypeSize: maximumDynamicTypeSize,
            label: largeContentViewerLabel
        )
    }
}

struct ShopBadgeLargeContentViewerHost: UIViewRepresentable {
    let label: String

    func makeUIView(context: Context) -> ShopBadgeLargeContentViewerView {
        let view = ShopBadgeLargeContentViewerView()
        view.configure(label: label)
        return view
    }

    func updateUIView(_ view: ShopBadgeLargeContentViewerView, context: Context) {
        view.configure(label: label)
    }
}

final class ShopBadgeLargeContentViewerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isAccessibilityElement = false
        addInteraction(UILargeContentViewerInteraction())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(label: String) {
        let hasLabel = label.isEmpty == false
        isUserInteractionEnabled = hasLabel
        showsLargeContentViewer = hasLabel
        largeContentTitle = hasLabel ? label : nil
    }
}

private extension View {
    @ViewBuilder
    func shopBadgeTextScale(maximumDynamicTypeSize: DynamicTypeSize?) -> some View {
        if let maximumDynamicTypeSize {
            dynamicTypeSize(ShopBadgeTextScale.range(upTo: maximumDynamicTypeSize))
        } else {
            self
        }
    }
}

public enum ShopBadgeVariant: Sendable, CaseIterable {
    /// Black fill with white text. Use for bold emphasis chips like sale or discount labels.
    case `default`
    /// White fill with black text. Use against dark surfaces.
    case inverse
    /// Translucent dark fill with white text. Use for quiet annotations over imagery.
    case subdued
    /// Purple fill with white text. Use for rare active brand moments.
    case brand
    /// Pale red fill with red text. Use for errors, alerts, and critical statuses.
    case critical

    var backgroundColor: Color {
        switch self {
        case .default:
            GravityColor.bgFillFixedDark
        case .inverse:
            GravityColor.bgFillFixedLight
        case .subdued:
            GravityColor.bgOverlayFixedIcon
        case .brand:
            GravityColor.bgFillBrand
        case .critical:
            GravityColor.bgFillCriticalSecondary
        }
    }

    var foregroundColor: Color {
        switch self {
        case .default, .subdued, .brand:
            GravityColor.textFixedLight
        case .inverse:
            GravityColor.textFixedDark
        case .critical:
            GravityColor.textCritical
        }
    }
}

// MARK: - Previews

#Preview("ShopBadge / Variants") {
    VStack(alignment: .center, spacing: GravitySpacing.space12) {
        ShopBadge("Default")
        ShopBadge("Inverse", variant: .inverse)
            .padding(GravitySpacing.space8)
            .background(GravityColor.bgFillFixedDark)
        ShopBadge("Subdued", variant: .subdued)
            .padding(GravitySpacing.space8)
            .background(
                LinearGradient(
                    colors: [GravityColor.bgFillBrand, GravityColor.bgFillCritical],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        ShopBadge("Brand", variant: .brand)
        ShopBadge("Critical", variant: .critical)
        ShopBadge("Warnings", variant: .subdued, leadingIcon: .alertTriangle)
            .padding(GravitySpacing.space8)
            .background(GravityColor.bg)
    }
    .padding()
}
