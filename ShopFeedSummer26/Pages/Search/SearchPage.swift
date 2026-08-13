import SwiftUI

struct SearchPage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    @Namespace private var heroNamespace
    @State private var query: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    @State private var historyClient = ConversationHistoryClient.shared
    @State private var searchClient = ShopSearchClient()
    @State private var startersClient = ConversationStartersClient.shared
    @State private var showRecents: Bool = false
    @State private var activeConversation: ActiveConversation?

    private let fallbackPrompts: [String] = [
        "Suggest a gift for Mother's Day",
        "Where is my order?",
        "Hiking boots under $100",
    ]

    private var suggestedPrompts: [String] {
        startersClient.starters.isEmpty ? fallbackPrompts : startersClient.starters
    }

    private var composerBottomPadding: CGFloat {
        if keyboardHeight > 0 {
            return max(keyboardHeight - 34, 0) + GravitySpacing.space12
        }
        return 64
    }

    /// How far the search view slides right to reveal recents
    private var searchOffset: CGFloat {
        showRecents ? UIScreen.main.bounds.width * 0.85 : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Recents (always underneath)
                RecentsPanel(
                    conversations: historyClient.conversations,
                    isLoading: historyClient.isLoading,
                    isVisible: showRecents,
                    onSelect: { conversation in
                        withAnimation(.spring(response: PurlTune.value("Pages/Search/SearchPage.swift:spring:response:47:57", default: 0.35), dampingFraction: PurlTune.value("Pages/Search/SearchPage.swift:spring:dampingFraction:47:160", default: 0.9))) {
                            showRecents = false
                        }
                        // Resume existing conversation
                        activeConversation = ActiveConversation(
                            query: conversation.title ?? "Continue conversation",
                            existingConversationId: conversation.id
                        )
                    },
                    onClose: {
                        withAnimation(.spring(response: PurlTune.value("Pages/Search/SearchPage.swift:spring:response:57:57", default: 0.35), dampingFraction: PurlTune.value("Pages/Search/SearchPage.swift:spring:dampingFraction:57:160", default: 0.9))) {
                            showRecents = false
                        }
                    }
                )
                .opacity(showRecents ? 1.0 : 0.96)
                .animation(.spring(response: PurlTune.value("Pages/Search/SearchPage.swift:spring:response:63:46", default: 0.4), dampingFraction: PurlTune.value("Pages/Search/SearchPage.swift:spring:dampingFraction:63:148", default: 0.85)), value: showRecents)

                // Layer 2: Search view (slides right to reveal recents)
                searchView(geometry: geometry)
                    .mask {
                        UnevenRoundedRectangle(
                            topLeadingRadius: showRecents ? 62 : 0,
                            bottomLeadingRadius: showRecents ? 62 : 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .ignoresSafeArea()
                    }
                    .overlay {
                        Color.white.opacity(showRecents ? 0.75 : 0)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: showRecents ? 62 : 0,
                                    bottomLeadingRadius: showRecents ? 62 : 0,
                                    bottomTrailingRadius: 0,
                                    topTrailingRadius: 0
                                )
                            )
                            .ignoresSafeArea()
                            .allowsHitTesting(showRecents)
                            .onTapGesture {
                                withAnimation(.spring(response: PurlTune.value("Pages/Search/SearchPage.swift:spring:response:89:65", default: 0.35), dampingFraction: PurlTune.value("Pages/Search/SearchPage.swift:spring:dampingFraction:89:168", default: 0.9))) {
                                    showRecents = false
                                }
                            }
                    }
                    .shadow(color: .black.opacity(showRecents ? 0.08 : 0), radius: PurlTune.value("Pages/Search/SearchPage.swift:shadow:radius:94:84", default: 20), x: PurlTune.value("Pages/Search/SearchPage.swift:shadow:x:94:169", default: -10), y: PurlTune.value("Pages/Search/SearchPage.swift:shadow:y:94:251", default: 0))
                    .offset(x: searchOffset)
                    .animation(.spring(response: PurlTune.value("Pages/Search/SearchPage.swift:spring:response:96:50", default: 0.4), dampingFraction: PurlTune.value("Pages/Search/SearchPage.swift:spring:dampingFraction:96:152", default: 0.85)), value: showRecents)
            }
        }
        .ignoresSafeArea(.keyboard)
        .purlInjectable()
    }

    // MARK: - Search View

    @ViewBuilder
    private func searchView(geometry: GeometryProxy) -> some View {
        ZStack(alignment: .top) {
            // Background — mesh gradient
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
                ],
                colors: [
                    .white, .white, .white,
                    Color(red: 0.95, green: 0.91, blue: 0.96), Color(red: 0.96, green: 0.93, blue: 0.98), Color(red: 0.94, green: 0.90, blue: 0.96),
                    Color(red: 0.95, green: 0.82, blue: 0.86), Color(red: 0.92, green: 0.78, blue: 0.84), Color(red: 0.96, green: 0.84, blue: 0.88),
                ]
            )
            .background(PurlTune.token("Pages/Search/SearchPage.swift:background:_:122:25", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
            .ignoresSafeArea()

            // Typeahead results — scrolls under the header
            TypeaheadResultsView(
                query: query,
                results: searchClient.results,
                isLoading: searchClient.isLoading,
                onSelect: { text in
                    launchConversation(query: text)
                },
                onShopSelect: { shop in
                    // Navigate to merchant store page
                    if let merchant = Self.merchant(for: shop) {
                        coordinator.pushRoute(.store(merchantId: merchant.id))
                    } else {
                        // Fallback: launch conversation with shop name
                        launchConversation(query: shop.name)
                    }
                },
                transitionNamespace: heroNamespace,
                merchantIdFor: { shop in Self.merchant(for: shop)?.id }
            )

            // Top fade scrim — content fades under header
            VStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: PurlTune.value("Pages/Search/SearchPage.swift:frame:height:161:36", default: 70))
                    .allowsHitTesting(false)
                Spacer()
            }
            .ignoresSafeArea()

            // Header + headline — floats above content on z-index
            VStack(alignment: .leading, spacing: 0) {
                SearchHeader(
                    query: query,
                    isInputFocused: isInputFocused,
                    onHistory: {
                        isInputFocused = false
                        Task { await historyClient.fetch() }
                        withAnimation(.spring(response: PurlTune.value("Pages/Search/SearchPage.swift:spring:response:175:57", default: 0.4), dampingFraction: PurlTune.value("Pages/Search/SearchPage.swift:spring:dampingFraction:175:160", default: 0.85))) {
                            showRecents = true
                        }
                    },
                    onClose: {
                        isInputFocused = false
                        query = ""
                    }
                )

                if query.isEmpty {
                    VStack(alignment: .leading, spacing: -4) {
                        Text("What are you")
                        Text("shopping for?")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(GravityTypography.posterXS.swiftUIFont)
                    .tracking(GravityLetterSpacing.tighter)
                    .foregroundStyle(PurlTune.token("Pages/Search/SearchPage.swift:foregroundStyle:_:193:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .padding(.horizontal, PurlTune.token("Pages/Search/SearchPage.swift:padding:_:194:43", default: GravitySpacing.space20, options: GravitySpacing.purlTuneOptions))
                    .padding(.top, PurlTune.token("Pages/Search/SearchPage.swift:padding:_:195:36", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                }

                Spacer()
            }

            // Composer + suggestions
            VStack(spacing: 0) {
                Spacer()
                ComposerBar(
                    text: $query,
                    isFocused: $isInputFocused,
                    suggestions: suggestedPrompts,
                    onSuggestionTap: { prompt in
                        launchConversation(query: prompt)
                    },
                    onSubmit: {
                        launchConversation(query: query)
                    }
                )
                .padding(.horizontal, GravitySpacing.screenMargin)
                .padding(.bottom, composerBottomPadding)
                .animation(.spring(response: PurlTune.value("Pages/Search/SearchPage.swift:spring:response:217:46", default: 0.35), dampingFraction: PurlTune.value("Pages/Search/SearchPage.swift:spring:dampingFraction:217:150", default: 1)), value: composerBottomPadding)
            }
            .ignoresSafeArea(.keyboard)
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            let anim = KeyboardAnimation.animation(from: notification)
            withAnimation(anim) {
                keyboardHeight = KeyboardAnimation.endHeight(from: notification)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            let anim = KeyboardAnimation.animation(from: notification)
            withAnimation(anim) {
                keyboardHeight = 0
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { coordinator.showNavBarBlur = false }
        .onDisappear { coordinator.showNavBarBlur = true }
        .onChange(of: query) { _, newValue in
            searchClient.search(query: newValue)
        }
        .fullScreenCover(item: $activeConversation) { convo in
            AgentConversationView(
                query: convo.query,
                existingConversationId: convo.existingConversationId,
                onDismiss: {
                    activeConversation = nil
                }
            )
            .background(PurlTune.token("Pages/Search/SearchPage.swift:background:_:264:25", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        }
    }

    // MARK: - Helpers

    /// Look up the local SampleMerchant matching a typeahead shop result by name.
    /// Used both for navigation and to anchor the zoom transition source.
    private static func merchant(for shop: SearchSuggestion.ShopResult) -> SampleMerchant? {
        SampleMerchant.all.first { $0.name.lowercased() == shop.name.lowercased() }
    }

    // MARK: - Launch Conversation

    private func launchConversation(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isInputFocused = false
        self.query = ""
        searchClient.clear()
        activeConversation = ActiveConversation(query: trimmed)
    }
}

/// Tracks the active conversation for the full-screen cover.
struct ActiveConversation: Identifiable {
    let id: String  // used as Identifiable id
    let query: String
    let existingConversationId: String?

    init(query: String, existingConversationId: String? = nil) {
        self.id = query + (existingConversationId ?? "")
        self.query = query
        self.existingConversationId = existingConversationId
    }
}

#Preview {
    SearchPage()
        .environment(NavigationCoordinator())
}
