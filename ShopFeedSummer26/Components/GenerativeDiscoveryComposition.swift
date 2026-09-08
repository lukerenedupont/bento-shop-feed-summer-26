import SwiftUI

/// Two entity-led compositions: a choice about use case, or a choice of shop.
/// Both change the content group, not an unrelated product rail elsewhere.
struct GenerativeDiscoveryComposition: View {
    let spec: NextGenerationFeedCardSpec
    let merchants: [SampleMerchant]
    let session: GenerativeFeedPrototypeSession
    let size: CGSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeGroup: PrototypeContentGroup? { session.activeGroup(for: spec) }
    private var enabled: Bool { session.state(for: spec).interactionsEnabled }

    var body: some View {
        if let group = activeGroup {
            focusedGroup(group)
        } else if spec.job == .narrow {
            HStack(alignment: .top, spacing: GravitySpacing.space12) {
                ForEach(spec.groups) { group in
                    Button { choose(group) } label: {
                        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                            GenerativeProductMedia(item: items(in: group).first)
                                .frame(height: max(size.height - 100, 120))
                            Text(group.title).font(GravityFont.semiBold.fixedFont(size: 18))
                            Text(group.context).font(GravityFont.regular.fixedFont(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: (size.width - 12) / 2, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .accessibilityIdentifier("generative.direction.\(group.id)")
                    .accessibilityLabel("Choose \(group.title)")
                }
            }
        } else {
            VStack(spacing: GravitySpacing.space16) {
                ForEach(spec.groups) { group in
                    Button { choose(group) } label: {
                        HStack(spacing: GravitySpacing.space16) {
                            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                                Text(group.title).font(GravityFont.expressiveSemiBold.fixedFont(size: 23))
                                Text(group.context).font(GravityFont.regular.fixedFont(size: 13))
                                    .foregroundStyle(.secondary).lineLimit(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            GenerativeProductMedia(item: items(in: group).first)
                                .frame(width: size.width * 0.32, height: max((size.height - 32) / 3, 88))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .accessibilityLabel("Explore \(group.title)")
                }
            }
        }
    }

    private func focusedGroup(_ group: PrototypeContentGroup) -> some View {
        let products = session.products(for: spec, merchants: merchants)
        let selected = session.selected(in: products, for: spec)
        return VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            if let merchantID = group.merchantID,
               let merchant = merchants.first(where: { $0.id == merchantID }) {
                HStack(spacing: GravitySpacing.space12) {
                    MerchantAvatarView(merchant: merchant, size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(merchant.displayName).font(GravityFont.semiBold.fixedFont(size: 20))
                        if spec.job == .discoverMerchants {
                            Text(merchant.description).font(GravityFont.regular.fixedFont(size: 12))
                                .foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }
            GenerativeProductMedia(item: selected)
                .frame(height: max(size.height - 205, 90))
            if let selected {
                Text(selected.product.title).font(GravityFont.semiBold.fixedFont(size: 15)).lineLimit(2)
                Text(GenerativeFeedStyle.price(selected.product)).font(GravityFont.medium.fixedFont(size: 14))
            }
            HStack(spacing: GravitySpacing.space8) {
                ForEach(products) { item in
                    Button { session.select(item, for: spec) } label: {
                        GenerativeProductMedia(item: item).frame(width: 52, height: 56)
                            .overlay {
                                RoundedRectangle(cornerRadius: GravityRadius.r16)
                                    .strokeBorder(selected?.id == item.id ? Color.black : .clear, lineWidth: 2)
                            }
                    }
                    .disabled(!enabled)
                    .accessibilityLabel("Select \(item.product.title)")
                    .accessibilityAddTraits(selected?.id == item.id ? .isSelected : [])
                }
            }
        }
    }

    private func items(in group: PrototypeContentGroup) -> [ResolvedStoryProduct] {
        group.products.compactMap { NextGenerationFeedCardSpec.resolve($0, in: merchants) }
    }
    private func choose(_ group: PrototypeContentGroup) {
        HapticFeedback.selection.fire()
        withAnimation(reduceMotion ? nil : SpringPreset.responsive) { session.choose(group, for: spec) }
    }
}
