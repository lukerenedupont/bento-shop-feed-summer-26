import SwiftUI

/// Single source of truth for floating feed and topic navigation chrome.
enum FeedNavigationStyle {
    static let avatarSize: CGFloat = 40
    static let controlSize: CGFloat = 40
    static let iconSize: CGFloat = 15
    static let labelSize: CGFloat = 17
    static let pillHorizontalPadding: CGFloat = GravitySpacing.space16
    static let itemSpacing: CGFloat = GravitySpacing.space4
    static let railLeadingInset: CGFloat = 64
    static let railTrailingInset: CGFloat = GravitySpacing.space20
    static let selectedFill = Color.white.opacity(0.94)

    static let labelFont = GravityFont.semiBold.fixedFont(size: labelSize)
    static let iconFont = Font.system(size: iconSize, weight: .semibold)
}
