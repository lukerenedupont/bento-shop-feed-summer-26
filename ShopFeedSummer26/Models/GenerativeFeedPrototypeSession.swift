import SwiftUI

/// PROTOTYPE session: all consumers share selection, steering and design input.
/// Nothing here mutates the authenticated buyer or persists across launches.
@MainActor @Observable
final class GenerativeFeedPrototypeSession {
    struct CardState {
        var selectedID: String?
        var selectedGroupID: String?
        var removedIDs: Set<String> = []
        var composition: NextGenerationCardLayout?
        var interactionsEnabled = true
        var signalKind: PrototypeShoppingSignal.Kind?
        var jobOverride: PrototypeShoppingJob?
        var generation = 0
        var lastAction = "No interaction yet"
    }
    private var states: [String: CardState] = [:]
    private(set) var disabledSignalIDs: Set<String> = []
    private(set) var orderedSignalIDs = GenerativeFeedPrototypeFixtures.signals.map(\.id)
    var designMode = ProcessInfo.processInfo.arguments.contains("-feedDesignMode")
    var acknowledgedDemo = false
    var showsFeedControls = false
    var requestedFeedControls = false

    func enterConsumerPreview() { acknowledgedDemo = true; designMode = false }
    func state(for spec: NextGenerationFeedCardSpec) -> CardState { states[spec.id] ?? CardState() }

    func resolve(_ source: NextGenerationFeedCardSpec, merchants: [SampleMerchant]) -> NextGenerationFeedCardSpec {
        let state = state(for: source)
        guard state.generation > 0 || state.signalKind != nil || state.jobOverride != nil else { return source }
        var signal = source.signal
        if let kind = state.signalKind {
            signal.kind = kind
            signal.summary = kind == .savedShortlist
                ? "Demo activity: saved these three House of Leon chairs."
                : "Demo activity: revisited these three House of Leon chairs."
        }
        return NextGenerationFeedCardCatalog.card(signal: signal, merchants: merchants,
            jobOverride: state.jobOverride, generation: state.generation) ?? source
    }

    func composition(for spec: NextGenerationFeedCardSpec) -> NextGenerationCardLayout {
        let override = state(for: spec).composition
        return override.flatMap { spec.alternatives.contains($0) ? $0 : nil } ?? spec.layout
    }
    func activeGroup(for spec: NextGenerationFeedCardSpec) -> PrototypeContentGroup? {
        spec.groups.first { $0.id == state(for: spec).selectedGroupID }
    }
    func products(for spec: NextGenerationFeedCardSpec, merchants: [SampleMerchant]) -> [ResolvedStoryProduct] {
        let items = spec.resolvedProducts(from: merchants)
        guard let group = activeGroup(for: spec) else { return items }
        let groupIDs = Set(group.products.map { "\($0.merchantID)-\($0.productID)" })
        return items.filter { groupIDs.contains("\($0.merchant.id)-\($0.product.id)") }
    }
    func selected(in items: [ResolvedStoryProduct], for spec: NextGenerationFeedCardSpec) -> ResolvedStoryProduct? {
        let current = state(for: spec)
        return items.first { $0.id == current.selectedID && !current.removedIDs.contains($0.id) }
            ?? items.first { !current.removedIDs.contains($0.id) }
    }
    func select(_ item: ResolvedStoryProduct, for spec: NextGenerationFeedCardSpec) {
        guard state(for: spec).interactionsEnabled else { return }
        update(spec) { $0.selectedID = item.id; $0.lastAction = "Selected \(item.product.title)" }
    }
    func choose(_ group: PrototypeContentGroup, for spec: NextGenerationFeedCardSpec) {
        guard state(for: spec).interactionsEnabled, spec.groups.contains(where: { $0.id == group.id }) else { return }
        update(spec) {
            $0.selectedGroupID = group.id; $0.selectedID = nil
            $0.lastAction = "Chose \(group.title); card now contains only this group's inventory"
        }
    }
    func clearGroup(_ spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.selectedGroupID = nil; $0.selectedID = nil; $0.lastAction = "Returned to directions" }
    }
    func remove(_ item: ResolvedStoryProduct, for spec: NextGenerationFeedCardSpec) {
        guard state(for: spec).interactionsEnabled else { return }
        update(spec) { $0.removedIDs.insert(item.id); $0.lastAction = "Removed \(item.product.title) from the shortlist" }
    }
    func setComposition(_ composition: NextGenerationCardLayout, for spec: NextGenerationFeedCardSpec) {
        guard spec.alternatives.contains(composition) else { return }
        update(spec) { $0.composition = composition; $0.lastAction = "Composition changed; products and selection retained" }
    }
    func setSignal(_ kind: PrototypeShoppingSignal.Kind, for spec: NextGenerationFeedCardSpec) {
        guard spec.signal.alternateSignals.contains(kind) else { return }
        update(spec) {
            $0.signalKind = kind; $0.jobOverride = nil; $0.composition = nil; $0.generation += 1
            $0.lastAction = "Rebuilt from \(kind.rawValue); retained valid choices"
        }
    }
    func setJob(_ job: PrototypeShoppingJob, for spec: NextGenerationFeedCardSpec) {
        guard spec.signal.supportedJobs.contains(job) else { return }
        update(spec) {
            $0.jobOverride = job; $0.composition = nil; $0.generation += 1
            $0.lastAction = "Rebuilt for \(job.rawValue); retained valid choices"
        }
    }
    func regenerate(_ spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.generation += 1; $0.lastAction = "Rebuilt from current inputs; selected and dismissed items retained" }
    }
    func setInteractions(_ enabled: Bool, for spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.interactionsEnabled = enabled }
    }
    func restoreShortlist(_ spec: NextGenerationFeedCardSpec) {
        update(spec) { $0.removedIDs = []; $0.lastAction = "Shortlist restored" }
    }
    func reset(_ spec: NextGenerationFeedCardSpec) { states.removeValue(forKey: spec.id) }

    func setSignalEnabled(_ enabled: Bool, id: String) {
        if enabled { disabledSignalIDs.remove(id) } else { disabledSignalIDs.insert(id) }
    }
    func moveSignals(from offsets: IndexSet, to destination: Int) {
        orderedSignalIDs.move(fromOffsets: offsets, toOffset: destination)
    }
    func arrange(_ entries: [FeedEntry]) -> [FeedEntry] {
        guard entries.contains(where: { if case .nextGeneration = $0 { return true }; return false }) else { return entries }
        let ranks = Dictionary(uniqueKeysWithValues: orderedSignalIDs.enumerated().map { ($1, $0) })
        return entries.filter {
            if case let .nextGeneration(spec) = $0 { return !disabledSignalIDs.contains(spec.signal.id) }
            return true
        }.sorted {
            func rank(_ entry: FeedEntry) -> Int {
                if case let .nextGeneration(spec) = entry { return ranks[spec.signal.id] ?? Int.max }
                return Int.max
            }
            return rank($0) < rank($1)
        }
    }
    private func update(_ spec: NextGenerationFeedCardSpec, change: (inout CardState) -> Void) {
        var current = state(for: spec)
        change(&current)
        states[spec.id] = current
    }
}
