import SwiftUI

/// Journey-specific actions stay outside the composition renderer.
struct JourneyCardMenu: View {
    let context: CompositionContext
    var body: some View {
        Button("Kept selections") { context.session.showsKeptSelections = true }
        if let selected = context.selected {
            Button("Keep \(selected.product.title)") { context.session.keepJourneySelection([selected], for: context.spec) }
        }
        if context.definition.id == DemoJourneyCatalog.footwearLook {
            Button("Back to shoe selection") { context.session.returnToShoeSelection() }
        }
        if context.definition.id == DemoJourneyCatalog.roomComparison {
            Button("Back to the room") { context.session.requestJourney(DemoJourneyCatalog.room) }
        }
    }
}

/// Continuations live in the existing review sheet; cards retain their native
/// primary action and the feed remains the navigation surface.
struct JourneyContinuationActions: View {
    let context: CompositionContext
    let onLeave: () -> Void
    var body: some View {
        if context.definition.id == DemoJourneyCatalog.room {
            Button("Compare chairs for this room") {
                onLeave(); context.session.compareRoomChairs(context)
            }.buttonStyle(.bordered).tint(.black)
                .accessibilityIdentifier("journey.compareRoom")
        }
        if context.definition.id == DemoJourneyCatalog.roomComparison {
            ForEach(context.reviewItems) { item in
                Button("Use \(item.product.title) in the room") {
                    onLeave(); context.session.useChairInRoom(item, context: context)
                }.buttonStyle(.bordered).tint(.black)
                    .accessibilityIdentifier("journey.useChair.\(item.id)")
            }
        }
        if context.definition.id == DemoJourneyCatalog.footwear,
           context.session.activeGroup(for: context.spec) != nil, let shoe = context.selected {
            Button("Build around \(shoe.product.title)") {
                onLeave(); context.session.buildAroundSelectedShoe(context)
            }.buttonStyle(.bordered).tint(.black)
                .accessibilityIdentifier("journey.buildLook")
            Text("An authored combination using the selected shoe's real product image—not a generated outfit photograph.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct JourneyProductReview: View {
    let item: ResolvedStoryProduct
    let context: CompositionContext
    var body: some View {
        GenerativeProductReview(item: item)
            .safeAreaInset(edge: .bottom) {
                Button(context.session.hasKept([item], for: context.spec) ? "Kept on this device" : "Keep this product") {
                    context.session.keepJourneySelection([item], for: context.spec)
                }
                .buttonStyle(.borderedProminent).tint(.black)
                .accessibilityIdentifier("journey.keepProduct")
                .frame(maxWidth: .infinity).padding(12).background(.regularMaterial)
            }
    }
}

struct JourneyKeptSelections: View {
    let session: GenerativeFeedPrototypeSession
    let merchants: [SampleMerchant]
    @Environment(\.dismiss) private var dismiss
    @State private var detail: ResolvedStoryProduct?
    @State private var confirmsReset = false

    private func items(_ selection: FeedJourneyMemory.KeptSelection) -> [ResolvedStoryProduct] {
        selection.products.compactMap { NextGenerationFeedCardSpec.resolve(.init(merchantID: $0.merchantID, productID: $0.productID), in: merchants) }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Exact selections kept on this device. Continue restores the choices you kept, not your latest browsing. This demo does not change your account.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if session.journeyMemory.kept.isEmpty {
                    Section { Text("Nothing kept yet. Inspect a product or review a composition, then choose Keep.") }
                }
                ForEach(session.journeyMemory.kept) { selection in
                    Section(selection.title) {
                        let products = items(selection)
                        ForEach(products) { item in
                            Button { detail = item } label: {
                                HStack(spacing: 12) {
                                    GenerativeProductMedia(item: item).frame(width: 64, height: 72)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.product.title).font(.subheadline)
                                        Text(item.merchant.displayName).font(.caption).foregroundStyle(.secondary)
                                    }
                                }.foregroundStyle(.primary)
                            }.buttonStyle(.plain)
                        }
                        if products.count != selection.products.count {
                            Text("Some products are no longer available in this demo catalog.").font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("Continue this selection") {
                            dismiss(); session.resumeJourneySelection(selection)
                        }
                        .disabled(products.count != selection.products.count || !session.canResumeJourney(selection))
                        .accessibilityIdentifier("journey.resume.\(selection.id)")
                        Button("Remove kept selection", role: .destructive) { session.removeJourneySelection(selection) }
                    }
                }
            }
            .navigationTitle("Kept selections").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .bottomBar) { Button("Reset demo", role: .destructive) { confirmsReset = true } }
            }
            .confirmationDialog("Remove demo selections and reset all twenty cards? Your account and other feeds are untouched.", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset demo", role: .destructive) { dismiss(); session.resetJourneyDemo() }
            }
            .sheet(item: $detail) { GenerativeProductReview(item: $0) }
        }.environment(\.colorScheme, .light)
    }
}
