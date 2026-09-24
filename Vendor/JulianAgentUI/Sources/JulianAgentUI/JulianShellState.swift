import SwiftUI
import Gravity
import UIKit

/// App-facing data/routing boundary. No layout, keyboard, or dock animation lives here.
@MainActor @Observable
public final class JulianShellState {
    public struct Context: Equatable {
        public let id: String
        public let title: String
        public let imageURL: String?
        public let isProduct: Bool
        public init(id: String, title: String, imageURL: String? = nil, isProduct: Bool = false) {
            self.id = id; self.title = title; self.imageURL = imageURL; self.isProduct = isProduct
        }
    }
    @MainActor @Observable final class Draft {
        let navigation: ShopBottomNavigationConversation
        let model = ShopAgentLandingViewModel()
        var query = ""
        var isFocused = false
        init(detail: Bool) {
            navigation = ShopBottomNavigationConversation(prefersDockedComposer: detail, opensAskPage: !detail)
            model.onFocus = { [weak navigation] in navigation?.isDrafting = true }
        }
    }

    public var context = Context(id: "library", title: "The curated library")
    public var searchQuery = ""
    public var searchActive = false
    /// Host-resolved media contrast shared by source search and UIKit navigation.
    public var prefersDarkChrome = false
    /// Optional destination-owned color beneath the dock's progressive blur.
    public var navigationBackdropColor: Color?
    public var showsSettings = false
    public var showsUtilityBeltControls = false
    public var showsServiceNotice = false
    public var avatar: UIImage?
    public var selectedPage = 0
    public var starterTitles: [String] = []
    public var starterImages: [String] = []
    let starterModel = ShopAskStartersModel()
    public var isConversationPresented = false
    public var conversationTitle = ""
    public var submittedQuery = ""
    public var isAgentStreaming = false
    var navigationStyle = ShopBottomNavigationStyle.pistons
    let cart = ShopCartShellStore()
    let cartAnimation = ShopAddToCartAnimationCoordinator()
    var draft = Draft(detail: false)
    private var drafts: [String: Draft] = [:]
    @ObservationIgnored public var onAccount: () -> Void = {}
    @ObservationIgnored public var onOpenCart: () -> Void = {}
    @ObservationIgnored public var onFavorites: () -> Void = {}
    @ObservationIgnored public var onSelectPage: (Int) -> Void = { _ in }
    /// Service adapters supplied by the host app. The package owns presentation only.
    @ObservationIgnored public var onInitialAgentSubmit: (String, Context) -> Void = { _, _ in }
    @ObservationIgnored public var onAgentFollowUp: (String) -> Void = { _ in }
    @ObservationIgnored public var onStopAgent: () -> Void = {}

    public init() {}

    public func setStarters(titles: [String], images: [String]) {
        starterTitles = titles
        starterImages = images
        starterModel.starters = titles.enumerated().map { index, title in
            ShopAskStarter(id: "library-starter-\(index)", title: title, query: title,
                contextItems: [], images: images.indices.contains(index)
                    ? [.init(url: images[index], altText: title, width: nil, height: nil)] : [], keyColorHex: nil)
        }
    }

    public func activate(_ context: Context) {
        guard self.context != context else { return }
        draft.navigation.closeAskPage()
        drafts[self.context.id] = draft
        self.context = context
        draft = drafts[context.id] ?? Draft(detail: context.id != "library")
        draft.navigation.returnToDraftSource()
        if context.id != "library" {
            draft.model.contextAttachments.items = [.init(id: context.id, type: context.isProduct ? .product : .page,
                                                         title: context.title, imageURL: context.imageURL, screen: context.isProduct ? nil : context.title)]
        }
    }

    public func openAsk(prompt: String? = nil) {
        if let prompt { draft.query = prompt }
        draft.navigation.isAskPagePresented = true
        draft.isFocused = true
        draft.navigation.showNavigationMode(.composer)
    }

    public func closeConversation() {
        if isAgentStreaming { onStopAgent() }
        isAgentStreaming = false
        isConversationPresented = false
        draft.navigation.returnToDraftSource()
    }

    func submit() {
        let query = draft.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !isAgentStreaming else { return }
        submittedQuery = query
        draft.query = ""
        draft.isFocused = false
        if isConversationPresented {
            onAgentFollowUp(query)
            return
        }
        conversationTitle = context.title
        draft.navigation.isDrafting = false
        draft.navigation.isAskPagePresented = false
        onInitialAgentSubmit(query, context)
        draft.navigation.isPresented = true
        isConversationPresented = true
    }
}

@MainActor @Observable
final class ShopAgentLandingViewModel {
    @Observable final class Attachments { var items: [ShopAgentMessageContextItem] = [] }
    let contextAttachments = Attachments()
    var activeContextSummary: String? { shopAgentMessageContextSummary(for: contextAttachments.items) }
    var imageAttachments: [ShopAgentImageAttachment] = []
    var canSubmit = false
    var isThreadsPanelOpen = false
    var onFocus: () -> Void = {}
    func handleInputFocus() { onFocus() }
    func clearActiveContextItems() { contextAttachments.items = [] }
}
@MainActor @Observable final class ShopAskStartersModel { var starters: [ShopAskStarter] = [] }

// The account action and avatar data come from the host, not production session/auth stores.
struct ShopSearchToolbarAccountButton: View {
    @Environment(JulianShellState.self) private var state
    var body: some View {
        Button(action: state.onAccount) {
            ShopAvatar(name: "Luke", size: .s, placeholderIcon: .navigationProfileFilled, fallbackStyle: .buyer) {
                if let avatar = state.avatar {
                    Image(uiImage: avatar).resizable().scaledToFill().frame(width: 32, height: 32)
                }
            }.frame(width: 32, height: 32)
        }
        .accessibilityLabel(localizedString("MainNavigationTabs.Account"))
        .accessibilityIdentifier("search-toolbar-avatar")
        .transition(.blurReplace)
    }
}

@MainActor final class ShopFeedQuickLinkActions: Sendable {
    let onSearch: () -> Void
    init(onSearch: @escaping () -> Void) { self.onSearch = onSearch }
    func search() { onSearch() }
}
