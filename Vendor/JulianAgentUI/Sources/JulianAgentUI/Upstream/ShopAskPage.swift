import Gravity
import SwiftUI

/// Shared system draft toolbar. UIKit owns the backdrop and keyboard geometry.
struct ShopAskPage: View {
    let onClose: () -> Void
    var onHistory: (() -> Void)?

    var body: some View {
        NavigationStack {
            Button(action: onClose) {
                Color.clear
                    .contentShape(.rect)
            }
                .buttonStyle(.plain)
                .accessibilityLabel(localizedString("Header.CloseA11yLabel"))
                .accessibilityIdentifier("ask-background-close")
                .ignoresSafeArea()
                .containerBackground(.clear, for: .navigation)
                .toolbar(.visible, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
                .navigationTitle(localizedString("Agent.Ask.Title"))
                .toolbarTitleDisplayMode(.inlineLarge)
                .background {
                    ShopNavigationTitleStyle(style: .posterXS)
                        .frame(width: 0, height: 0)
                }
                .toolbar {
                    ShopAgentConversationToolbar(
                        contextInfo: nil, ratingModalOpen: false,
                        conversationID: nil, showsCopyConversationIDButton: false,
                        onNewThread: {}, onCloseRating: {}, onCopyConversationID: { _ in },
                        onCloseDraft: onClose, onHistory: onHistory
                    )
                }
                .tint(GravityColor.text)
        }
        .ignoresSafeArea(.keyboard)
        .accessibilityIdentifier("ask-page")
    }
}
