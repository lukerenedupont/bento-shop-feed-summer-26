import SwiftUI

struct ResearchShippingPolicy: Decodable {
    let merchantID: String
    let summary: String
    let detail: String
    let sourceURL: String
    let observedAt: String
}

struct ResearchShoeMatch: Hashable, Identifiable {
    let model: String
    let color: String
    var id: String { "\(model)|\(color.lowercased())" }
    var title: String { "\(model) · \(color)" }
    func matches(_ offer: ResearchOffer) -> Bool {
        offer.section == "shoes" && offer.model == model
            && offer.color.caseInsensitiveCompare(color) == .orderedSame
            && offer.currency == "USD"
    }
}

enum ResearchComparisonCriterion: String, CaseIterable, Identifiable {
    case price = "Best price"
    case shipping = "Fastest shipping"
    case rating = "Highest rated"
    var id: String { rawValue }
}

/// Only exact model/color/US men's size observations can share a price ranking.
/// Dispatch policies aren't delivery estimates; missing ratings aren't zero stars.
struct ResearchComparison {
    let offers: [ResearchOffer]
    let lowestOfferIDs: Set<String>
    let notice: String?

    init(offers: [ResearchOffer], match: ResearchShoeMatch, size: String, criterion: ResearchComparisonCriterion) {
        let matching = offers.filter { match.matches($0) && $0.usMensSizes.contains(size) }
        self.offers = criterion == .price
            ? matching.sorted { $0.amount == $1.amount ? $0.merchantName < $1.merchantName : $0.amount < $1.amount }
            : matching.sorted { $0.merchantName < $1.merchantName }
        if criterion == .price, Set(matching.map(\.merchantID)).count > 1,
           let lowest = matching.map(\.amount).min() {
            lowestOfferIDs = Set(matching.filter { $0.amount == lowest }.map(\.id))
        } else { lowestOfferIDs = [] }
        switch criterion {
        case .price:
            notice = matching.isEmpty ? "No checked offers in this size."
                : matching.count == 1 ? "One checked offer in this size. No price winner yet." : nil
        case .shipping:
            notice = "Delivery dates aren't verified yet. These shops aren't ranked by speed."
        case .rating:
            notice = "Comparable ratings aren't available yet. No rating winner selected."
        }
    }
}

/// A buying-guide hierarchy rather than a comparison dashboard. The model
/// selected in “Find your Norda” flows here; this block asks only for size,
/// leads with the lowest exact-match observation, then shows other sellers.
struct ResearchMerchantComparison: View {
    let world: ShoppingResearchWorld
    let onOffer: (ResearchOffer, String) -> Void
    @AppStorage private var model: String
    @AppStorage("shop-agent.norda.comparison-us-size") private var size = "9"
    private let accent = Color(hex: "#DFECA5")

    init(world: ShoppingResearchWorld, onOffer: @escaping (ResearchOffer, String) -> Void) {
        self.world = world
        self.onOffer = onOffer
        _model = AppStorage(wrappedValue: "All", "\(world.id).model")
    }

    private var match: ResearchShoeMatch? {
        if model != "All", let selected = world.comparisonMatches.first(where: { $0.model == model }) {
            return selected
        }
        return world.comparisonMatches.first { $0.model == "003" } ?? world.comparisonMatches.first
    }
    private var availableSizes: [String] {
        guard let match else { return [] }
        let compared = world.offers.filter(match.matches)
        let counts = Dictionary(grouping: compared.flatMap(\.usMensSizes), by: { $0 }).mapValues(\.count)
        let shared = counts.filter { $0.value > 1 }.map(\.key)
        return (shared.isEmpty ? Array(counts.keys) : shared).sorted { (Double($0) ?? 0) < (Double($1) ?? 0) }
    }

    var body: some View {
        if let match {
            let safeSize = availableSizes.contains(size) ? size : availableSizes.first ?? size
            let result = world.comparison(match: match, size: safeSize, criterion: .price)
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where to buy it.")
                        .font(GravityFont.expressiveBold.fixedFont(size: 30)).tracking(-1)
                        .accessibilityAddTraits(.isHeader)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Norda \(match.title)")
                            .font(GravityFont.medium.fixedFont(size: 16))
                        Spacer()
                        sizeMenu(safeSize)
                    }
                    Text("Same shoe, color and available size at each shop.")
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.white.opacity(0.65))
                }.padding(.horizontal, 20)

                if let pick = result.offers.first {
                    recommendation(pick, result: result, size: safeSize)
                    if result.offers.count > 1 {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Also available")
                                .font(GravityFont.semiBold.fixedFont(size: 14))
                                .padding(.bottom, 8)
                            ForEach(Array(result.offers.dropFirst().enumerated()), id: \.element.id) { index, offer in
                                alternativeRow(offer, result: result, size: safeSize)
                                if index < result.offers.dropFirst().count - 1 {
                                    Divider().overlay(.white.opacity(0.12))
                                }
                            }
                        }.padding(.horizontal, 20)
                    }
                } else if let notice = result.notice {
                    Text(notice).font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(.white.opacity(0.7)).padding(.horizontal, 20)
                }
            }
            .onAppear { if size != safeSize { size = safeSize } }
            .onChange(of: model) { _, _ in
                if !availableSizes.contains(size), let first = availableSizes.first { size = first }
            }
        }
    }

    private func sizeMenu(_ selectedSize: String) -> some View {
        Menu {
            ForEach(availableSizes, id: \.self) { value in
                Button("US men's \(value)") { size = value }
            }
        } label: {
            HStack(spacing: 5) {
                Text("US M \(selectedSize)")
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .font(GravityFont.medium.fixedFont(size: 13))
            .foregroundStyle(.white)
        }
        .accessibilityIdentifier("research.comparison-size")
    }

    private func recommendation(_ offer: ResearchOffer, result: ResearchComparison, size: String) -> some View {
        Button { onOffer(offer, size) } label: {
            VStack(alignment: .leading, spacing: 16) {
                Text(result.lowestOfferIDs.contains(offer.id) ? "Best observed price" : "One checked offer")
                    .font(GravityFont.semiBold.fixedFont(size: 12))
                    .foregroundStyle(accent)
                HStack(alignment: .center, spacing: 16) {
                    ProductCard(image: nil, imageURL: offer.image, showFavoriteButton: false)
                        .frame(width: 112, height: 112).environment(\.colorScheme, .light)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(offer.displayPrice)
                            .font(GravityFont.expressiveBold.fixedFont(size: 36)).tracking(-1)
                        Text("at \(offer.merchantName.localizedCapitalized)")
                            .font(GravityFont.semiBold.fixedFont(size: 16)).lineLimit(2)
                        if let difference = priceDifference(from: offer, in: result) {
                            Text("\(difference) below the next observed item price")
                                .font(GravityFont.regular.fixedFont(size: 12))
                                .foregroundStyle(.white.opacity(0.68)).lineLimit(2)
                        }
                    }
                }
                HStack {
                    Text("View offer").font(GravityFont.semiBold.fixedFont(size: 14))
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "#26382D"))
                .padding(.horizontal, 16).frame(height: 46)
                .background(accent, in: Capsule())
            }
            .padding(20)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.11)))
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityIdentifier("research.merchant.\(offer.nativeID)")
    }

    private func alternativeRow(_ offer: ResearchOffer, result: ResearchComparison, size: String) -> some View {
        Button { onOffer(offer, size) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(offer.merchantName.localizedCapitalized)
                        .font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(1)
                    if result.lowestOfferIDs.contains(offer.id), result.lowestOfferIDs.count > 1 {
                        Text("Same observed item price").font(GravityFont.regular.fixedFont(size: 11))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                Spacer(minLength: 8)
                Text(offer.displayPrice).font(GravityFont.expressiveBold.fixedFont(size: 22))
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(minHeight: 62).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("research.merchant.\(offer.nativeID)")
    }

    private func priceDifference(from offer: ResearchOffer, in result: ResearchComparison) -> String? {
        guard result.lowestOfferIDs.count == 1,
              let next = result.offers.dropFirst().first,
              next.amount > offer.amount else { return nil }
        return offer.money(String(next.amount - offer.amount))
    }
}
