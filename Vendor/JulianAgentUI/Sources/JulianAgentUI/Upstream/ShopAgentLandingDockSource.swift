import SwiftUI
import Gravity
import UIKit

/// Adapts the existing landing submission/upload owner to the persistent shell input.
struct ShopAgentLandingDockSource: View {
    let viewModel: ShopAgentLandingViewModel
    @Binding var query: String
    @Binding var isFocused: Bool
    let navigation: ShopBottomNavigationConversation
    let starters: ShopAskStartersModel?
    var contextualStarters: [ShopProductConversationStarter] = []
    var maximumDraftStarterCount: Int? = nil
    var placeholder: String? = nil
    let isActive: Bool
    let onAddContext: (ShopAgentComposerAttachmentPickerSource) -> Void
    let onRemoveImageAttachment: (UUID) -> Void
    let onSubmit: () -> Void
    let onStarter: (ShopAskStarter) -> Void
    var onContextualStarter: (String) -> Void = { _ in }
    let onHistory: () -> Void

    var body: some View {
        ShopAgentUIKitComposer(
            query: $query,
            isFocused: $isFocused,
            placeholder: placeholder ?? localizedString(navigation.isDraftPresented
                ? "Agent.Ask.Placeholder" : "ContextualSearchTabBar.SearchPlaceholderAgentLanding"),
            contextSummary: viewModel.activeContextSummary,
            selectedContext: ShopAgentUIKitComposerContext(contextItems: viewModel.contextAttachments.items),
            imageAttachments: viewModel.imageAttachments,
            canSubmit: viewModel.canSubmit,
            canAddContext: true,
            restingBottomInset: 0,
            onHeightChange: { _ in },
            onFocus: viewModel.handleInputFocus,
            onAddContext: onAddContext,
            onRemoveContext: viewModel.clearActiveContextItems,
            onRemoveImageAttachment: onRemoveImageAttachment,
            onSubmit: onSubmit
        )
        .hosted(in: navigation, isEnabled: isActive)
        .ignoresSafeArea()

        ShopAgentDockedAccessory(
            navigation: navigation,
            isVisible: navigation.isDraftPresented && query.isEmpty && !viewModel.isThreadsPanelOpen,
            onHistory: onHistory
        ) {
            if contextualStarters.isEmpty {
                ShopAskStartersView(starters: starters?.starters ?? [], onSelect: onStarter)
            } else {
                ShopProductConversationStartersView(
                    starters: contextualStarters, onSelect: onContextualStarter,
                    layout: .stacked, horizontalInset: 0,
                    maximumDraftCount: maximumDraftStarterCount
                )
            }
        }
        .frame(width: 0, height: 0)
    }
}

