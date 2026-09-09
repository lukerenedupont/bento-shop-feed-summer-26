import SwiftUI

/// Stable host for setup and feed-level design tools. It stays alive when an
/// inspector disables/reorders its own source card, including an empty feed.
struct GenerativePrototypeTools: ViewModifier {
    @Bindable var session: GenerativeFeedPrototypeSession
    let merchants: [SampleMerchant]
    var active = true

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $session.showsFeedControls) {
                GenerativeFeedDesignPanel(session: session, merchants: merchants)
            }
            .sheet(isPresented: Binding(
                get: { active && !session.designMode && !session.acknowledgedDemo },
                set: { if !$0 { session.acknowledgedDemo = true } }
            )) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                        Text("Preview the shopping feed")
                            .font(GravityFont.expressiveSemiBold.fixedFont(size: 28))
                        Text("Real products. Simulated activity.").font(.headline)
                        Text("These cards are authored examples of generative output, using real merchant catalogs and photography. No AI model is called, and activity is simulated—not your actual purchases, saves or searches. Selections last only for this session. No purchases or account changes are made.")
                        Text("After this setup, the feed is shown without debug labels. Long-press any card heading to inspect or direct it.")
                            .foregroundStyle(.secondary)
                        Button("Preview feed") { session.enterConsumerPreview() }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("generative.previewConsumer")
                        Button("Open design mode") { session.designMode = true; session.acknowledgedDemo = true }
                    }
                    .padding(GravitySpacing.space24)
                }
                .environment(\.colorScheme, .light)
                .presentationDetents([.large])
                .interactiveDismissDisabled()
            }
            .overlay(alignment: .bottomLeading) {
                if active, session.designMode,
                   session.disabledSignalIDs.count == GenerativeFeedPrototypeFixtures.signals.count {
                    Button("Edit demo feed") { session.showsFeedControls = true }
                        .buttonStyle(.borderedProminent)
                        .padding(.leading, 20)
                        .padding(.bottom, FeedCardStyle.bottomNavigationClearance)
                }
            }
    }
}

struct GenerativeFeedDesignPanel: View {
    @Bindable var session: GenerativeFeedPrototypeSession
    let merchants: [SampleMerchant]
    @Environment(\.dismiss) private var dismiss

    private var sources: [NextGenerationFeedCardSpec] {
        NextGenerationFeedCardCatalog.cards(signals: GenerativeFeedPrototypeFixtures.signals, merchants: merchants)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Prototype context") {
                    Text("Luke · authored demo activity")
                    Text("Real catalog; simulated purchases, saves, searches and Worlds. Signal switches below add or remove jobs from the feed. Drag handles change their order.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Signals in the feed") {
                    ForEach(session.orderedSignalIDs, id: \.self) { id in
                        if let signal = GenerativeFeedPrototypeFixtures.signals.first(where: { $0.id == id }) {
                            Toggle(signal.kind.rawValue, isOn: Binding(
                                get: { !session.disabledSignalIDs.contains(id) },
                                set: { session.setSignalEnabled($0, id: id) }
                            ))
                            .accessibilityIdentifier("generative.signal.\(id)")
                        }
                    }
                    .onMove { session.moveSignals(from: $0, to: $1) }
                }
                Section("Regeneration") {
                    Text("Re-runs each job against its current signal and real catalog. Valid selections, dismissals and chosen directions stay intact. No model API is called.")
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(sources) { source in
                        LabeledContent(source.signal.kind.rawValue, value: "Revision \(session.state(for: source).generation)")
                    }
                }
                Section {
                    Button("Preview without design controls") {
                        session.enterConsumerPreview()
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Direct the feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Show all signals") { sources.forEach { session.setSignalEnabled(true, id: $0.signal.id) } }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .bottomBar) {
                    Button("Regenerate feed") { sources.forEach { session.regenerate($0) } }
                        .accessibilityIdentifier("generative.regenerateFeed")
                }
            }
        }
        .environment(\.colorScheme, .light)
    }
}
