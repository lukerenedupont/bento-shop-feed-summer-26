import Foundation

/// A suggestion chip with a short display label and the full query to send.
struct SuggestionItem: Equatable {
    let label: String
    let query: String

    init(label: String, query: String? = nil) {
        self.label = label
        self.query = query ?? label
    }
}

/// SSE event types from the agent stream.
enum AgentSSEEvent {
    case message(String)
    case quickSearchSDUI(String)  // pre-rendered SDUI shelf from search classifier
    case title(String)
    case suggestions([SuggestionItem])
    case productReason(productId: String, reason: String)
    case recommendations(productIds: [String], labels: [String])
    case toolCall(String)
    case toolResult(String)
    case loader(String)
    case searchQueries([String])
    case end
    case ignored
    case unknown(event: String, data: String)
}

/// Observable client that creates a conversation and streams agent responses via SSE.
@Observable
final class AgentStreamClient {
    // MARK: - Content Block Model

    enum ContentBlock: Identifiable {
        case text(String)
        case products(AgentProductSection)

        var id: String {
            switch self {
            case .text(let s): return "text-\(s.hashValue)"
            case .products(let section): return section.id.uuidString
            }
        }
    }

    // MARK: - Published State

    var messageText: String = ""  // raw running text for streaming display
    var contentBlocks: [ContentBlock] = []  // ordered interleaved content
    var conversationTitle: String = ""
    var suggestions: [SuggestionItem] = []
    var productReasons: [String: String] = [:]  // productId → reason text
    var workSteps: [String] = []
    var productSections: [AgentProductSection] = []
    var isLoadingSection: Bool = false
    var isStreaming: Bool = false
    var error: String?

    private var streamTask: Task<Void, Never>?
    private var conversationId: String?


    // MARK: - Send Message

    /// Creates a conversation (if needed) and streams the agent response.
    @MainActor
    func send(query: String) async {
        reset()
        isStreaming = true

        do {
            // Step 1: Create conversation
            let uuid = try await createConversation()
            conversationId = uuid

            // Step 2: Stream response
            try await streamMessages(conversationId: uuid, content: query)
        } catch {
            self.error = error.localizedDescription
            print("[Agent] Error: \(error)")
        }

        isStreaming = false
    }

    /// Send a follow-up message to the existing conversation.
    @MainActor
    func sendFollowUp(query: String) async {
        guard let id = conversationId else {
            await send(query: query)
            return
        }

        messageText = ""
        contentBlocks = []
        suggestions = []
        productReasons = [:]
        workSteps = []
        productSections = []
        isLoadingSection = false
        error = nil
        isStreaming = true

        do {
            try await streamMessages(conversationId: id, content: query)
        } catch {
            self.error = error.localizedDescription
            print("[Agent] Follow-up error: \(error)")
        }

        isStreaming = false
    }

    func cancel() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    /// Set an existing conversation ID for resuming conversations.
    func setConversationId(_ id: String) {
        conversationId = id
    }

    func reset() {
        cancel()
        messageText = ""
        contentBlocks = []
        conversationTitle = ""
        suggestions = []
        productReasons = [:]
        workSteps = []
        productSections = []
        error = nil
        conversationId = nil
    }

    // MARK: - Create Conversation

    private func createConversation() async throws -> String {
        guard let authorization = await Self.resolveAuthorization() else {
            throw AgentStreamError.noConversation
        }

        let url = URL(string: "https://server.shop.app/graphql")!
        let bodyData = "{\"query\":\"mutation { agentConversationCreate { agentConversation { id } } }\"}".data(using: .utf8)!

        var request = Self.buildRequest(url: url, authorization: authorization)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AgentStreamError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gqlData = json["data"] as? [String: Any],
              let create = gqlData["agentConversationCreate"] as? [String: Any],
              let convo = create["agentConversation"] as? [String: Any],
              let gid = convo["id"] as? String,
              let ulid = gid.components(separatedBy: "/").last else {
            throw AgentStreamError.noConversation
        }

        return ulid
    }

    // MARK: - Stream Messages

    /// Overrides to send with every message (system_prompt, context_message, model, etc.)
    var overrides: [String: Any] = [:]

    /// Mint a signed stream URL via Shop Server GraphQL.
    private func createStreamUrl() async throws -> String {
        guard let authorization = await Self.resolveAuthorization() else {
            throw AgentStreamError.noConversation
        }

        let url = URL(string: "https://server.shop.app/graphql")!
        let bodyData = "{\"query\":\"mutation { agentStreamUrlCreate { streamUrl expiresAt userErrors { message } } }\"}".data(using: .utf8)!

        var request = Self.buildRequest(url: url, authorization: authorization)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AgentStreamError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gqlData = json["data"] as? [String: Any],
              let create = gqlData["agentStreamUrlCreate"] as? [String: Any],
              let streamUrl = create["streamUrl"] as? String else {
            throw AgentStreamError.noConversation
        }

        return streamUrl
    }

    private func streamMessages(conversationId: String, content: String) async throws {
        // Mint a signed stream URL (the old direct path is deprecated)
        let streamUrlString = try await createStreamUrl()
        guard let targetUrl = URL(string: streamUrlString) else {
            throw AgentStreamError.httpError(0)
        }

        let requestId = UUID().uuidString
        var body: [String: Any] = [
            "message": [
                "content": content,
                "conversation_id": conversationId,
                "scenario": "ShopAgent",
                "features": ["shop_agent/default", "shop_agent/platform/mobile"],
                "request_id": requestId,
            ]
        ]

        if !overrides.isEmpty {
            body["config"] = ["overrides": overrides] as [String: Any]
        }

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: targetUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("shop", forHTTPHeaderField: "Shopify-Client-Id")
        request.httpBody = bodyData

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200 else {
            throw AgentStreamError.httpError(status)
        }

        // Parse SSE line by line
        var eventType: String?
        var dataBuffer: String = ""


        for try await line in bytes.lines {
            guard !Task.isCancelled else { break }

            if line.hasPrefix("event:") {
                // Dispatch previous event if we have one buffered
                if let type = eventType, !dataBuffer.isEmpty {
                    let event = parseEvent(type: type, data: dataBuffer)
                    await handleEvent(event)
                    dataBuffer = ""
                }
                eventType = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                // SSE spec: one optional space after "data:"
                var data = String(line.dropFirst(5))
                if data.hasPrefix(" ") { data = String(data.dropFirst()) }
                if !dataBuffer.isEmpty { dataBuffer += "\n" }
                dataBuffer += data
            } else if line.isEmpty {
                // Empty line = end of event
                if let type = eventType {
                    let event = parseEvent(type: type, data: dataBuffer)
                    await handleEvent(event)
                }
                eventType = nil
                dataBuffer = ""
            }
        }

        // Handle any remaining buffered event
        if let type = eventType, !dataBuffer.isEmpty {
            let event = parseEvent(type: type, data: dataBuffer)
            await handleEvent(event)
        }
    }

    // MARK: - Parse SSE Events

    // swiftlint:disable:next cyclomatic_complexity
    private func parseEvent(type: String, data: String) -> AgentSSEEvent {
        switch type {
        case "message":
            return .message(data == "null" ? " " : data)
        case "conversation_title":
            return .title(data)
        case "conversation_suggestions":
            if let jsonData = data.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: jsonData) as? [String] {
                return .suggestions(array.map { SuggestionItem(label: $0) })
            }
            return .suggestions([])
        case "tool_call", "tool_call_start":
            return .toolCall(data)
        case "tool_result":
            return .toolResult(data)
        case "message_loader", "loader_message":
            return .loader(data)
        case "end", "finish_stream":
            return .end
        // Silent events — no action needed
        case "loader_adaptive_ui_message":
            // Parse start/end status for skeleton loading
            if let jsonData = data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let status = json["status"] as? String {
                return .loader(status)
            }
            return .ignored
        case "search:sdui_content":
            // Quick search shelf — pre-rendered SDUI from server classifier
            return .quickSearchSDUI(data)
        case "ui":
            // UI events carry hydrated adaptive_ui JSON or suggestions
            if let jsonData = data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // Check for conversation_suggestions
                if let text = json["text"] as? [String: Any],
                   let items = text["conversation_suggestions"] as? [String] {
                    return .suggestions(items.map { SuggestionItem(label: $0) })
                }
                // Check for adaptive_ui product data in "data" field
                if let innerData = json["data"] as? String, innerData.contains("adaptive_ui") {
                    return .message(innerData)
                }
                // Check for UiReason in "data" field
                if let innerData = json["data"] as? String, innerData.contains("UiReason") {
                    // Parse <UiReason id="..." text="..." />
                    if let idRange = innerData.range(of: "id=\"", options: []),
                       let idEnd = innerData.range(of: "\"", range: idRange.upperBound..<innerData.endIndex),
                       let textRange = innerData.range(of: "text=\"", options: []),
                       let textEnd = innerData.range(of: "\" />", range: textRange.upperBound..<innerData.endIndex) {
                        let productId = String(innerData[idRange.upperBound..<idEnd.lowerBound])
                        let reason = String(innerData[textRange.upperBound..<textEnd.lowerBound])
                            .replacingOccurrences(of: "\\n", with: "\n")
                        return .productReason(productId: productId, reason: reason)
                    }
                }
                // Check for UiRecommendations in "data" field
                if let innerData = json["data"] as? String, innerData.contains("UiRecommendations") {
                    // Parse products={["id1", "id2"]} labels={["label1", "label2"]}
                    let productIds = Self.parseXMLArray(innerData, attribute: "products")
                    let labels = Self.parseXMLArray(innerData, attribute: "labels")
                    if !productIds.isEmpty {
                        return .recommendations(productIds: productIds, labels: labels)
                    }
                }
            }
            return .ignored
        case "product_reason":
            // Parse product reason: { product_id, reason }
            if let jsonData = data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let productId = json["product_id"] as? String,
               let reason = json["reason"] as? String {
                return .productReason(productId: productId, reason: reason)
            }
            return .ignored
        case "preturn_search_ui":
            // Quick search shelf in XML format — skip (hydrated version comes via ui event)
            return .ignored
        case "heartbeat", "debug:trace_id",
             "user_message_id", "assistant_message_id", "search_message_id",
             "preturn_message_id",
             "preturn_merchant_ui",
             "message_content_end":
            return .ignored
        case "preturn_classifier":
            return .ignored
        case "search:queries":
            // Parse search terms from adaptive_ui SearchQueries
            var queries: [String] = []
            // Extract JSON from ```adaptive_ui ... ```
            if let jsonStart = data.range(of: "{")?.lowerBound,
               let jsonEnd = data.range(of: "}", options: .backwards)?.upperBound {
                let jsonStr = String(data[jsonStart..<jsonEnd])
                if let jsonData = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let queryNodes = json["queries"] as? [[String: Any]] {
                    queries = queryNodes.compactMap { $0["query"] as? String }
                }
            }
            if !queries.isEmpty {
                return .searchQueries(queries)
            }
            return .ignored
        default:
            return .unknown(event: type, data: data)
        }
    }

    // MARK: - Handle Events

    @MainActor
    private func handleEvent(_ event: AgentSSEEvent) {
        switch event {
        case .message(let text):
            // Parse adaptive_ui blocks for ActionCards (suggestions)
            if text.contains("```adaptive_ui") {
                parseAdaptiveUI(text)
                return
            }
            // Skip markdown images
            if text.contains("[![") { return }
            // Strip <ui>...</ui> blocks (product shelves rendered separately)
            var cleaned = text
            while let start = cleaned.range(of: "<ui"),
                  let end = cleaned.range(of: "</ui>", range: start.lowerBound..<cleaned.endIndex) {
                cleaned.removeSubrange(start.lowerBound..<end.upperBound)
            }
            // Also strip self-closing <ui .../> single-line tags
            cleaned = cleaned.replacingOccurrences(
                of: "<ui [^>]*/>",
                with: "",
                options: .regularExpression
            )
            // Convert product links [text](#productId=...) to plain text
            cleaned = cleaned.replacingOccurrences(
                of: "\\[([^\\]]+)\\]\\(#[^)]+\\)",
                with: "$1",
                options: .regularExpression
            )
            // Skip if nothing left after stripping
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            messageText += cleaned
            // Update the current text block (last block if it's text, otherwise create new)
            updateCurrentTextBlock()
        case .title(let title):
            conversationTitle = title
        case .quickSearchSDUI(let data):
            parseQuickSearchSDUI(data)
        case .suggestions(let items):
            suggestions = items
        case .productReason(let productId, let reason):
            productReasons[productId] = reason
        case .loader(let data):
            // Handle loader events in multiple formats
            if data == "start" {
                isLoadingSection = true
            } else if data == "end" {
                isLoadingSection = false
            } else if let jsonData = data.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                // New shopkick format: {"message":"...","data":{"name":"tool_name","status":"start"}}
                if let innerData = json["data"] as? [String: Any],
                   let name = innerData["name"] as? String,
                   let status = innerData["status"] as? String {
                    if status == "start" {
                        isLoadingSection = true
                        let step = Self.readableStepName(name)
                        if !workSteps.contains(step) {
                            workSteps.append(step)
                        }
                    } else if status == "end" {
                        isLoadingSection = false
                    }
                }
                // Old format: {"tool_call":{"function":{"name":"..."}}}
                else if let toolCall = json["tool_call"] as? [String: Any],
                        let function = toolCall["function"] as? [String: Any],
                        let name = function["name"] as? String {
                    let step = Self.readableStepName(name)
                    if !workSteps.contains(step) {
                        workSteps.append(step)
                    }
                }
            }
        case .toolCall, .toolResult:
            break
        case .recommendations(let productIds, let labels):
            // Find matching products from already-parsed sections and create a comparison section
            let allProducts = productSections.flatMap { $0.products }
            var matched: [AgentProduct] = []
            for (i, pid) in productIds.enumerated() {
                // Match by ID prefix (shopId part of "shopId:variantId")
                let shopId = pid.components(separatedBy: ":").first ?? pid
                if let product = allProducts.first(where: { $0.id.contains(shopId) }) {
                    let label = i < labels.count ? labels[i] : ""
                    let labeled = AgentProduct(
                        id: product.id,
                        title: product.title,
                        price: product.price,
                        originalPrice: product.originalPrice,
                        imageURL: product.imageURL,
                        allImageURLs: product.allImageURLs,
                        rating: product.rating,
                        ratingCount: product.ratingCount,
                        shopName: product.shopName,
                        shopLogoURL: product.shopLogoURL,
                        descriptors: product.descriptors,
                        labels: label.isEmpty ? product.labels : [label]
                    )
                    matched.append(labeled)
                }
            }
            if !matched.isEmpty {
                let section = AgentProductSection(
                    title: "Top picks",
                    subtitle: nil,
                    products: matched,
                    isComparison: true
                )
                productSections.append(section)
                flushTextBlock()
                contentBlocks.append(.products(section))
            }
        case .searchQueries:
            break // Not used currently
        case .ignored:
            break
        case .end:
            print("[Agent] Stream ended")
        case .unknown(let event, let data):
            print("[Agent] Unknown event '\(event)': \(data.prefix(80))")
        }
    }

    /// Extract ActionCard labels from adaptive_ui JSON blocks as suggestions.
    @MainActor
    private func parseAdaptiveUI(_ text: String) {
        // Extract JSON between ```adaptive_ui and ```
        guard let jsonStart = text.range(of: "```adaptive_ui")?.upperBound,
              let jsonEnd = text.range(of: "```", range: jsonStart..<text.endIndex)?.lowerBound else { return }
        let jsonString = String(text[jsonStart..<jsonEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Check for ActionCard items
        guard let items = json["items"] as? [String: Any],
              let nodes = items["nodes"] as? [[String: Any]] else { return }

        var newSuggestions: [SuggestionItem] = []
        for node in nodes {
            if node["__typename"] as? String == "ActionCard",
               let action = node["action"] as? [String: Any],
               let label = action["label"] as? String {
                // Extract full query from the URL (shopapp://agent?query=...)
                var fullQuery: String? = nil
                if let urlString = action["url"] as? String,
                   let components = URLComponents(string: urlString),
                   let queryParam = components.queryItems?.first(where: { $0.name == "query" })?.value {
                    // URLComponents doesn't decode + as space, handle manually
                    fullQuery = queryParam.replacingOccurrences(of: "+", with: " ")
                }
                newSuggestions.append(SuggestionItem(label: label, query: fullQuery))
            }
        }
        if !newSuggestions.isEmpty {
            suggestions = newSuggestions
            return
        }

        // Parse product sections (ShelfSection / ListSection / Table)
        if let section = AgentProductSection.parse(from: json) {
            productSections.append(section)
            flushTextBlock()
            contentBlocks.append(.products(section))
        }
    }

    /// Parse pre-rendered SDUI JSON from search:sdui_content event (quick search shelf).
    @MainActor
    private func parseQuickSearchSDUI(_ data: String) {
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("[Agent] Failed to parse quick search SDUI")
            return
        }

        if let section = AgentProductSection.parse(from: json) {
            let quickSection = AgentProductSection(
                title: nil,
                subtitle: nil,
                products: section.products,
                isComparison: false,
                isQuickSearch: true
            )
            productSections.insert(quickSection, at: 0)
            contentBlocks.insert(.products(quickSection), at: 0)
        }
    }

    // MARK: - Content Block Helpers

    /// Update or append the current text block with latest messageText
    @MainActor
    private func updateCurrentTextBlock() {
        // Find the index of the last text block that isn't followed by a product block
        // We track text accumulated since the last product section
        let textSinceLastProduct = currentTextSegment()
        guard !textSinceLastProduct.isEmpty else { return }

        if case .text = contentBlocks.last {
            contentBlocks[contentBlocks.count - 1] = .text(textSinceLastProduct)
        } else {
            contentBlocks.append(.text(textSinceLastProduct))
        }
    }

    /// Flush current running text into a finalized text block
    @MainActor
    private func flushTextBlock() {
        let text = currentTextSegment().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // If the last block is already this text, leave it
        if case .text(let existing) = contentBlocks.last, existing == text { return }
        if case .text = contentBlocks.last {
            contentBlocks[contentBlocks.count - 1] = .text(text)
        } else {
            contentBlocks.append(.text(text))
        }
    }

    /// Get the text accumulated since the last product block
    @MainActor
    private func currentTextSegment() -> String {
        // Sum up all text blocks already committed
        var committedTextLength = 0
        for block in contentBlocks {
            if case .text(let t) = block {
                committedTextLength += t.count
            }
        }
        // If last block is text, subtract it (it's the one we're updating)
        if case .text(let last) = contentBlocks.last {
            committedTextLength -= last.count
        }
        // Return everything after committed text, trim leading newlines
        let start = messageText.index(messageText.startIndex, offsetBy: min(committedTextLength, messageText.count))
        return String(messageText[start...]).drop(while: { $0.isNewline }).description
    }
}

// MARK: - Content Block Helpers

extension AgentStreamClient.ContentBlock {
    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

extension Array where Element == AgentStreamClient.ContentBlock {
    /// Drop the quick-search block since it's rendered separately.
    /// Quick search = untitled ShelfSection (production rule) or explicit isQuickSearch flag.
    func droppingQuickSearch() -> [AgentStreamClient.ContentBlock] {
        var droppedOne = false
        return compactMap { block in
            if case .products(let section) = block, !droppedOne {
                if section.isQuickSearch || (section.title == nil && section.isShelfSection && !section.isComparison) {
                    droppedOne = true
                    return nil
                }
            }
            return block
        }
    }
}

// MARK: - XML Parsing Helpers

extension AgentStreamClient {
    /// Parse a JSX-style array attribute like products={["a", "b"]} from XML-ish markup.
    static func parseXMLArray(_ text: String, attribute: String) -> [String] {
        // Look for attribute={["...", "..."]}
        guard let attrRange = text.range(of: "\(attribute)={[") else { return [] }
        let start = attrRange.upperBound
        guard let endBracket = text.range(of: "]}", range: start..<text.endIndex) else { return [] }
        let arrayContent = String(text[start..<endBracket.lowerBound])
        // Extract quoted strings
        var results: [String] = []
        var scanner = arrayContent[...]
        while let quoteStart = scanner.firstIndex(of: "\"") {
            let afterQuote = scanner.index(after: quoteStart)
            guard afterQuote < scanner.endIndex,
                  let quoteEnd = scanner[afterQuote...].firstIndex(of: "\"") else { break }
            results.append(String(scanner[afterQuote..<quoteEnd]))
            scanner = scanner[scanner.index(after: quoteEnd)...]
        }
        return results
    }
}

// MARK: - Step Names

extension AgentStreamClient {
    static func readableStepName(_ functionName: String) -> String {
        switch functionName {
        case "search_global_products": return "Searching for products"
        case "web_search": return "Searching the web"
        case "get_global_product_details": return "Looking up product details"
        case "get_product_shipping_details": return "Checking delivery options"
        case "search_buyer_orders": return "Pulling up your orders"
        case "get_active_shopping_carts": return "Checking your cart"
        case "update_shopping_carts": return "Updating your cart"
        case "extract_memories": return "Saving your preferences"
        case "merchant_contact_info": return "Looking up store info"
        case "search_shop_policies_and_faqs": return "Reading store policies"
        case "create_shop_support_request": return "Creating support ticket"
        default: return functionName.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Errors

enum AgentStreamError: Error, LocalizedError {
    case httpError(Int)
    case noConversation

    var errorDescription: String? {
        switch self {
        case .httpError(let code): "HTTP error \(code)"
        case .noConversation: "No active conversation"
        }
    }
}

// MARK: - Auth Helpers

extension AgentStreamClient {
    /// Resolve a Bearer authorization from the active Shop Account OAuth
    /// session, refreshing the access token if needed.
    static func resolveAuthorization() async -> String? {
        guard await AuthService.shared.hasSession else { return nil }
        return try? await AuthService.shared.getAuthorization()
    }

    private static let installDeviceId = UUID().uuidString
    private static let externalDeviceId = UUID().uuidString
    private static let sessionId = UUID().uuidString

    static func buildRequest(url: URL, authorization: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("shop", forHTTPHeaderField: "Shopify-Client-Id")
        request.setValue("verbose-tracing=true", forHTTPHeaderField: "baggage")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "User-Agent")
        request.setValue("Shop/2.235.0 ios/17.0", forHTTPHeaderField: "X-User-Agent")
        request.setValue(externalDeviceId, forHTTPHeaderField: "X-Device-Id-Hw")
        request.setValue(installDeviceId, forHTTPHeaderField: "X-Device-Id")
        request.setValue(sessionId, forHTTPHeaderField: "Session-Id")
        return request
    }


}
