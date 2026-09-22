import Gravity
import SwiftUI

/// Shared image/title layout for identity and conversation context labels.
/// The enclosing system button owns the outer capsule insets.
struct ShopContextLockup<Leading: View, Subtitle: View>: View {
    let title: String
    var leadingPadding: CGFloat = GravitySpacing.space4
    var contentSpacing: CGFloat? = nil
    var titleStyle: GravityTextStyle = .bodyTitleSmall
    var fillsAvailableWidth = false
    @ViewBuilder let leading: Leading
    @ViewBuilder let subtitle: Subtitle

    var body: some View {
        HStack(spacing: contentSpacing ?? (GravitySpacing.space8 + leadingPadding)) {
            // Preserve vertical halo clearance independently of the content gap.
            // The system button already provides the leading inset.
            leading
                .padding(.vertical, leadingPadding)

            VStack(alignment: .leading, spacing: GravitySpacing.space2) {
                ShopText(title, style: titleStyle, color: GravityColor.text)
                    .lineLimit(1)
                    .truncationMode(.tail)

                subtitle
            }
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, alignment: .leading)
        }
        .padding(.trailing, GravitySpacing.space8)
    }
}
