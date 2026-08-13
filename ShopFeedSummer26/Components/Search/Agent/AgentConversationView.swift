import SwiftUI

/// A single conversation turn — user query + assistant response.
struct ConversationTurn: Identifiable {
    let id = UUID()
    let query: String
    var blocks: [AgentStreamClient.ContentBlock] = []
    var quickSearchSection: AgentProductSection? = nil
    var suggestions: [SuggestionItem] = []
    var isStreaming: Bool = true
    var showContent: Bool = false
    var revealedBlockCount: Int = 0
    var error: String? = nil
    var isFromHistory: Bool = false
}

/// Agent conversation view with multi-turn support.
/// Each follow-up creates a new turn, visually separated by the user's query as a chapter header.
struct AgentConversationView: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let query: String
    var existingConversationId: String? = nil
    var onDismiss: () -> Void = {}

    @State private var agentClient = AgentStreamClient()
    @State private var searchCount = SearchResultCount()
    @State private var turns: [ConversationTurn] = []
    @State private var followUpText: String = ""
    @State private var thinkingText = "Looking at all the options"
    @State private var loadingTask: Task<Void, Never>?
    @State private var scrollTarget: UUID?
    @State private var isLoadingHistory: Bool = false
    @State private var selectedProduct: AgentProduct?
    @State private var showSearchResults: Bool = false
    @Namespace private var productNamespace

    private var isNavigatedDeep: Bool {
        selectedProduct != nil || showSearchResults
    }
    @FocusState private var followUpFocused: Bool

    private var currentTurnIndex: Int { turns.count - 1 }
    private var currentTurn: ConversationTurn? { turns.last }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                ZStack(alignment: .bottom) {
                    if isLoadingHistory {
                        VStack(spacing: GravitySpacing.space12) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading conversation…")
                                .gravityTextStyle(GravityTypography.bodySmall)
                                .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:foregroundStyle:_:57:50", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                    } else {
                        scrollContent
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isLoadingHistory)
                .overlay(alignment: .topTrailing) { newConversationButton }
                .overlay(alignment: .top) { topFadeGradient }
                .background(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:background:_:70:29", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
                .navigationDestination(item: $selectedProduct) { product in
                    ProductPage(
                        agentProduct: product,
                        reason: agentClient.productReasons[product.id],
                        namespace: productNamespace
                    )
                }
                .navigationDestination(isPresented: $showSearchResults) {
                    if let section = turns.first?.quickSearchSection {
                        SearchResultsPage(
                            products: section.products,
                            namespace: productNamespace
                        )
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }

            // Follow-up bar floats above everything
            followUpBar
                .zIndex(10)
        }
        .ignoresSafeArea(.keyboard)
        .task { await startConversation(query: query) }
        .onDisappear { cleanup() }
        .onChange(of: agentClient.isStreaming) { _, isStreaming in
            guard !isStreaming, !turns.isEmpty else { return }
            // Streaming ended — snapshot final state into the current turn
            finalizeTurn()
        }
        .onChange(of: agentClient.contentBlocks.count) { _, _ in
            syncCurrentTurn()
        }
        .onChange(of: agentClient.productSections.count) { _, _ in
            syncCurrentTurn()
        }
        .onChange(of: agentClient.suggestions) { _, _ in
            syncCurrentTurn()
        }
    }

    // MARK: - Scroll Content

    private var scrollContent: some View {
        ScrollViewReader { proxy in
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(turns.enumerated()), id: \.element.id) { index, turn in
                            turnView(turn: turn, index: index)
                                .id(turn.id)
                        }

                        // Only add scroll space when there are follow-up turns
                        if turns.count > 1 {
                            Spacer()
                                .frame(height: geo.size.height)
                        }
                    }
                    .padding(.top, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:130:36", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                    .padding(.bottom, PurlTune.value("Components/Search/Agent/AgentConversationView.swift:padding:_:131:39", default: 120))
                }
            }
            .onTapGesture { followUpFocused = false }
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:137:49", default: 0.5), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:137:174", default: 0.85))) {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
    }

    // MARK: - Turn View

    private func turnView(turn: ConversationTurn, index: Int) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space20) {
            // Divider between turns (not on first)
            if index > 0 {
                Divider()
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:foregroundStyle:_:151:38", default: GravityColors.border, options: GravityColors.purlTuneColorOptions))
                    .padding(.horizontal, GravitySpacing.screenMargin)
                    .padding(.vertical, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:153:41", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            }

            // Chapter title (user query)
            Text(turn.query)
                .gravityTextStyle(GravityTypography.headerExtraBold)
                .tracking(-1)
                .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:foregroundStyle:_:160:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:162:37", default: GravitySpacing.space48, options: GravitySpacing.purlTuneOptions))
                .padding(.horizontal, GravitySpacing.screenMargin)

            // Quick search card (first turn only)
            if index == 0, let section = turn.quickSearchSection {
                QuickSearchCard(agentSection: section, totalCount: searchCount.totalCount, onViewMore: {
                    showSearchResults = true
                }, onProductTap: { product in
                    selectedProduct = product
                })
                .transition(.offset(y: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:offset:y:172:40", default: 12)).combined(with: .opacity))
            }

            // Work preview (shows while streaming, before content reveals)
            if turn.isStreaming && !turn.showContent {
                AgentWorkPreview(steps: agentClient.workSteps, thinkingText: thinkingText)
                    .padding(.horizontal, GravitySpacing.screenMargin)
                    .transition(.opacity)
            }

            // Content blocks (staggered reveal)
            if turn.showContent {
                turnContentBlocks(turn: turn, turnIndex: index)

                // Suggestions + meta (after all blocks revealed)
                if turn.revealedBlockCount >= filteredBlocks(for: turn).count {
                    if !turn.suggestions.isEmpty && !turn.isStreaming {
                        AgentSuggestionChips(
                            suggestions: turn.suggestions,
                            onTap: { suggestion in
                                Task { await sendFollowUp(query: suggestion) }
                            }
                        )
                        .padding(.horizontal, GravitySpacing.screenMargin)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    if !turn.isStreaming && !filteredBlocks(for: turn).isEmpty {
                        AgentMetaRow()
                            .padding(.horizontal, GravitySpacing.screenMargin)
                            .padding(.top, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:202:44", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                            .transition(.opacity)
                    }
                }
            }

            // Error
            if turn.error != nil {
                errorView(turnIndex: index)
            }
        }
        .animation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:213:38", default: 0.5), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:213:163", default: 0.85)), value: turn.showContent)
        .animation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:214:38", default: 0.5), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:214:163", default: 0.85)), value: turn.quickSearchSection != nil)
    }

    // MARK: - Turn Content Blocks

    private func filteredBlocks(for turn: ConversationTurn) -> [AgentStreamClient.ContentBlock] {
        // Layout: Preamble → Shelves (max 2) → Reasoning text
        var preambleText = ""
        var shelfBlocks: [AgentStreamClient.ContentBlock] = []
        var detailBlocks: [AgentStreamClient.ContentBlock] = []
        var reasoningText = ""
        let maxShelves = 2
        var seenFirstProduct = false

        for block in turn.blocks {
            switch block {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if !seenFirstProduct {
                    if !preambleText.isEmpty { preambleText += " " }
                    preambleText += trimmed
                } else {
                    if !reasoningText.isEmpty { reasoningText += " " }
                    reasoningText += trimmed
                }
            case .products(let section):
                if section.isComparison || (!section.isShelfSection && !section.isQuickSearch) {
                    // Comparison cards or detail cards (ListSection) → recommendations
                    detailBlocks.append(block)
                } else if shelfBlocks.count < maxShelves {
                    shelfBlocks.append(block)
                    seenFirstProduct = true
                }
            }
        }

        // Layout: Preamble → Shelves → Recommendations → Reasoning/Follow-up
        var result: [AgentStreamClient.ContentBlock] = []
        if !preambleText.isEmpty {
            result.append(.text(preambleText))
        }
        result.append(contentsOf: shelfBlocks)
        result.append(contentsOf: detailBlocks)
        if !reasoningText.isEmpty {
            result.append(.text(reasoningText))
        }
        return result
    }

    private func turnContentBlocks(turn: ConversationTurn, turnIndex: Int) -> some View {
        let blocks = filteredBlocks(for: turn)
        return ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
            if index < turn.revealedBlockCount + 1 {
                switch block {
                case .text(let text):
                    if turn.isFromHistory {
                        Text(LocalizedStringKey(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                            .gravityTextStyle(GravityTypography.bodyLarge)
                            .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:foregroundStyle:_:273:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:275:51", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                            .padding(.horizontal, GravitySpacing.screenMargin)
                            .onAppear { revealNextBlock(turnIndex: turnIndex, afterBlock: index) }
                    } else {
                        TypewriterText(
                            fullText: text.trimmingCharacters(in: .whitespacesAndNewlines),
                            onComplete: {
                                revealNextBlock(turnIndex: turnIndex, afterBlock: index)
                            }
                        )
                        .padding(.horizontal, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:285:47", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                        .padding(.horizontal, GravitySpacing.screenMargin)
                    }
                case .products(let section):
                    productSection(section)
                        .transition(.offset(y: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:offset:y:290:48", default: 12)).combined(with: .opacity))
                        .onAppear {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(400))
                                revealNextBlock(turnIndex: turnIndex, afterBlock: index)
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func productSection(_ section: AgentProductSection) -> some View {
        if !section.isShelfSection && section.title == nil {
            // Detail cards — untitled ListSection, render vertically
            VStack(spacing: GravitySpacing.space20) {
                ForEach(section.products) { product in
                    Button {
                        HapticFeedback.light.fire()
                        selectedProduct = product
                    } label: {
                        ProductDetailCard(
                            product: product,
                            reason: agentClient.productReasons[product.id]
                        )
                    }
                    .buttonStyle(PressScaleButtonStyle(scale: 0.98))
                }
            }
            .padding(.horizontal, GravitySpacing.screenMargin)
        } else if section.isComparison && section.title != nil {
            ComparisonShelf(section: section)
        } else {
            AgentProductShelf(section: section, onProductTap: { product in
                selectedProduct = product
            })
        }
    }

    // MARK: - Error View

    private func errorView(turnIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            // Header
            HStack(spacing: GravitySpacing.space8) {
                GravityIcon.exclamationCircle.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:width:339:35", default: 16), height: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:height:339:146", default: 16))
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:foregroundStyle:_:340:38", default: GravityColors.textAgent, options: GravityColors.purlTuneColorOptions))
                
                Text("Couldn\u{2019}t load results right now")
                    .gravityTextStyle(GravityTypography.bodySmall)
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:foregroundStyle:_:344:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
            }

            // Body
            TypewriterText(
                fullText: "Hmm, it looks like that search wasn\u{2019}t completed successfully. Would you like to try again?",
                style: GravityTypography.bodyLarge
            )

            // Try again button
            Button {
                HapticFeedback.light.fire()
                turns[turnIndex].error = nil
                Task { await retryTurn(turnIndex: turnIndex) }
            } label: {
                Text("Try again")
                    .gravityTextStyle(GravityTypography.buttonLarge)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:height:363:36", default: 44))
                    .background(GravityColors.bgFillInverse, in: Capsule())
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.97))
        }
        .padding(.horizontal, GravitySpacing.screenMargin)
        .transition(.opacity)
    }

    // MARK: - Follow-Up Bar

    private var followUpBar: some View {
        FollowUpBar(
            text: $followUpText,
            isFocused: $followUpFocused,
            isNavigatedDeep: isNavigatedDeep,
            onSubmit: { query in
                Task { await sendFollowUp(query: query) }
            },
            onDismiss: onDismiss,
            onBack: {
                withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:384:49", default: 0.35), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:384:175", default: 0.85))) {
                    if selectedProduct != nil {
                        selectedProduct = nil
                    } else if showSearchResults {
                        showSearchResults = false
                    }
                }
            }
        )
    }

    // MARK: - New Conversation Button

    private var newConversationButton: some View {
        HStack {
            Spacer()
            Button {
                HapticFeedback.light.fire()
                onDismiss()
            } label: {
                GravityIcon.editFilled.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:width:407:35", default: 20), height: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:height:407:146", default: 20))
                    .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:foregroundStyle:_:408:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:width:409:35", default: 44), height: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:height:409:146", default: 44))
                    .background(.white.opacity(PurlTune.value("Components/Search/Agent/AgentConversationView.swift:opacity:_:410:48", default: 0.85)), in: Capsule())
                    .glassEffect(.regular)
                    .overlay(
                        Capsule().stroke(GravityColors.borderSecondary, lineWidth: 0.5)
                    )
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.90))
        }
        .padding(.horizontal, GravitySpacing.screenMargin)
        .padding(.top, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:419:24", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        .padding(.bottom, PurlTune.token("Components/Search/Agent/AgentConversationView.swift:padding:_:420:27", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
    }

    // MARK: - Top Fade Gradient

    private var topFadeGradient: some View {
        LinearGradient(
            colors: [GravityColors.bg, GravityColors.bg.opacity(PurlTune.value("Components/Search/Agent/AgentConversationView.swift:opacity:_:427:65", default: 0))],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top)
        .frame(height: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:frame:height:432:24", default: 40))
        .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func startConversation(query: String) async {
        // If resuming an existing conversation, just load past messages
        if let existingId = existingConversationId {
            isLoadingHistory = true
            agentClient.setConversationId(existingId)
            await loadConversationHistory(conversationId: existingId)
            isLoadingHistory = false
            return
        }

        // New conversation
        turns.append(ConversationTurn(query: query))

        var contextParts: [String] = [
            "Keep product shelf section titles to 3-4 words max. No parentheticals. Subtitles should be 6 words or fewer."
        ]
        let lower = query.lowercased()
        if ["compare", "vs", "versus", "difference between", "which is better", "side by side"].contains(where: { lower.contains($0) }) {
            contextParts.append("The user is asking for a comparison. Use <UiTable> to present a structured side-by-side comparison. Keep each row value to 2-3 words max.")
        }
        agentClient.overrides = [
            "context_message": contextParts.joined(separator: " ")
        ]

        searchCount.fetch(query: query)
        startLoadingSequence()
        await agentClient.send(query: query)
    }

    private func sendFollowUp(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        followUpText = ""
        followUpFocused = false

        // Append a new turn
        let newTurn = ConversationTurn(query: trimmed)
        turns.append(newTurn)

        // Scroll to the new turn after layout
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            scrollTarget = newTurn.id
        }

        // Reset loading text
        thinkingText = "Looking at all the options"
        startLoadingSequence()

        await agentClient.sendFollowUp(query: trimmed)
    }

    // MARK: - Sync State

    /// Keep the current turn in sync with the streaming client state.
    private func syncCurrentTurn() {
        guard !turns.isEmpty else { return }
        let idx = currentTurnIndex

        // Update quick search section
        // Quick search = untitled ShelfSection (matches production rule from inferUiSkeletonType)
        if turns[idx].quickSearchSection == nil {
            turns[idx].quickSearchSection = agentClient.productSections.first(where: {
                $0.isQuickSearch || ($0.title == nil && $0.isShelfSection && !$0.isComparison)
            })
        }

        // Snapshot blocks
        turns[idx].blocks = agentClient.contentBlocks.droppingQuickSearch()
        turns[idx].suggestions = agentClient.suggestions
        turns[idx].isStreaming = agentClient.isStreaming
        turns[idx].error = agentClient.error

        // Reveal content once the first text block is fully loaded.
        // A text block is "done" when a product section follows it (meaning the LLM moved on)
        // or when streaming ends (handled in finalizeTurn).
        if !turns[idx].showContent {
            let blocks = turns[idx].blocks
            let hasTextThenProduct = blocks.count >= 2
                && blocks[0].isText
                && !blocks[1].isText
            if hasTextThenProduct {
                withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:521:49", default: 0.5), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:521:174", default: 0.85))) {
                    turns[idx].showContent = true
                }
            }
        }
    }

    /// Called when streaming ends — finalize the turn and reveal content.
    private func finalizeTurn() {
        guard !turns.isEmpty else { return }
        let idx = currentTurnIndex
        syncCurrentTurn()
        turns[idx].isStreaming = false

        withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:535:41", default: 0.5), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:535:166", default: 0.85))) {
            turns[idx].showContent = true
        }
    }

    private func revealNextBlock(turnIndex: Int, afterBlock: Int) {
        guard turnIndex < turns.count else { return }
        let next = afterBlock + 1
        if next > turns[turnIndex].revealedBlockCount {
            withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:544:45", default: 0.4), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:544:170", default: 0.85))) {
                turns[turnIndex].revealedBlockCount = next
            }
        }
    }

    private func startLoadingSequence() {
        loadingTask?.cancel()
        loadingTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:555:45", default: 0.4), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:555:170", default: 0.8))) {
                thinkingText = "Searching across stores"
            }

            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:response:561:45", default: 0.4), dampingFraction: PurlTune.value("Components/Search/Agent/AgentConversationView.swift:spring:dampingFraction:561:170", default: 0.8))) {
                thinkingText = "Putting it all together"
            }
        }
    }

    private func retryTurn(turnIndex: Int) async {
        guard turnIndex < turns.count else { return }
        let query = turns[turnIndex].query
        turns[turnIndex].isStreaming = true
        turns[turnIndex].showContent = false
        turns[turnIndex].revealedBlockCount = 0
        thinkingText = "Looking at all the options"
        startLoadingSequence()

        if turnIndex == 0 {
            await agentClient.send(query: query)
        } else {
            await agentClient.sendFollowUp(query: query)
        }
    }

    /// Parse assistant message content into text and product blocks.
    /// Mirrors production's parseContentInOrder: splits on ```adaptive_ui...``` fences.
    private static func parseHistoryContent(_ content: String) -> [AgentStreamClient.ContentBlock] {
        var blocks: [AgentStreamClient.ContentBlock] = []
        var remaining = content

        while let openRange = remaining.range(of: "```adaptive_ui") ?? remaining.range(of: "```json") {
            // Text before this code block
            let textBefore = String(remaining[remaining.startIndex..<openRange.lowerBound])
            let cleanText = Self.cleanMarkdown(textBefore)
            if !cleanText.isEmpty {
                blocks.append(.text(cleanText))
            }

            // Find the closing ```
            let afterOpen = remaining[openRange.upperBound...]
            if let closeRange = afterOpen.range(of: "```") {
                let jsonString = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Try parsing as product section
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let section = AgentProductSection.parse(from: json) {
                    blocks.append(.products(section))
                }

                remaining = String(remaining[closeRange.upperBound...])
            } else {
                // No closing fence found, treat rest as text
                remaining = String(afterOpen)
                break
            }
        }

        // Remaining text
        let cleanRemaining = Self.cleanMarkdown(String(remaining))
        if !cleanRemaining.isEmpty {
            blocks.append(.text(cleanRemaining))
        }

        return blocks
    }

    /// Extract ActionCard suggestions from stored assistant message content.
    private static func parseHistorySuggestions(_ content: String) -> [SuggestionItem] {
        var suggestions: [SuggestionItem] = []
        var remaining = content

        while let openRange = remaining.range(of: "```adaptive_ui") ?? remaining.range(of: "```json") {
            let afterOpen = remaining[openRange.upperBound...]
            if let closeRange = afterOpen.range(of: "```") {
                let jsonString = String(afterOpen[afterOpen.startIndex..<closeRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let items = json["items"] as? [String: Any],
                   let nodes = items["nodes"] as? [[String: Any]] {
                    for node in nodes {
                        if node["__typename"] as? String == "ActionCard",
                           let action = node["action"] as? [String: Any],
                           let label = action["label"] as? String {
                            var fullQuery: String? = nil
                            if let urlString = action["url"] as? String,
                               let components = URLComponents(string: urlString),
                               let queryParam = components.queryItems?.first(where: { $0.name == "query" })?.value {
                                fullQuery = queryParam.replacingOccurrences(of: "+", with: " ")
                            }
                            suggestions.append(SuggestionItem(label: label, query: fullQuery))
                        }
                    }
                }

                remaining = String(remaining[closeRange.upperBound...])
            } else {
                break
            }
        }

        return suggestions
    }

    /// Remove markdown artifacts from text.
    private static func cleanMarkdown(_ text: String) -> String {
        text
            // Remove markdown image links [![alt](url)](url)
            .replacingOccurrences(of: "\\[!\\[[^\\]]*\\]\\([^)]*\\)\\]\\([^)]*\\)", with: "", options: .regularExpression)
            // Convert product links [text](#id) to plain text
            .replacingOccurrences(of: "\\[([^\\]]+)\\]\\(#[^)]+\\)", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Load past conversation messages and render as static turns.
    private func loadConversationHistory(conversationId: String) async {
        guard let authorization = await AgentStreamClient.resolveAuthorization() else { return }

        let body: [String: Any] = [
            "query": "query($id: ID!) { agentConversationMessages(conversationId: $id, first: 50) { messages { nodes { content type } } } }",
            "variables": ["id": conversationId]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: URL(string: "https://server.shop.app/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "X-User-Agent")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[Agent] History fetch HTTP \(status) for conversation \(conversationId)")
            if let raw = String(data: data, encoding: .utf8) {
                print("[Agent] History response: \(raw.prefix(500))")
            }
            guard status == 200 else { return }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let convoMessages = dataObj["agentConversationMessages"] as? [String: Any],
                  let messages = convoMessages["messages"] as? [String: Any],
                  let nodes = messages["nodes"] as? [[String: Any]] else { return }

            // Parse messages into turns: user messages start new turns, assistant messages are content
            var parsedTurns: [ConversationTurn] = []
            var currentTurn: ConversationTurn?

            for node in nodes {
                let type = node["type"] as? String ?? ""
                let content = node["content"] as? String ?? ""

                if type == "USER_MESSAGE" {
                    // Save previous turn
                    if let turn = currentTurn {
                        parsedTurns.append(turn)
                    }
                    currentTurn = ConversationTurn(query: content)
                    currentTurn?.isStreaming = false
                    currentTurn?.showContent = true
                    currentTurn?.isFromHistory = true
                } else if type == "ASSISTANT_MESSAGE", currentTurn != nil {
                    // Parse content in order: text segments and adaptive_ui product blocks
                    let parsed = Self.parseHistoryContent(content)
                    for block in parsed {
                        currentTurn?.blocks.append(block)
                        // Extract product reasons from descriptors
                        if case .products(let section) = block {
                            for product in section.products where !product.descriptors.isEmpty {
                                let reason = product.descriptors.map(\.value).joined(separator: "\n")
                                agentClient.productReasons[product.id] = reason
                            }
                        }
                    }
                    let count = currentTurn?.blocks.count ?? 0
                    currentTurn?.revealedBlockCount = count

                    // Extract ActionCard suggestions from adaptive_ui blocks
                    let suggestions = Self.parseHistorySuggestions(content)
                    if !suggestions.isEmpty {
                        currentTurn?.suggestions = suggestions
                    }
                }
            }

            // Append last turn
            if let turn = currentTurn {
                parsedTurns.append(turn)
            }

            // Replace the placeholder first turn with parsed history
            if !parsedTurns.isEmpty {
                turns = parsedTurns
            }
        } catch {
            print("[Agent] Failed to load conversation history: \(error)")
        }
    }

    private func cleanup() {
        loadingTask?.cancel()
        agentClient.cancel()
    }
}

#Preview {
    // Pure UI preview — the AgentStreamClient won't actually stream without a
    // network session, so the conversation will sit on its initial "thinking"
    // state. Useful for tweaking layout, loading visuals, and the input bar.
    AgentConversationView(query: "Best hiking boots for snow")
        .background(PurlTune.token("Components/Search/Agent/AgentConversationView.swift:background:_:775:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
