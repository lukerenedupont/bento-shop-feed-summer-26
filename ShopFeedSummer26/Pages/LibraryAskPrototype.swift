import SwiftUI

struct LibraryAskPrototype: View {
    @Bindable var thread: LibraryAskThread
    let onSelect: (ShopCanvasLibrary.Product) -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(thread.context.title)
                            .font(.title2.weight(.semibold))
                            .accessibilityIdentifier("library.ask.context")
                        Text("Demo · On-device catalog only")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Explore the pieces and shops here. Live Agent answers aren’t connected.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(thread.exchanges) { exchange in
                        VStack(alignment: .leading, spacing: 20) {
                            Text(exchange.question)
                                .padding(14)
                                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            Text(exchange.answer).font(.body)
                            if !exchange.products.isEmpty {
                                LibraryCatalogGrid(products: exchange.products, onSelect: onSelect)
                            }
                        }
                        .id(exchange.id)
                    }
                    if thread.exchanges.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(thread.starters, id: \.self) { starter in
                                Button {
                                    thread.send(starter)
                                    isFocused = false
                                } label: {
                                    Text(starter).font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16).padding(.vertical, 14)
                                        .background(Color.black.opacity(0.05), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Color.clear.frame(height: 1).id("conversation-end")
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: thread.exchanges.count) { _, _ in
                proxy.scrollTo("conversation-end", anchor: .bottom)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about this selection", text: $thread.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($isFocused)
                    .padding(.vertical, 12).padding(.leading, 16)
                    .accessibilityIdentifier("library.ask.input")
                Button {
                    thread.send()
                    isFocused = false
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black, in: Circle())
                }
                .disabled(thread.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send")
                .accessibilityIdentifier("library.ask.send")
                .padding(4)
            }
            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.background)
        }
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The root owns presentation, so dismissing a sheet cannot erase its draft or search query.
struct LibraryShellPresentation: ViewModifier {
    @Bindable var session: LibraryShellSession
    let onOpen: (HomeRoute) -> Void

    func body(content: Content) -> some View {
        content.sheet(item: $session.surface, onDismiss: {
            guard let route = session.pendingRoute else { return }
            session.pendingRoute = nil
            onOpen(route)
        }) { surface in
            NavigationStack {
                Group {
                    switch surface {
                    case .search:
                        LibrarySearchPrototype(session: session, onSelect: session.open)
                    case .ask(let context):
                        LibraryAskPrototype(thread: session.thread(for: context), onSelect: session.open)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { session.surface = nil }
                            .accessibilityIdentifier("library.sheet.done")
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.light)
        }
    }
}
