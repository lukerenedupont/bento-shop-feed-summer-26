import Gravity
import SwiftUI

/// Retained by the UIKit accessory host so closing a draft can animate its
/// existing rows out, rather than removing the accessory hierarchy immediately.
@MainActor @Observable
final class ShopConversationStarterPresentation {
    var isVisible = false
    private(set) var orderedIDs: [String] = []
    @ObservationIgnored private var starterIDs: [String] = []
    @ObservationIgnored private var isDraftPresented = false

    func updateDraft(isPresented: Bool) {
        guard isDraftPresented != isPresented else { return }
        isDraftPresented = isPresented
        if isPresented { shuffle() }
    }

    func updateStarters(ids: [String]) {
        guard starterIDs != ids else { return }
        starterIDs = ids
        shuffle()
    }

    func orderedItems<Item: Identifiable>(_ items: [Item], maximumCount: Int?) -> [Item] where Item.ID == String {
        let itemsByID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // UIKit measures the accessory before SwiftUI's initial onChange runs.
        // Reserve the rows' height on that first pass, before they unfurl.
        let ids = orderedIDs.isEmpty ? items.map(\.id) : orderedIDs
        return ids.prefix(maximumCount ?? ids.count).compactMap { itemsByID[$0] }
    }

    private func shuffle() {
        var shuffled = starterIDs.shuffled()
        // A fresh opening should visibly change the order when possible.
        if shuffled.count > 1, shuffled == orderedIDs {
            let first = shuffled.removeFirst()
            shuffled.append(first)
        }
        orderedIDs = shuffled
    }
}

extension EnvironmentValues {
    @Entry var shopConversationStarterPresentation: ShopConversationStarterPresentation?
}

/// Personalized and contextual drafts share the same bottom-first unfurl.
/// Outside a draft accessory, this is an ordinary, always-visible stack.
struct ShopConversationStarterStack<Item: Identifiable, Row: View>: View where Item.ID == String {
    let items: [Item]
    var isReady = true
    var maximumDraftCount: Int? = nil
    @ViewBuilder let row: (Item) -> Row
    @Environment(\.shopConversationStarterPresentation) private var presentation
    @Namespace private var coordinateSpace

    var body: some View {
        let displayedItems = presentation?.orderedItems(items, maximumCount: maximumDraftCount) ?? items
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                row(item)
                    .modifier(ShopConversationStarterUnfurl(
                        index: index, count: displayedItems.count, coordinateSpace: coordinateSpace, isReady: isReady
                    ))
                    .zIndex(Double(index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .coordinateSpace(name: coordinateSpace)
        .onChange(of: items.map(\.id), initial: true) { _, ids in
            presentation?.updateStarters(ids: ids)
        }
    }
}

private struct ShopConversationStarterUnfurl: ViewModifier {
    let index: Int
    let count: Int
    let coordinateSpace: Namespace.ID
    let isReady: Bool
    @Environment(\.shopConversationStarterPresentation) private var presentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isMounted = false

    func body(content: Content) -> some View {
        let isVisible = isReady && (presentation.map { isMounted && $0.isVisible } ?? true)
        let reducesMotion = reduceMotion
        // Reverse the stagger on exit: the top row folds away first.
        let delay = Double(isVisible ? count - 1 - index : index) * 0.035
        let animation: Animation = reducesMotion
            ? .easeOut(duration: 0.15)
            : .smooth(duration: 0.30, extraBounce: 0).delay(delay)

        content
            .environment(\.shopConversationStarterIsVisible, isVisible)
            .visualEffect { effect, geometry in
                // Stack bounds are expressed in this row's coordinates. Every
                // row starts just under the composer's top edge, regardless of
                // text size or row count. UIKit moves the whole stack with it.
                let tuckedOffset = (geometry.bounds(of: .named(coordinateSpace))?.maxY ?? geometry.size.height)
                    + GravitySpacing.space12
                return effect
                    .offset(y: isVisible || reducesMotion ? 0 : tuckedOffset)
            }
            .animation(animation, value: isVisible)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .onAppear {
                withAnimation(animation) { isMounted = true }
            }
    }
}
