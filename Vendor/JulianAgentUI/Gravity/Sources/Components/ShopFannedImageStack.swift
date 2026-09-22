import SwiftUI

public enum ShopFannedImageStackSize {
    case xxSmall
    case xSmall
    case small
    case medium
    case large
    case xLarge
    case xxLarge

    public var value: CGFloat {
        switch self {
        case .xxSmall:
            28
        case .xSmall:
            GravitySpacing.space32
        case .small:
            GravitySpacing.space40
        case .medium:
            GravitySpacing.space48
        case .large:
            GravitySpacing.space64
        case .xLarge:
            72
        case .xxLarge:
            120
        }
    }
}

public enum ShopFannedImageStackGap {
    case small
    case medium
    case large
    case xLarge
    case xxLarge

    public var value: CGFloat {
        switch self {
        case .small:
            GravitySpacing.space2
        case .medium:
            GravitySpacing.space4
        case .large:
            GravitySpacing.space8
        case .xLarge:
            GravitySpacing.space16
        case .xxLarge:
            GravitySpacing.space32
        }
    }
}

public enum ShopFannedImageStackDirection {
    case left
    case right
}

public struct ShopFannedImageStack<Content: View, Placeholder: View>: View {
    private let itemCount: Int
    private let size: ShopFannedImageStackSize
    private let gap: ShopFannedImageStackGap
    private let direction: ShopFannedImageStackDirection
    private let reservesOverflowInLayout: Bool
    private let content: (Int) -> Content
    private let placeholder: () -> Placeholder

    public init(
        itemCount: Int,
        size: ShopFannedImageStackSize = .medium,
        gap: ShopFannedImageStackGap = .medium,
        direction: ShopFannedImageStackDirection = .left,
        reservesOverflowInLayout: Bool = false,
        @ViewBuilder content: @escaping (Int) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.itemCount = min(max(itemCount, 0), 3)
        self.size = size
        self.gap = gap
        self.direction = direction
        self.reservesOverflowInLayout = reservesOverflowInLayout
        self.content = content
        self.placeholder = placeholder
    }

    public var body: some View {
        let directionSign: CGFloat = direction == .right ? 1 : -1
        let rotationStepDegrees = 5.0
        let maxOffset = CGFloat(max(itemCount - 1, 0)) * gap.value
        let shouldReserveOverflow = reservesOverflowInLayout && itemCount > 1
        let rotationInset = shouldReserveOverflow ? GravitySpacing.space2 : 0
        let fanOverflow = shouldReserveOverflow ? maxOffset + rotationInset : 0
        let leadingInset = direction == .left ? fanOverflow : rotationInset
        let reservedWidth = size.value + (shouldReserveOverflow ? maxOffset + rotationInset * 2 : 0)

        ZStack(alignment: .topLeading) {
            if itemCount == 0 {
                placeholder()
                    .offset(x: leadingInset)
            } else {
                ForEach(0 ..< itemCount, id: \.self) { index in
                    content(index)
                        .rotationEffect(.degrees(directionSign * rotationStepDegrees * Double(index)))
                        .offset(
                            x: leadingInset + directionSign * CGFloat(index) * gap.value,
                            y: CGFloat(index) * gap.value * 0.1
                        )
                        .zIndex(Double(itemCount - index))
                }
            }
        }
        .frame(width: reservedWidth, height: size.value, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

#Preview("ShopFannedImageStack") {
    FannedImageStackPreviewContent()
        .background(GravityColor.bg)
}

private struct FannedImageStackPreviewContent: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GravitySpacing.space32) {
                section("Past orders row", note: "S / gap S / fans left") {
                    ShopFannedImageStack(itemCount: 3, size: .small, gap: .small) { index in
                        FannedImageStackPreviewTile(index: index, displayWidth: PreviewMetric.small)
                    } placeholder: {
                        FannedImageStackPreviewPlaceholder(displayWidth: PreviewMetric.small)
                    }
                }

                section("Order card", note: "L / gap S / product-card image chrome") {
                    ShopFannedImageStack(itemCount: 3, size: .large, gap: .small) { index in
                        FannedImageStackPreviewTile(index: index, displayWidth: PreviewMetric.large)
                    } placeholder: {
                        FannedImageStackPreviewPlaceholder(displayWidth: PreviewMetric.large)
                    }
                }

                section("Single image", note: "XL / no rotation or offset") {
                    ShopFannedImageStack(itemCount: 1, size: .xLarge, gap: .small) { index in
                        FannedImageStackPreviewTile(index: index, displayWidth: PreviewMetric.xLarge)
                    } placeholder: {
                        FannedImageStackPreviewPlaceholder(displayWidth: PreviewMetric.xLarge)
                    }
                }

                section("Fans right", note: "M / gap M / direction right") {
                    ShopFannedImageStack(itemCount: 3, size: .medium, gap: .medium, direction: .right) { index in
                        FannedImageStackPreviewTile(index: index, displayWidth: PreviewMetric.medium)
                    } placeholder: {
                        FannedImageStackPreviewPlaceholder(displayWidth: PreviewMetric.medium)
                    }
                }

                section("Wider fan", note: "M / gap XL") {
                    ShopFannedImageStack(itemCount: 3, size: .medium, gap: .xLarge) { index in
                        FannedImageStackPreviewTile(index: index, displayWidth: PreviewMetric.medium)
                    } placeholder: {
                        FannedImageStackPreviewPlaceholder(displayWidth: PreviewMetric.medium)
                    }
                }

                section("Placeholder", note: "Empty stack") {
                    ShopFannedImageStack(itemCount: 0, size: .small, gap: .small) { index in
                        FannedImageStackPreviewTile(index: index, displayWidth: PreviewMetric.small)
                    } placeholder: {
                        FannedImageStackPreviewPlaceholder(displayWidth: PreviewMetric.small)
                    }
                }
            }
            .padding(GravitySpacing.screenMargin)
        }
    }

    private func section<Content: View>(_ title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                ShopText(title)
                    .font(.headline)
                    .foregroundStyle(GravityColor.text)
                ShopText(note)
                    .font(.caption)
                    .foregroundStyle(GravityColor.textSecondary)
            }

            ZStack(alignment: .topLeading) {
                content()

                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(GravityColor.border)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, GravitySpacing.space64)
            .padding(.vertical, GravitySpacing.space12)
        }
    }
}

private enum PreviewMetric {
    static let small: CGFloat = 40
    static let medium: CGFloat = 48
    static let large: CGFloat = 64
    static let xLarge: CGFloat = 72
}

private struct FannedImageStackPreviewTile: View {
    private let index: Int
    private let displayWidth: CGFloat

    private static let colors: [Color] = [
        Color(red: 0.99, green: 0.54, blue: 0.36),
        Color(red: 0.54, green: 0.74, blue: 0.98),
        Color(red: 0.67, green: 0.82, blue: 0.55),
    ]

    init(index: Int, displayWidth: CGFloat) {
        self.index = index
        self.displayWidth = displayWidth
    }

    var body: some View {
        ShopProductImageTile(displayWidth: displayWidth, cornerRadius: GravityRadius.radius8) {
            LinearGradient(
                colors: [Self.colors[index % Self.colors.count], Self.colors[index % Self.colors.count].opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .frame(width: displayWidth, height: displayWidth)
    }
}

private struct FannedImageStackPreviewPlaceholder: View {
    private let displayWidth: CGFloat

    init(displayWidth: CGFloat) {
        self.displayWidth = displayWidth
    }

    var body: some View {
        ShopProductImageTile(displayWidth: displayWidth, cornerRadius: GravityRadius.radius8) {
            ZStack {
                GravityColor.bgFillSecondary
                ShopIcon(.noImage, size: .medium, color: GravityColor.textTertiary)
            }
        }
        .frame(width: displayWidth, height: displayWidth)
    }
}
