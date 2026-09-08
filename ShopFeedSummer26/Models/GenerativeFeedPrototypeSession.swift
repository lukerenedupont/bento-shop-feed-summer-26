import SwiftUI

/// Session-only prototype state. Lives above lazy feed cells so scrolling away
/// or opening the room plan doesn't lose selection. Reset never touches real data.
@Observable
final class GenerativeFeedPrototypeSession {
    struct CardState {
        var selectedID: String?
        var removedIDs: Set<String> = []
        var composition: NextGenerationCardLayout?
        var interactionsEnabled = true
        var lastAction = "No interaction yet"
    }
    private var states: [String: CardState] = [:]
    var designMode = ProcessInfo.processInfo.arguments.contains("-feedDesignMode")

    func state(for spec: NextGenerationFeedCardSpec) -> CardState { states[spec.id] ?? CardState() }
    func composition(for spec: NextGenerationFeedCardSpec) -> NextGenerationCardLayout {
        state(for: spec).composition ?? spec.layout
    }
    func selected(in items: [ResolvedStoryProduct], for spec: NextGenerationFeedCardSpec) -> ResolvedStoryProduct? {
        let current = state(for: spec)
        return items.first { $0.id == current.selectedID && !current.removedIDs.contains($0.id) }
            ?? items.first { !current.removedIDs.contains($0.id) }
    }
    func select(_ item: ResolvedStoryProduct, for spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.selectedID = item.id; $0.lastAction = "Selected \(item.product.title)" }
    }
    func remove(_ item: ResolvedStoryProduct, for spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.removedIDs.insert(item.id); $0.lastAction = "Removed \(item.product.title) from the shortlist" }
    }
    func setComposition(_ composition: NextGenerationCardLayout, for spec: NextGenerationFeedCardSpec) {
        guard spec.alternatives.contains(composition) else { return }
        update(spec) { $0.composition = composition; $0.lastAction = "Composition changed; products and selection retained" }
    }
    func setInteractions(_ enabled: Bool, for spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.interactionsEnabled = enabled }
    }
    func restoreShortlist(_ spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.removedIDs = []; $0.lastAction = "Shortlist restored" }
    }
    func reset(_ spec: NextGenerationFeedCardSpec) { states.removeValue(forKey: spec.id) }
    private func update(_ spec: NextGenerationFeedCardSpec, change: (inout CardState) -> Void) {
        var current = state(for: spec)
        change(&current)
        states[spec.id] = current
    }
}
