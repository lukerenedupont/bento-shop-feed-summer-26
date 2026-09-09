import SwiftUI

/// PROTOTYPE only. Debug controls never mutate the canonical catalog or buyer.
struct GenerativeFeedInspector: View {
    let sourceSpec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    @Environment(\.dismiss) private var dismiss

    private var spec: NextGenerationFeedCardSpec { session.resolve(sourceSpec, merchants: merchants) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Simulated activity, real catalog")
                        .font(.headline)
                    Text("Authored Luke demo scenario. This activity is simulated, not observed account history.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Signal → shopping job") {
                    Text(spec.signal.summary)
                    if spec.isQuietReview {
                        LabeledContent("Scenario", value: spec.title)
                        LabeledContent("Shopping job", value: spec.job.rawValue)
                        Text("Fixed review fixture. Inputs and recommendation sets are authored; regeneration retains this scenario.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                    Picker("Signal", selection: Binding(
                        get: { spec.signal.kind }, set: { session.setSignal($0, for: spec) }
                    )) {
                        ForEach(spec.signal.alternateSignals) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("generative.sourceSignal")
                    Picker("Shopping job", selection: Binding(
                        get: { spec.job }, set: { session.setJob($0, for: spec) }
                    )) {
                        ForEach(spec.signal.supportedJobs) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("generative.job")
                    }
                    if let world = spec.signal.worldID { LabeledContent("World", value: world) }
                    DisclosureGroup("Why this card?") {
                        Text(spec.reasonForSelection)
                        Text("Only supported signal/job combinations are offered for this scenario.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Direct this card") {
                    Picker("Composition", selection: Binding(
                        get: { session.composition(for: spec) },
                        set: { session.setComposition($0, for: spec) }
                    )) {
                        ForEach(spec.alternatives) { layout in Text(layout.rawValue).tag(layout) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("generative.composition")
                    Toggle("Enable card interactions", isOn: Binding(
                        get: { session.state(for: spec).interactionsEnabled },
                        set: { session.setInteractions($0, for: spec) }
                    ))
                    Toggle("Show inspector buttons in feed", isOn: Binding(
                        get: { session.designMode }, set: { if $0 { session.designMode = true } else { session.enterConsumerPreview() } }
                    ))
                    Text("Changing composition keeps the same data and selection. Regeneration repeats catalog retrieval with current signal/job inputs, retaining valid state.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    DisclosureGroup("\(DossierReviewLibrary.record(for: spec) == nil ? "Canonical entities" : "Dossier references") (\(spec.productReferences.count))") {
                        if let ref = spec.anchor,
                           let item = NextGenerationFeedCardSpec.resolve(ref, in: merchants) {
                            entity(item, role: "Anchor")
                        }
                        ForEach(spec.resolvedProducts(from: merchants)) { item in entity(item, role: "Candidate") }
                    }
                }
                Section("Session state") {
                    LabeledContent("Interaction", value: spec.interaction.rawValue)
                    LabeledContent("Behavior", value: spec.interaction.level)
                    LabeledContent("Direction / merchant", value: session.activeGroup(for: spec)?.title ?? "Not chosen")
                    LabeledContent("Selected product", value: session.selected(in: session.products(for: spec, merchants: merchants), for: spec)?.product.title ?? "None")
                    LabeledContent("Removed candidates", value: String(session.state(for: spec).removedIDs.count))
                    LabeledContent("Saved selections", value: String(session.state(for: spec).savedSelectionIDs.count))
                    if spec.interaction == .shortlist {
                        let pair = spec.isQuietReview
                            ? spec.resolvedProducts(from: merchants).filter { session.state(for: spec).comparisonIDs.contains($0.id) }
                            : session.comparisonPair(in: spec.resolvedProducts(from: merchants), for: spec)
                        Text("Comparing: " + pair.map { $0.product.title }.joined(separator: " / "))
                    }
                    if spec.isQuietReview, spec.interaction == .selectForWorld {
                        ForEach(spec.groups) { slot in
                            LabeledContent(slot.title, value: session.roomProduct(slot: slot, for: spec, merchants: merchants)?.product.title ?? "None")
                        }
                    }
                    if let record = DossierReviewLibrary.record(for: spec) {
                        Text(record.note).font(.footnote).foregroundStyle(.secondary)
                        LabeledContent("Saved compositions", value: String(session.state(for: spec).savedDossierPlans.count))
                        Text("Dossier product IDs are local surrogates for the original global IDs, not verified merchant IDs. Original mappings are preserved in ReviewSources.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if spec.isQuietReview, spec.interaction == .swap {
                        Text("The flat tee is a generated Dossier styling illustration. Product details use the original merchant photograph. The Dossier look is inspiration, not a render of the current selection.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Text(session.state(for: spec).lastAction)
                        .accessibilityIdentifier("generative.lastAction")
                    Button("Reset this card", role: .destructive) { session.reset(spec) }
                }
            }
            .navigationTitle("Design inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Feed") { session.requestedFeedControls = true; dismiss() }
                        .accessibilityIdentifier("generative.editFeed")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Regenerate this card") { session.regenerate(spec) }
                        .accessibilityIdentifier("generative.regenerateCard")
                    Spacer()
                    Text("Revision \(spec.generation)").accessibilityIdentifier("generative.revision")
                }
            }
        }
        .environment(\.colorScheme, .light)
        .presentationDetents([.large])
    }

    private func entity(_ item: ResolvedStoryProduct, role: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(role) · \(item.merchant.displayName)").font(.caption).foregroundStyle(.secondary)
            Text(item.product.title)
            Text("\(GenerativeFeedStyle.price(item.product)) · \(item.product.id)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
