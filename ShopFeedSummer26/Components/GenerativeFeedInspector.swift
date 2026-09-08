import SwiftUI

/// PROTOTYPE only. Debug controls never mutate the canonical catalog or buyer.
struct GenerativeFeedInspector: View {
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Simulated activity, real catalog")
                        .font(.headline)
                    Text("This feed uses an authored Luke demo scenario. Purchases, views, affinity and World activity below are fixtures—not observed account history.")
                }
                Section("Signal → shopping job") {
                    Text(spec.signal.summary)
                    LabeledContent("Job", value: spec.job.rawValue)
                    if let world = spec.signal.worldID { LabeledContent("World", value: world) }
                    Text(spec.reasonForSelection)
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
                        get: { session.designMode }, set: { session.designMode = $0 }
                    ))
                    Text("Changing composition keeps the same data and selection. Close this sheet to see the result.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Canonical entities") {
                    if let ref = spec.anchor,
                       let item = NextGenerationFeedCardSpec.resolve(ref, in: merchants) {
                        entity(item, role: "Anchor")
                    }
                    ForEach(spec.resolvedProducts(from: merchants)) { item in entity(item, role: "Candidate") }
                }
                Section("Session state") {
                    LabeledContent("Interaction", value: spec.interaction.rawValue)
                    LabeledContent("Selected product", value: session.selected(in: spec.resolvedProducts(from: merchants), for: spec)?.product.title ?? "None")
                    LabeledContent("Removed candidates", value: String(session.state(for: spec).removedIDs.count))
                    Text(session.state(for: spec).lastAction)
                        .accessibilityIdentifier("generative.lastAction")
                    Button("Reset this card", role: .destructive) { session.reset(spec) }
                }
            }
            .navigationTitle("Design inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
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
