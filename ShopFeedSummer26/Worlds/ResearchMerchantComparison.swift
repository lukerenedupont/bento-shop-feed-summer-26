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

struct ResearchMerchantComparison: View {
    let world: ShoppingResearchWorld
    let onOffer: (ResearchOffer, String) -> Void
    @AppStorage("shop-agent.norda.comparison-us-size") private var size = "9"
    @State private var selectedMatchID = ""
    private let accent = Color(hex: "#DFECA5")

    private var match: ResearchShoeMatch? {
        world.comparisonMatches.first { $0.id == selectedMatchID }
            ?? world.comparisonMatches.first { $0.model == "003" }
            ?? world.comparisonMatches.first
    }
    private var availableSizes: [String] {
        guard let match else { return [] }
        return Set(world.offers.filter(match.matches).flatMap(\.usMensSizes)).sorted {
            (Double($0) ?? 0) < (Double($1) ?? 0)
        }
    }

    var body: some View {
        if let match {
            let result = world.comparison(match: match, size: size, criterion: .price)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Compare shops.")
                        .font(GravityFont.expressiveBold.fixedFont(size: 30)).tracking(-1)
                        .accessibilityAddTraits(.isHeader)
                    Text("Norda \(match.title)")
                        .font(GravityFont.medium.fixedFont(size: 16))
                    Text("Same shoe and color, checked in US men's \(size)")
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.white.opacity(0.65))
                }.padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(world.comparisonMatches) { item in
                            Button {
                                selectedMatchID = item.id
                                if !sizes(for: item).contains(size) { size = sizes(for: item).first ?? size }
                            } label: {
                                Text("\(item.model) · \(item.color)")
                                    .font(GravityFont.medium.fixedFont(size: 13))
                                    .padding(.horizontal, 14).frame(minHeight: 38)
                                    .foregroundStyle(match.id == item.id ? Color(hex: "#26382D") : .white)
                                    .background(match.id == item.id ? accent : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("research.comparison.\(item.id)")
                        }
                    }
                }.contentMargins(.horizontal, 20, for: .scrollContent)

                HStack(spacing: 12) {
                    Text("Size").font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.white.opacity(0.65))
                    Picker("US men's size", selection: $size) {
                        ForEach(availableSizes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).tint(.white)
                    .accessibilityIdentifier("research.comparison-size")
                    Spacer()
                }.padding(.horizontal, 20)

                if let notice = result.notice {
                    Text(notice).font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(.white.opacity(0.7)).padding(.horizontal, 20)
                }
                VStack(spacing: 0) {
                    ForEach(Array(result.offers.enumerated()), id: \.element.id) { index, offer in
                        merchantRow(offer, result: result)
                        if index < result.offers.count - 1 { Divider().overlay(.white.opacity(0.12)) }
                    }
                }
                .padding(.horizontal, 18)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1)))
                .padding(.horizontal, 20)
            }
        }
    }

    private func sizes(for match: ResearchShoeMatch) -> [String] {
        Set(world.offers.filter(match.matches).flatMap(\.usMensSizes)).sorted {
            (Double($0) ?? 0) < (Double($1) ?? 0)
        }
    }

    private func merchantRow(_ offer: ResearchOffer, result: ResearchComparison) -> some View {
        Button { onOffer(offer, size) } label: {
            HStack(spacing: 12) {
                ProductCard(image: nil, imageURL: offer.image, showFavoriteButton: false)
                    .frame(width: 54, height: 54).environment(\.colorScheme, .light)
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.merchantName.localizedCapitalized)
                        .font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(1)
                    if result.lowestOfferIDs.contains(offer.id) {
                        Text(result.lowestOfferIDs.count > 1 ? "Same item price" : "Lowest observed item price")
                            .font(GravityFont.medium.fixedFont(size: 11)).foregroundStyle(accent)
                    } else {
                        Text("Available when checked")
                            .font(GravityFont.regular.fixedFont(size: 11)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer(minLength: 8)
                Text(offer.displayPrice).font(GravityFont.expressiveBold.fixedFont(size: 23))
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(minHeight: 82)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("research.merchant.\(offer.nativeID)")
    }
}
