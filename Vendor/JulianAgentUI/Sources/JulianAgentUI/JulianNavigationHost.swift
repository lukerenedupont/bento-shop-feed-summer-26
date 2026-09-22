import SwiftUI
import Gravity
import UIKit

/// Binds the library's routing/data to the original persistent UIKit owner.
public struct JulianNavigationHost: View {
    @Bindable var state: JulianShellState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(ShopHomeSearchLayout.storageKey) private var searchLayout = ShopHomeSearchLayout.full
    @AppStorage("library.julian.navigation-style") private var storedStyle = "pistons"

    public init(state: JulianShellState) { self.state = state }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                ShopBottomNavigation(
                    navigationStyle: state.navigationStyle,
                    selectedTab: selectedTab,
                    tabs: ShopRootTab.visibleTabs(isNativeAgentEnabled: true).filter { $0 != .aiSearch },
                    isNativeAgentEnabled: true,
                    usesSearchIconForExplore: searchLayout.usesSearchIconForExplore,
                    cartStore: state.cart,
                    addToCartAnimationCoordinator: state.cartAnimation,
                    cartAnimations: state.cartAnimation.activeAnimations,
                    cartButtonBounceTrigger: state.cartAnimation.cartButtonBounceTrigger,
                    bottomInset: geometry.safeAreaInsets.bottom,
                    backdropColor: colorScheme == .dark ? .black : .white,
                    onTabPressed: { tab in
                        state.draft.navigation.closeAskPage()
                        state.closeConversation()
                        state.onSelectPage(tab == .home ? 0 : tab == .orders ? 1 : 3)
                    },
                    onOpenCart: state.onOpenCart,
                    onNavigationStyleLongPressed: { state.showsSettings = true },
                    conversation: state.draft.navigation,
                    usesChatTabSwap: true
                )
                .ignoresSafeArea()

                ShopAgentLandingDockSource(
                    viewModel: state.draft.model,
                    query: queryBinding,
                    isFocused: focusBinding,
                    navigation: state.draft.navigation,
                    starters: state.starterModel,
                    contextualStarters: state.context.id == "library" ? [] : ShopProductConversationStarter.serverStarters(state.starterTitles),
                    maximumDraftStarterCount: state.context.isProduct ? 3 : nil,
                    isActive: !state.isConversationPresented,
                    onAddContext: { _ in state.showsServiceNotice = true },
                    onRemoveImageAttachment: { _ in },
                    onSubmit: state.submit,
                    onStarter: { starter in state.draft.query = starter.query; state.submit() },
                    onContextualStarter: { text in state.draft.query = text; state.submit() },
                    onHistory: { state.showsServiceNotice = true }
                )
                if state.isConversationPresented {
                    ShopAgentUIKitComposer(
                        query: queryBinding,
                        isComposing: focusBinding,
                        context: ShopAgentUIKitComposerContext(contextItems: state.draft.model.contextAttachments.items),
                        imageAttachments: [],
                        canSubmit: !state.draft.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !state.isAgentStreaming,
                        isStreaming: state.isAgentStreaming,
                        showsBackButton: true, restingBottomInset: 0, bottomSpacing: 0,
                        preservesNavigationBackTapRegion: false,
                        onOpen: {}, onDismiss: { state.draft.isFocused = false },
                        onBack: state.closeConversation, onClose: state.closeConversation,
                        onAddContext: { _ in state.showsServiceNotice = true },
                        onRemoveImageAttachment: { _ in }, onSubmit: state.submit, onStop: state.onStopAgent
                    ).hosted(in: state.draft.navigation)
                }
            }
        }
        .environment(state)
        .ignoresSafeArea(.keyboard)
        .onChange(of: state.draft.query, initial: true) { _, query in
            state.draft.model.canSubmit = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onChange(of: state.draft.navigation.isDraftPresented) { _, presented in
            if presented { state.searchActive = false }
        }
        // Persist at the owner, including Reset while the picker row is offscreen.
        .onChange(of: state.navigationStyle) { _, style in
            storedStyle = style == .rodeo ? "rodeo" : "pistons"
        }
        .onAppear { state.navigationStyle = storedStyle == "rodeo" ? .rodeo : .pistons }
        .sheet(isPresented: $state.showsSettings) {
            ShopNavigationStylePickerSheet(selectedStyle: $state.navigationStyle) { style in
                storedStyle = style == .rodeo ? "rodeo" : "pistons"
            }
            .presentationDetents([.large])
        }
        .alert("Live Agent connection required", isPresented: $state.showsServiceNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This catalog app isn’t connected to Shop’s conversation history or attachment services. No request has been sent.")
        }
    }

    // The UIKit owner may configure between SwiftUI renders. Read live draft values,
    // not a projected binding's render snapshot; capture the draft to isolate route handoffs.
    private var queryBinding: Binding<String> {
        let draft = state.draft
        return Binding(get: { draft.query }, set: { draft.query = $0 })
    }

    private var focusBinding: Binding<Bool> {
        let draft = state.draft
        return Binding(get: { draft.isFocused }, set: { draft.isFocused = $0 })
    }

    private var selectedTab: ShopRootTab {
        state.selectedPage == 1 ? .orders : state.selectedPage == 2 || state.selectedPage == 3 ? .search : .home
    }
}

/// The transcript boundary is explicit until a real Agent transport is connected.
/// The toolbar and follow-up composer are the original components, not demo chat replicas.
public struct JulianConversationSurface<Content: View>: View {
    @Bindable var state: JulianShellState
    private let content: () -> Content
    public init(state: JulianShellState, @ViewBuilder content: @escaping () -> Content) {
        self.state = state
        self.content = content
    }
    public var body: some View {
        NavigationStack {
            content()
                .navigationTitle(state.conversationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ShopAgentConversationToolbar(contextInfo: nil, ratingModalOpen: false, conversationID: nil,
                        showsCopyConversationIDButton: false, onNewThread: state.closeConversation,
                        onCloseRating: {}, onCopyConversationID: { _ in }, onBack: state.closeConversation)
                }
        }
    }
}
