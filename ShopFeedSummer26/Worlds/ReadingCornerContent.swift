import SwiftUI

struct ReadingCornerFeedSummary: View {
    private let selection = ReadingCornerSelection.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(selection.selected) { piece in
                    CornerArtwork(url: ShopCanvasLibrary.resolve(piece.product.image), ratio: 1)
                        .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            Text(ReadingCornerCatalog.money(selection.subtotalCents))
                .font(GravityFont.semiBold.fixedFont(size: 19))
                .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("corner.feed-set")
    }
}

/// Authored set composition inside the shared World host, with canonical PDPs.
struct ReadingCornerContent: View {
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var selection = ReadingCornerSelection.shared
    @State private var selectedRole = ReadingCornerPiece.Role.chair
    @State private var showsRoom = false
    @State private var showsSources = false

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            request
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    heading("Make it yours.")
                    Spacer()
                    Button { coordinator.pushRoute(.store(merchantId: ReadingCornerCatalog.merchantID)) } label: {
                        LibraryMerchantWordmark(merchantID: ReadingCornerCatalog.merchantID, onDark: true)
                            .frame(width: 104, height: 32)
                    }.accessibilityLabel("Explore The Oblist")
                }
                rolePicker
                ReadingCornerDeck(selection: selection, role: selectedRole, onOpen: open).id(selectedRole)
                budgetSummary
            }
            roomAction
            ReadingCornerDiscovery()
            Button { showsSources = true } label: {
                Label("Imagery, prices & sources", systemImage: "info.circle")
                    .font(GravityFont.medium.fixedFont(size: 14))
            }
        }
        .padding(.horizontal, 16).foregroundStyle(.white).padding(.bottom, 180)
        .sheet(isPresented: $showsRoom) { ReadingCornerRoomBoard(selection: selection) }
        .sheet(isPresented: $showsSources) { sources.environment(\.colorScheme, .light) }
    }

    private func heading(_ title: String) -> some View {
        Text(title).font(GravityFont.expressiveBold.fixedFont(size: 28)).tracking(-0.5)
    }

    private var request: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOU ASKED").font(GravityFont.medium.fixedFont(size: 10)).tracking(1.4)
                .foregroundStyle(.white.opacity(0.65))
            Text(ReadingCornerCatalog.prompt)
                .font(GravityFont.medium.fixedFont(size: 17)).foregroundStyle(Color(hex: "#E0F3B6"))
                .fixedSize(horizontal: false, vertical: true)
            Text("Now working with a \(ReadingCornerCatalog.money(selection.budgetCents)) budget.")
                .font(GravityFont.regular.fixedFont(size: 14)).foregroundStyle(.white.opacity(0.68))
        }.accessibilityElement(children: .combine).accessibilityIdentifier("corner.request")
    }

    private var rolePicker: some View {
        HStack(spacing: 8) {
            ForEach(selection.selected) { piece in
                Button { selectedRole = piece.role } label: {
                    VStack(spacing: 8) {
                        ReadingCornerCutout(piece: piece)
                            .frame(width: 98, height: 108, alignment: .bottom)
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 5)
                        Text(piece.role.title).font(GravityFont.medium.fixedFont(size: 15))
                        Capsule().fill(selectedRole == piece.role ? Color(hex: "#E0F3B6") : .clear)
                            .frame(width: 20, height: 2)
                    }
                    .foregroundStyle(.white.opacity(selectedRole == piece.role ? 1 : 0.7))
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("corner.role.\(piece.role.rawValue)")
                    .accessibilityLabel(piece.role.title)
                    .accessibilityAddTraits(selectedRole == piece.role ? .isSelected : [])
            }
        }
    }

    private var budgetSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("3-piece subtotal").font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.white.opacity(0.6))
                    Text(ReadingCornerCatalog.money(selection.subtotalCents)).font(GravityFont.semiBold.fixedFont(size: 25))
                        .accessibilityIdentifier("corner.subtotal")
                }
                Spacer()
                Menu {
                    ForEach([60_000, 300_000, 400_000, 500_000], id: \.self) { cents in
                        Button("\(ReadingCornerCatalog.money(cents)) item budget") { selection.setBudget(cents: cents) }
                    }
                } label: {
                    VStack(alignment: .trailing, spacing: 5) {
                        Text("Your item budget").font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.white.opacity(0.6))
                        HStack(spacing: 6) {
                            Text(ReadingCornerCatalog.money(selection.budgetCents)).font(GravityFont.medium.fixedFont(size: 25))
                            Image(systemName: "pencil").font(.system(size: 12))
                        }
                    }
                }.accessibilityLabel("Change item budget").accessibilityIdentifier("corner.budget")
            }
            Button { refineBudget() } label: {
                Text("Find options closer to my budget")
                    .font(GravityFont.medium.fixedFont(size: 14))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(.white.opacity(0.1), in: Capsule())
            }.accessibilityIdentifier("corner.refine-budget")
        }.padding(18).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
    }

    private var roomAction: some View {
        Button { showsRoom = true } label: {
            VStack(alignment: .leading, spacing: 0) {
                ReadingCornerRoomScene(pieces: selection.selected).frame(height: 280)
                HStack {
                    Text("See it in your room.").font(GravityFont.expressiveBold.fixedFont(size: 27))
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right").font(.system(size: 18, weight: .medium))
                }.padding(22).foregroundStyle(Color(hex: "#302C25"))
            }.background(Color(hex: "#E8E1D5")).clipShape(RoundedRectangle(cornerRadius: 26))
        }.buttonStyle(.plain).accessibilityIdentifier("corner.room")
    }

    private func refineBudget() {
        let list = selection.selected.map { "\($0.product.title) (\(ReadingCornerCatalog.money($0.amountCents)))" }.joined(separator: ", ")
        coordinator.julianShell.openAsk(prompt: "Find lower-priced alternatives for my reading corner: \(list). My item budget is \(ReadingCornerCatalog.money(selection.budgetCents)), before tax and shipping. The current set is \(ReadingCornerCatalog.money(selection.subtotalCents)). Please source alternatives rather than assuming these pieces fit the budget.")
    }

    private var sources: some View {
        NavigationStack {
            List {
                Section("Room inspiration") {
                    Text("The hero is The Oblist’s Living Room Edit photograph. It does not depict this selected set. It is not a rendering of your room or proof of fit.")
                    Link("The Oblist · Living Room Edit", destination: URL(string: ReadingCornerCatalog.snapshot.coverSource)!)
                }
                Section("Style inspiration") {
                    ForEach(ReadingCornerDiscoveryCatalog.directions) { direction in
                        if let source = direction.source, let url = source.url.flatMap(URL.init(string:)) {
                            Link("\(direction.title) · \(source.brand)", destination: url)
                        }
                    }
                    Text("Merchant lifestyle photography guides the mood. The grouped products are editorial suggestions, not every item or finish pictured. Discovery prices retain the original catalog observation dates; check current prices at each shop.")
                }
                Section("Selected products") {
                    ForEach(selection.selected) { piece in
                        Link(destination: URL(string: piece.product.url!)!) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(piece.product.title)
                                Text("\(piece.variantTitle) · \(ReadingCornerCatalog.money(piece.amountCents)) · USD")
                                Text(piece.note).font(.footnote)
                                Text("Checked \(String((piece.product.checkedAt ?? "").prefix(10)))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Text("Prices are item subtotals in USD, before shipping and tax. Available variants were checked on the merchant’s USD storefront; recheck before buying. No delivery quote, unified checkout, or comfort testing is implied.")
                    Text("The product cutouts are background-removed merchant photographs. The preview room is an illustrative composition, not measured placement or a generated photograph of your room. Cutout source URLs and processing provenance are bundled with the catalog.")
                    Text(ReadingCornerCatalog.snapshot.rightsStatus)
                }
            }.navigationTitle("Sources").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsSources = false } } }
        }
    }

    private func open(_ piece: ReadingCornerPiece) {
        coordinator.pushRoute(.product(merchantId: ReadingCornerCatalog.merchantID, productId: piece.product.nativeID))
    }
}
