import SwiftUI

#Preview("ShopMenu & ShopContextMenu") {
    VStack(spacing: 32) {
        ShopText("Tap the button for quick actions.\nLong-press the card for more.", style: .bodySmall, color: ShopColor.textSecondary, alignment: .center)
            .padding(.horizontal)

        HStack {
            Spacer()
            ShopMenu {
                ShopContextMenuItem("Share", icon: .share) {}
                ShopContextMenuItem("Copy link", icon: .link) {}
            } label: {
                ShopIconButton(.overflow, accessibilityLabel: "Quick actions", variant: .glass) {}
            }
        }
        .padding(.horizontal)

        ShopCard {
            VStack(alignment: .leading, spacing: 8) {
                ShopText("Running Shoes", style: .sectionTitle)
                ShopText("Long-press for options", style: .bodySmall, color: ShopColor.textSecondary)
            }
        }
        .shopContextMenu {
            ShopContextMenuItem("Add to favorites", icon: .navigationFavoritesFilled) {}
            ShopContextMenuItem("Hide", icon: .delete, role: .destructive) {}
        }
        .padding(.horizontal)

        Spacer()
    }
    .padding(.top, 60)
}
