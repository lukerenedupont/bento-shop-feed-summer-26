import SwiftUI

/// Stable host for setup and feed-level design tools. It stays alive when an
/// inspector disables/reorders its own source card, including an empty feed.
struct GenerativePrototypeTools: ViewModifier {
    @Bindable var session: GenerativeFeedPrototypeSession
    let merchants: [SampleMerchant]
    var active = true
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task(id: active) {
                guard active, NextGeneration20Catalog.enabled else { return }
                // Let Home's initial utility positioning finish before an
                // explicit demo journey requests the native scroll target.
                await Task.yield()
                guard !Task.isCancelled else { return }
                session.openLaunchJourneyIfRequested()
            }
            .sheet(isPresented: $session.showsKeptSelections) {
                JourneyKeptSelections(session: session, merchants: merchants)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { session.persistJourneyMemory() }
            }
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
                        if DossierReviewLibrary.enabled {
                            Text("Scenes and films are generated styling studies, not photographs of you or renders of a changed selection. Product details retain source photographs; prices and compatibility are not independently verified.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(NextGeneration20Catalog.enabled
                            ? "This demo uses twenty authored compositions and explicit journey transitions—not live model calls or actual account history. Choices and kept selections stay on this device until you reset the demo. No purchases or account changes are made."
                            : "This prototype uses an authored Luke scenario—not your actual purchases, saves or searches. Selections stay on this device for this session. No purchases or account changes are made.")
                        Text(NextGeneration20Catalog.enabled
                            ? "Use a card's options to return to Kept selections or inspect its authored specification. The feed itself stays free of debug labels."
                            : "After this setup, the feed is shown without debug labels. Long-press any card heading to inspect or direct it.")
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
                if NextGeneration20Catalog.enabled {
                    Section("Demo journeys") {
                        Button("Finish a room") { dismiss(); session.requestJourney(DemoJourneyCatalog.room) }
                        Button("Choose a shoe and build a look") { dismiss(); session.requestJourney(DemoJourneyCatalog.footwear) }
                        Button("Discover and keep a book") { dismiss(); session.requestJourney(DemoJourneyCatalog.books) }
                        Text("The same feed, with remembered decisions. Kept selections are available from every card's options menu.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Signals in the feed") {
                    ForEach(session.orderedSignalIDs, id: \.self) { id in
                        if let signal = GenerativeFeedPrototypeFixtures.signals.first(where: { $0.id == id }) {
                            Toggle(sources.first(where: { $0.signal.id == signal.id && $0.isQuietReview })?.title ?? signal.kind.rawValue, isOn: Binding(
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
