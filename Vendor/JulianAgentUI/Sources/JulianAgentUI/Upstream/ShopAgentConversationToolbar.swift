import Gravity
import SwiftUI

/// System toolbar shared by standalone chats and conversations opened from a detail page.
struct ShopAgentConversationToolbar: ToolbarContent {
    let contextInfo: ShopAgentEmbeddedConversation.ContextInfo?
    let ratingModalOpen: Bool
    let conversationID: String?
    let showsCopyConversationIDButton: Bool
    let onNewThread: () -> Void
    let onCloseRating: () -> Void
    let onCopyConversationID: (String) -> Void
    var onBack: (() -> Void)? = nil
    var onCloseDraft: (() -> Void)? = nil
    var onHistory: (() -> Void)? = nil
    var onOpenContext: (() -> Void)? = nil
    var allowsNewThread = true

    var body: some ToolbarContent {
        if onCloseDraft == nil, let onBack {
            ShopToolbarBackButton(action: onBack)
        }

        if onCloseDraft == nil, let contextInfo {
            if #available(iOS 26.0, *) {
                // The back control can be supplied explicitly or by NavigationStack. Always start
                // context in a separate glass group so the two controls never share one capsule.
                ToolbarSpacer(.fixed, placement: .topBarLeading)
            }
            let contextItem = ToolbarItem(placement: .topBarLeading) {
                if let action = onOpenContext ?? onBack {
                    Button(action: action) {
                        ShopAgentContextToolbarLabel(info: contextInfo)
                    }
                    .accessibilityIdentifier("agent-toolbar-context")
                } else {
                    ShopAgentContextToolbarLabel(info: contextInfo)
                }
            }
            if #available(iOS 26.0, *) {
                contextItem.sharedBackgroundVisibility(.visible)
            } else {
                contextItem
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if let onCloseDraft {
                if let onHistory {
                    Button(action: onHistory) {
                        Label {
                            SwiftUI.Text(localizedString("Agent.Ask.History"))
                        } icon: {
                            ShopIcon(.history, size: .medium)
                        }
                    }
                        .shopToolbarIconStyle()
                        .accessibilityIdentifier("ask-history")
                }
                Button(action: onCloseDraft) {
                    Label(localizedString("Header.CloseA11yLabel"), systemImage: "xmark")
                }
                    .shopToolbarIconStyle()
                    .accessibilityIdentifier("ask-close")
            } else if ratingModalOpen {
                Button(action: onCloseRating) {
                    Label(localizedString("Header.CloseA11yLabel"), systemImage: "xmark")
                }
                .shopToolbarIconStyle()
            } else {
                if showsCopyConversationIDButton, let conversationID, !conversationID.isEmpty {
                    Button(action: { onCopyConversationID(conversationID) }) {
                        Label {
                            SwiftUI.Text(localizedString("AgentScreen.CopyConversationIdA11yLabel"))
                        } icon: {
                            ShopIcon(.copy, size: .medium)
                        }
                    }
                    .shopToolbarIconStyle()
                }
                if allowsNewThread {
                    Button(action: onNewThread) {
                        Label {
                            SwiftUI.Text(localizedString("Threads.NewThreadA11yLabel"))
                        } icon: {
                            ShopIcon(.newThread, size: .medium)
                        }
                    }
                    .shopToolbarIconStyle()
                    .accessibilityIdentifier("agent-toolbar-new-conversation")
                }
            }
        }
    }
}
