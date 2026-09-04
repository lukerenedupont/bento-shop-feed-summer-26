import SwiftUI

/// Single source of truth for floating feed and topic navigation chrome.
enum FeedNavigationStyle {
    static let avatarSize: CGFloat = 40
    static let controlSize: CGFloat = 40
    static let iconSize: CGFloat = 15
    static let labelSize: CGFloat = 16
    static let pillHorizontalPadding: CGFloat = GravitySpacing.space8
    static let selectedPillHorizontalPadding: CGFloat = GravitySpacing.space12
    static let itemSpacing: CGFloat = GravitySpacing.space6
    static let railLeadingInset: CGFloat = 64
    static let railTrailingInset: CGFloat = GravitySpacing.space20
    static let selectedFill = Color.white.opacity(0.85)

    static let labelFont = GravityTypography.buttonLarge.swiftUIFont
    static let iconFont = Font.system(size: iconSize, weight: .semibold)
}
