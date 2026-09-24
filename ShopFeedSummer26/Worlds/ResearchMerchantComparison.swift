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
    @State private var selectedMatchID = ""
    @AppStorage("shop-agent.norda.comparison-us-size") private var size = "9"
    @State private var criterion = ResearchComparisonCriterion.price
    private let accent = Color(hex: "#DFECA5")

    private var match: ResearchShoeMatch? {
        world.comparisonMatches.first { $0.id == selectedMatchID }
            ?? world.featuredShoes().first.flatMap { offer in world.comparisonMatches.first { $0.matches(offer) } }
            ?? world.comparisonMatches.first
    }

    var body: some View {
        if let match {
            let result = world.comparison(match: match, size: size, criterion: criterion)
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compare shops.")
                        .font(GravityFont.expressiveBold.fixedFont(size: 30)).tracking(-1)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(world.shoeOffers(currency: "USD").count) Norda offers checked across \(world.shoeMerchantCount) shops")
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.white.opacity(0.65))
                }.padding(.horizontal, 20)
                HStack(spacing: 8) {
                    Menu {
                        ForEach(world.comparisonMatches) { item in
                            Button(item.title) { selectedMatchID = item.id }
                        }
                    } label: { menuLabel(match.title) }
                    .accessibilityIdentifier("research.comparison-model")
                    Menu {
                        ForEach(["8", "8.5", "9", "9.5", "10", "10.5", "11", "11.5", "12", "12.5", "13", "14", "15"], id: \.self) { value in
                            Button("US men's \(value)") { size = value }
                        }
                    } label: { menuLabel("US men's \(size)") }
                    .accessibilityIdentifier("research.comparison-size")
                }.padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ResearchComparisonCriterion.allCases) { option in
                            Button { criterion = option } label: {
                                Text(option.rawValue).font(GravityFont.medium.fixedFont(size: 13))
                                    .padding(.horizontal, 16).frame(minHeight: 44)
                                    .foregroundStyle(criterion == option ? Color(hex: "#26382D") : .white)
                                    .background(criterion == option ? accent : .white.opacity(0.08), in: Capsule())
                            }.buttonStyle(.plain)
                        }
                    }
                }.contentMargins(.horizontal, 20, for: .scrollContent)
                if let notice = result.notice {
                    Text(notice).font(GravityFont.regular.fixedFont(size: 13))
                        .foregroundStyle(.white.opacity(0.7)).padding(.horizontal, 20)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(result.offers) { offer in
                            merchantCard(offer, result: result)
                        }
                    }.scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func menuLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title).font(GravityFont.medium.fixedFont(size: 13))
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 14).frame(minHeight: 44)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private func merchantCard(_ offer: ResearchOffer, result: ResearchComparison) -> some View {
        let policy = world.shippingPolicies.first { $0.merchantID == offer.merchantID }
        return Button { onOffer(offer, size) } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    ProductCard(image: nil, imageURL: offer.image, showFavoriteButton: false)
                        .frame(width: 64, height: 64).environment(\.colorScheme, .light)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(offer.merchantName.localizedCapitalized)
                            .font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(2)
                        Text(offer.displayPrice).font(GravityFont.expressiveBold.fixedFont(size: 26))
                    }
                    Spacer(minLength: 0)
                }
                if result.lowestOfferIDs.contains(offer.id) {
                    Text(result.lowestOfferIDs.count > 1 ? "Same item price" : "Lowest observed item price")
                        .font(GravityFont.medium.fixedFont(size: 12))
                        .foregroundStyle(accent)
                } else {
                    Text("Available when checked").font(GravityFont.regular.fixedFont(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Text(criterion == .rating ? "Ratings not verified" : policy?.summary ?? "Shipping not verified")
                    .font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .frame(width: 242, height: 150, alignment: .topLeading).padding(18)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1)))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("research.merchant.\(offer.nativeID)")
    }
}
