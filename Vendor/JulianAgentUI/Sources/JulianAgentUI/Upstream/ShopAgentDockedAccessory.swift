import Gravity
import SwiftUI
import UIKit

/// Supplies SwiftUI content to the shared UIKit dock, anchored to the composer's
/// actual top edge. No keyboard-height measurement or second input is needed.
struct ShopAgentDockedAccessory<Content: View>: UIViewRepresentable {
    let navigation: ShopBottomNavigationConversation
    let isVisible: Bool
    var onHistory: (() -> Void)? = nil
    @ViewBuilder let content: Content

    func makeUIView(context: Context) -> ShopAgentDockedAccessorySourceView {
        ShopAgentDockedAccessorySourceView()
    }

    func updateUIView(_ view: ShopAgentDockedAccessorySourceView, context: Context) {
        if view.navigation !== navigation { view.disconnect() }
        view.navigation = navigation
        let presentation = view.presentation
        presentation.updateDraft(isPresented: navigation.isDraftPresented)
        let configuration = UIHostingConfiguration {
            ShopTheme {
                content
                    .environment(\.shopConversationStarterPresentation, presentation)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.margins(.all, 0)
        view.contentContainer.update(configuration: configuration)
        view.isAccessoryVisible = isVisible
        view.onHistory = onHistory
        navigation.dockedAccessorySource = view
        navigation.controller?.updateDockedAccessory()
    }

    static func dismantleUIView(_ view: ShopAgentDockedAccessorySourceView, coordinator: ()) {
        view.disconnect()
    }
}

final class ShopAgentDockedAccessorySourceView: UIView {
    weak var navigation: ShopBottomNavigationConversation?
    let contentContainer = ShopAgentInlineAccessoryContainer()
    let presentation = ShopConversationStarterPresentation()
    var isAccessoryVisible = false
    var onHistory: (() -> Void)?

    func setStartersVisible(_ isVisible: Bool) {
        contentContainer.isUserInteractionEnabled = isVisible
        contentContainer.accessibilityElementsHidden = !isVisible
        guard presentation.isVisible != isVisible else { return }
        // The container renders the glass outside each row. Give it the same
        // transaction as the row motion so materialize animates removals too.
        withAnimation(.smooth(duration: 0.30)) {
            presentation.isVisible = isVisible
        }
    }

    func disconnect() {
        guard let navigation, navigation.dockedAccessorySource === self else { return }
        navigation.dockedAccessorySource = nil
        onHistory = nil
        navigation.controller?.updateDockedAccessory()
        self.navigation = nil
    }
}
