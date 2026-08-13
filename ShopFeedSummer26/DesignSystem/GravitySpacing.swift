import Foundation
import SwiftUI

/// Spacing scale matching Gravity's spacing.ts.
enum GravitySpacing {
    // Raw scale
    static let space0: CGFloat = 0
    static let space2: CGFloat = 2
    static let space4: CGFloat = 4
    static let space6: CGFloat = 6
    static let space8: CGFloat = 8
    static let space10: CGFloat = 10
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32
    static let space36: CGFloat = 36
    static let space40: CGFloat = 40
    static let space44: CGFloat = 44
    static let space48: CGFloat = 48
    static let space64: CGFloat = 64

    // Negative values
    static let spaceNeg2: CGFloat = -2
    static let spaceNeg4: CGFloat = -4
    static let spaceNeg8: CGFloat = -8
    static let spaceNeg12: CGFloat = -12
    static let spaceNeg16: CGFloat = -16
    static let spaceNeg20: CGFloat = -20
    static let spaceNeg24: CGFloat = -24
    static let spaceNeg32: CGFloat = -32
    static let spaceNeg36: CGFloat = -36
    static let spaceNeg40: CGFloat = -40
    static let spaceNeg48: CGFloat = -48
    static let spaceNeg64: CGFloat = -64

    // Semantic tokens
    static let screenMargin: CGFloat = space16
    static let sectionGap: CGFloat = space36
    static let cardRowGutter: CGFloat = space8
    static let cardPadding: CGFloat = space16
}

#Preview("Spacing scale") {
    let scale: [(String, CGFloat)] = [
        ("space2", GravitySpacing.space2),
        ("space4", GravitySpacing.space4),
        ("space6", GravitySpacing.space6),
        ("space8", GravitySpacing.space8),
        ("space10", GravitySpacing.space10),
        ("space12", GravitySpacing.space12),
        ("space16 / screen-margin / card-padding", GravitySpacing.space16),
        ("space20", GravitySpacing.space20),
        ("space24", GravitySpacing.space24),
        ("space32", GravitySpacing.space32),
        ("space36 / section-gap", GravitySpacing.space36),
        ("space40", GravitySpacing.space40),
        ("space48", GravitySpacing.space48),
        ("space64", GravitySpacing.space64),
    ]
    return ScrollView {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            ForEach(scale, id: \.0) { item in
                HStack(spacing: GravitySpacing.space12) {
                    Rectangle()
                        .fill(GravityColors.bgFillBrand)
                        .frame(width: item.1, height: 20)
                    Text(item.0)
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(GravityColors.text)
                    Spacer()
                }
            }
        }
        .padding(GravitySpacing.space16)
    }
    .background(GravityColors.bg)
}
