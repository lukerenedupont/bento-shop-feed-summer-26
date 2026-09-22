import Gravity
import SwiftUI

/// Product, order, or search context in the conversation's system toolbar.
struct ShopAgentContextToolbarLabel: View {
    let info: ShopAgentEmbeddedConversation.ContextInfo

    private var isSearchContext: Bool { info.icon == .search }

    var body: some View {
        ShopContextLockup(
            title: info.title,
            contentSpacing: isSearchContext ? GravitySpacing.space8 : nil,
            titleStyle: isSearchContext ? .bodyTitleLarge : .bodyTitleSmall
        ) {
            if let icon = info.icon {
                ShopIcon(icon, size: .medium, color: GravityColor.text)
            } else if let imageURL = info.imageURL {
                ShopRemoteImage(image: .init(url: imageURL, altText: nil, width: nil, height: nil),
                                displaySize: CGSize(width: GravitySpacing.space32, height: GravitySpacing.space32))
                    .frame(width: GravitySpacing.space32, height: GravitySpacing.space32)
                    .overlay {
                        GravityColor.bgOverlayFixedDark04
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: GravityRadius.radius8))
                    .overlay {
                        RoundedRectangle(cornerRadius: GravityRadius.radius8, style: .continuous)
                            .strokeBorder(GravityColor.borderImage, lineWidth: 0.5)
                            .allowsHitTesting(false)
                    }
            }
        } subtitle: {
            if let subtitle = info.subtitle, !subtitle.isEmpty {
                ShopText(subtitle, style: .captionBold, color: GravityColor.textSecondary)
                    .lineLimit(1).truncationMode(.tail)
            }
        }
        // Toolbar custom items are measured with a compressed width. Supply the
        // complete label's ideal width, capped to leave room for the trailing action.
        .frame(maxWidth: 220, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.trailing, isSearchContext ? GravitySpacing.space4 : GravitySpacing.space0)
        .accessibilityElement(children: .combine)
    }
}
