import SwiftUI

/// PROTOTYPE design pass: a fixed purchase with changeable companions, and
/// simultaneous comparison. Both live inside the existing feed/card grammar.
struct GenerativeOutfitComposition: View {
    let anchor: ResolvedStoryProduct
    let selected: ResolvedStoryProduct
    let products: [ResolvedStoryProduct]
    let size: CGSize
    let saved: Bool
    let enabled: Bool
    let onSelect: (ResolvedStoryProduct) -> Void
    let onSave: () -> Void
    let onOpen: (ResolvedStoryProduct) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            HStack(alignment: .center, spacing: GravitySpacing.space8) {
                garment(anchor, caption: "You bought", width: (size.width - 40) * 0.6)
                garment(selected, caption: "Wear it with", width: (size.width - 40) * 0.4)
            }
            .padding(GravitySpacing.space16)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: GravityRadius.r24))

            HStack(alignment: .top, spacing: GravitySpacing.space8) {
                Button { onOpen(selected) } label: {
                    VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                        Text(selected.product.title)
                            .font(GravityFont.semiBold.fixedFont(size: 16))
                            .lineLimit(3).multilineTextAlignment(.leading)
                        Text("\(selected.merchant.displayName) · \(GenerativeFeedStyle.price(selected.product))")
                            .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("View \(selected.product.title)")
                Button(action: onSave) {
                    Image(systemName: saved ? "heart.fill" : "heart")
                        .font(.system(size: 20)).frame(width: 44, height: 44)
                }
                .accessibilityLabel(saved ? "Unsave this look" : "Save this look")
                .accessibilityIdentifier("generative.saveSelection")
            }
            HStack(spacing: GravitySpacing.space8) {
                ForEach(products) { item in
                    Button { onSelect(item) } label: {
                        HStack(spacing: GravitySpacing.space8) {
                            GenerativeProductMedia(item: item).frame(width: 28, height: 36)
                            Text(GenerativeDecisionContent.variant(item))
                                .font(GravityFont.medium.fixedFont(size: 13)).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, GravitySpacing.space12)
                        .frame(minHeight: 48)
                        .background(selected.id == item.id ? Color.white : .clear, in: RoundedRectangle(cornerRadius: GravityRadius.r16))
                        .overlay {
                            RoundedRectangle(cornerRadius: GravityRadius.r16)
                                .strokeBorder(selected.id == item.id ? Color.black : .black.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .accessibilityLabel("Select \(item.product.title)")
                    .accessibilityAddTraits(selected.id == item.id ? .isSelected : [])
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func garment(_ item: ResolvedStoryProduct, caption: String, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space8) {
            Text(caption).font(GravityFont.medium.fixedFont(size: 12)).foregroundStyle(.secondary)
            Button { onOpen(item) } label: {
                GenerativeProductMedia(item: item, fillsFrame: item.id != anchor.id)
                    .frame(width: width, height: min(max(110, size.height - 228), width * 1.6))
            }
            .accessibilityLabel("View \(item.product.title)")
        }
        .frame(width: width)
    }
}

struct GenerativeComparisonComposition: View {
    let pair: [ResolvedStoryProduct]
    let remaining: [ResolvedStoryProduct]
    let selectedID: String?
    let size: CGSize
    let enabled: Bool
    let onSelect: (ResolvedStoryProduct) -> Void
    let onCompare: (ResolvedStoryProduct) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            HStack(alignment: .top, spacing: GravitySpacing.space12) {
                ForEach(pair) { item in
                    candidate(item, width: (size.width - 12) / 2)
                }
                if pair.count == 1 { Spacer(minLength: 0) }
            }
            if let insight = GenerativeDecisionContent.priceComparison(pair) {
                Text(insight)
                    .font(GravityFont.medium.fixedFont(size: 15))
                    .accessibilityIdentifier("generative.priceComparison")
            }
            ForEach(remaining) { item in
                Button { onCompare(item) } label: {
                    HStack(spacing: GravitySpacing.space12) {
                        GenerativeProductMedia(item: item, presentation: "comparison")
                            .frame(width: 64, height: 68)
                        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                            Text("Also on your shortlist")
                                .font(GravityFont.regular.fixedFont(size: 12)).foregroundStyle(.secondary)
                            Text(item.product.title)
                                .font(GravityFont.semiBold.fixedFont(size: 14)).lineLimit(2)
                            Text(GenerativeFeedStyle.price(item.product))
                                .font(GravityFont.regular.fixedFont(size: 13))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 16))
                    }
                    .multilineTextAlignment(.leading)
                    .padding(.top, GravitySpacing.space12)
                    .overlay(alignment: .top) { Rectangle().fill(.black.opacity(0.1)).frame(height: 1) }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Compare with \(item.product.title)")
                .accessibilityIdentifier("generative.compareAlternative")
            }
            Spacer(minLength: 0)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func candidate(_ item: ResolvedStoryProduct, width: CGFloat) -> some View {
        Button { onSelect(item) } label: {
            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                GenerativeProductMedia(item: item, presentation: "comparison")
                    .frame(height: min(width * 1.18, max(96, size.height - 248)))
                VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                    Text(GenerativeDecisionContent.name(item))
                        .font(GravityFont.semiBold.fixedFont(size: 16)).lineLimit(2)
                    Text(GenerativeDecisionContent.variant(item))
                        .font(GravityFont.regular.fixedFont(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                    Text(GenerativeFeedStyle.price(item.product))
                        .font(GravityFont.medium.fixedFont(size: 15))
                }
                .frame(height: 68, alignment: .topLeading)
                HStack(spacing: GravitySpacing.space4) {
                    Image(systemName: selectedID == item.id ? "checkmark.circle.fill" : "circle")
                    Text(selectedID == item.id ? "In focus" : "Take a look")
                }
                .font(GravityFont.medium.fixedFont(size: 12))
                .frame(minHeight: 28)
            }
            .frame(width: width, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Select \(item.product.title)")
        .accessibilityValue(GenerativeFeedStyle.price(item.product))
        .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])
    }
}

/// Display fragments are taken from the canonical title; never SKU aliases or
/// inferred dimensions/availability. Price deltas require a shared currency.
enum GenerativeDecisionContent {
    static func name(_ item: ResolvedStoryProduct) -> String {
        item.product.title.components(separatedBy: " - ").first ?? item.product.title
    }
    static func variant(_ item: ResolvedStoryProduct) -> String {
        let parts = item.product.title.components(separatedBy: " - ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " - ") : item.product.title
    }
    static func priceComparison(_ items: [ResolvedStoryProduct]) -> String? {
        guard items.count == 2, items[0].product.currencyCode == items[1].product.currencyCode,
              let first = Decimal(string: items[0].product.price),
              let second = Decimal(string: items[1].product.price) else { return nil }
        if first == second { return "Both \(GenerativeFeedStyle.price(items[0].product))." }
        let lower = first < second ? items[0] : items[1]
        let difference = abs(first - second).formatted(.currency(code: lower.product.currencyCode))
        return "\(variant(lower)) is \(difference) less."
    }
}
