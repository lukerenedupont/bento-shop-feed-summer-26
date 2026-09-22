import SwiftUI
import UIKit

enum ShopBottomNavigationMode: Equatable {
    case tabs
    case composer
}

/// A detail screen lends its conversation state to the existing shell navigation.
/// The shell keeps ownership of its buttons; Back closes the conversation before popping.
@MainActor
@Observable
final class ShopBottomNavigationConversation: Equatable {
    let usesPushedPresentation: Bool
    let prefersDockedComposer: Bool
    let opensAskPage: Bool
    var isAskPagePresented = false {
        didSet {
            if isAskPagePresented {
                navigationMode = .composer
            } else {
                restoreDefaultNavigationModeIfIdle()
            }
        }
    }
    private var isReturningFromPush = false
    private(set) var isReturningComposerFromPush = false
    private(set) var navigationMode: ShopBottomNavigationMode

    init(usesPushedPresentation: Bool = false, prefersDockedComposer: Bool = false, opensAskPage: Bool = false) {
        self.usesPushedPresentation = usesPushedPresentation
        self.prefersDockedComposer = prefersDockedComposer
        self.opensAskPage = opensAskPage
        navigationMode = prefersDockedComposer ? .composer : .tabs
    }

    var isPresented = false {
        didSet {
            if isPresented != oldValue {
                if usesPushedPresentation { isReturningFromPush = !isPresented }
                if isConversationVisible {
                    navigationMode = .composer
                } else {
                    restoreDefaultNavigationModeIfIdle()
                }
            }
        }
    }
    var isDrafting = false {
        didSet {
            if isDrafting {
                navigationMode = .composer
            } else {
                restoreDefaultNavigationModeIfIdle()
            }
        }
    }
    var isConversationVisible: Bool { isPresented || isReturningFromPush }
    var isDraftPresented: Bool { !isConversationVisible && (isDrafting || isAskPagePresented) }
    var showsDockedComposer: Bool { navigationMode == .composer }
    /// The same frosted layer follows the inline composer into the chat container.
    @ObservationIgnored let backdrop = ShopComposerFocusBackdropView()

    // Nonvisual connection to the screen's composer data. Neither endpoint owns the other.
    @ObservationIgnored weak var controller: ShopBottomNavigationViewController?
    @ObservationIgnored weak var composerSource: ShopBottomNavigationComposerSourceView?
    @ObservationIgnored weak var inlineComposerContainer: UIView?
    @ObservationIgnored weak var inlineStartersContainer: ShopAgentInlineAccessoryContainer?
    @ObservationIgnored weak var dockedAccessorySource: ShopAgentDockedAccessorySourceView?

    func showNavigationMode(_ mode: ShopBottomNavigationMode) {
        navigationMode = mode
    }

    /// Detail pages may temporarily reveal the tab bar, but their next page interaction restores
    /// the composer they prefer by default. This only changes the dock presentation; it does not
    /// focus the input, reopen a draft, or summon the keyboard.
    func restorePreferredComposerAfterPageInteraction() {
        guard prefersDockedComposer, navigationMode == .tabs else { return }
        navigationMode = .composer
        controller?.updateComposer(focusOverride: false)
    }

    func closeAskPage() {
        composerSource?.composer?.dismissFocus()
        isDrafting = false
        isAskPagePresented = false
        navigationMode = prefersDockedComposer ? .composer : .tabs
        // The source can still contain the previous SwiftUI focus snapshot until
        // its next update. Clear UIKit's focus intent in the same close action.
        controller?.updateComposer(focusOverride: false)
    }

    /// A retained source regains ownership after its registered chat route pops.
    /// Clear the handoff state before accepting another focus request.
    func returnToDraftSource() {
        isPresented = false
        isReturningFromPush = false
        isReturningComposerFromPush = false
        restoreDefaultNavigationModeIfIdle()
    }

    func resetForSessionChange() {
        closeAskPage()
        returnToDraftSource()
        navigationMode = prefersDockedComposer ? .composer : .tabs
    }

    func beginPushedConversationReturn() {
        guard let composer = controller?.composerController,
              let container = inlineComposerContainer,
              container.window != nil, container.window === composer.view.window else { return }
        isReturningComposerFromPush = true
        composer.beginNavigationInlineReturn()
        controller?.updateComposer()
    }

    func cancelPushedConversationReturn() {
        controller?.composerController?.completeNavigationInlineReturn(cancelled: true)
        isReturningComposerFromPush = false
        controller?.updateComposer()
    }

    func finishPushedConversationReturn() {
        controller?.composerController?.completeNavigationInlineReturn(cancelled: false)
        isPresented = false
        isReturningFromPush = false
        isReturningComposerFromPush = false
        restoreDefaultNavigationModeIfIdle()
        controller?.updateComposer()
    }

    private func restoreDefaultNavigationModeIfIdle() {
        guard !isDrafting, !isAskPagePresented, !isConversationVisible else { return }
        navigationMode = prefersDockedComposer ? .composer : .tabs
    }

    nonisolated static func == (lhs: ShopBottomNavigationConversation, rhs: ShopBottomNavigationConversation) -> Bool {
        lhs === rhs
    }
}

struct ShopBottomNavigationConversationPreferenceKey: PreferenceKey {
    static let defaultValue: ShopBottomNavigationConversation? = nil

    static func reduce(value: inout ShopBottomNavigationConversation?, nextValue: () -> ShopBottomNavigationConversation?) {
        value = nextValue() ?? value
    }
}

extension EnvironmentValues {
    /// Set only by the tab shell, not by separately presented navigation surfaces.
    @Entry var shopHasBottomNavigation = false
    /// Only the active landing input supplies the shell's generic dock; detail inputs
    /// keep their own conversation source and take precedence over this fallback.
    @Entry var shopLandingComposerNavigation: ShopBottomNavigationConversation? = nil
}
