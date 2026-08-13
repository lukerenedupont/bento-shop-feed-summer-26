import Foundation
import SwiftUI

/// Border radius tokens matching Gravity's borderRadii.ts.
enum GravityRadius {
    static let none: CGFloat = 0
    static let r4: CGFloat = 4
    static let r6: CGFloat = 6
    static let r8: CGFloat = 8
    static let r10: CGFloat = 10
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    static let r20: CGFloat = 20
    static let r24: CGFloat = 24
    static let r28: CGFloat = 28
    static let r36: CGFloat = 36
    static let r40: CGFloat = 40
    static let max: CGFloat = 9999999
}

#Preview("Border radii") {
    let radii: [(String, CGFloat)] = [
        ("none", GravityRadius.none),
        ("r4", GravityRadius.r4),
        ("r6", GravityRadius.r6),
        ("r8", GravityRadius.r8),
        ("r10", GravityRadius.r10),
        ("r12", GravityRadius.r12),
        ("r16", GravityRadius.r16),
        ("r20", GravityRadius.r20),
        ("r24", GravityRadius.r24),
        ("r28", GravityRadius.r28),
        ("r36", GravityRadius.r36),
        ("r40", GravityRadius.r40),
        ("max (capsule)", GravityRadius.max),
    ]
    return ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: GravitySpacing.space12)],
                  spacing: GravitySpacing.space16) {
            ForEach(radii, id: \.0) { item in
                VStack(spacing: GravitySpacing.space6) {
                    RoundedRectangle(cornerRadius: min(item.1, 40))
                        .fill(GravityColors.bgFillBrand)
                        .frame(width: 90, height: 90)
                    Text(item.0)
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(GravityColors.textSecondary)
                }
            }
        }
        .padding(GravitySpacing.space16)
    }
    .background(GravityColors.bg)
}
