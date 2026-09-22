import Gravity
import SwiftUI
import UIKit

/// Hosts the same starter rows inline and while drafting, preserving their
/// horizontal scroll positions instead of fading between duplicate instances.
struct ShopProductConversationStartersPlacement: UIViewRepresentable {
    @Environment(\.shopProductConversationStartersLayout) private var layout

    let starters: [ShopProductConversationStarter]
    let navigation: ShopBottomNavigationConversation
    let onSelect: (String) -> Void

    func makeUIView(context: Context) -> ShopAgentInlineAccessoryContainer {
        ShopAgentInlineAccessoryContainer()
    }

    func updateUIView(_ view: ShopAgentInlineAccessoryContainer, context: Context) {
        view.update(configuration: UIHostingConfiguration {
            ShopTheme {
                ShopProductConversationStartersView(
                    starters: starters,
                    onSelect: onSelect,
                    layout: layout,
                    horizontalInset: GravitySpacing.space8
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }.margins(.all, 0))
        navigation.inlineStartersContainer = view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ShopAgentInlineAccessoryContainer, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return uiView.fittingSize(width: width)
    }
}
