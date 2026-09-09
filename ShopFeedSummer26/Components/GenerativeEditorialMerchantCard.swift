import SwiftUI

/// PROTOTYPE — bring merchant discovery into the authored topic-card language:
/// shared heavy display type, an editorial cover composition, one product handoff.
struct GenerativeEditorialMerchantCard: View {
    let spec: NextGenerationFeedCardSpec
    let products: [ResolvedStoryProduct]
    let session: GenerativeFeedPrototypeSession
    let width: CGFloat
    let height: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let onInspect: () -> Void
    let onOpen: (ResolvedStoryProduct) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selected: ResolvedStoryProduct? { session.selected(in: products, for: spec) }
    private var enabled: Bool { session.state(for: spec).interactionsEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            HStack(alignment: .top) {
                Text(spec.groups.first?.title ?? spec.title)
                    .feedCardTitleStyle()
                    .frame(maxWidth: width * 0.65, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("generative.heading")
                    .contentShape(Rectangle())
                    .onLongPressGesture(perform: onInspect)
                    .accessibilityAction(named: "Inspect demo context", onInspect)
                Spacer(minLength: 0)
                if session.designMode {
                    Button(action: onInspect) {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Inspect this shopping experience")
                    .accessibilityIdentifier("generative.inspector")
                }
            }
            GeometryReader { proxy in
                ZStack {
                    ForEach(Array(products.enumerated()), id: \.element.id) { index, item in
                        let focused = selected?.id == item.id
                        let others = products.filter { $0.id != selected?.id }
                        let side = others.first?.id == item.id ? -1.0 : 1.0
                        Button {
                            session.select(item, for: spec)
                            HapticFeedback.selection.fire()
                        } label: {
                            EditorialManualCover(item: item)
                                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 12)
                        }
                        .buttonStyle(.plain)
                        .frame(width: proxy.size.width * (focused ? 0.69 : 0.48),
                               height: proxy.size.height * (focused ? 0.86 : 0.70))
                        .rotationEffect(.degrees(reduceMotion ? 0 : focused ? -5 : side * 13))
                        .position(x: proxy.size.width * (focused ? 0.5 : side < 0 ? 0.23 : 0.78),
                                  y: proxy.size.height * (focused ? 0.58 : 0.35))
                        .zIndex(focused ? 3 : Double(index) * 0.1)
                        .disabled(!enabled)
                        .accessibilityLabel("Select \(item.product.title)")
                        .accessibilityAddTraits(focused ? .isSelected : [])
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .accessibilityIdentifier("generative.editorialBooks")
            .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: selected?.id)

            if let merchant = products.first?.merchant {
                HStack(spacing: GravitySpacing.space8) {
                    MerchantAvatarView(merchant: merchant, size: 28)
                    Text(merchant.displayName).font(GravityFont.semiBold.fixedFont(size: 14))
                }
            }
            if let selected {
                Button { onOpen(selected) } label: {
                    HStack(spacing: GravitySpacing.space16) {
                        VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                            Text(selected.product.title)
                                .font(GravityFont.semiBold.fixedFont(size: 16)).lineLimit(2)
                            Text(GenerativeFeedStyle.price(selected.product))
                                .font(GravityFont.medium.fixedFont(size: 14)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.07), in: Circle())
                    }
                    .multilineTextAlignment(.leading)
                    .contentShape(Rectangle())
                    .frame(minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View \(selected.product.title)")
                .accessibilityIdentifier("generative.primaryAction")
            }
        }
        .padding(.horizontal, GravitySpacing.space20)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(width: width, height: height)
        .foregroundStyle(.black)
    }
}

/// Art-directed crops of the three frozen, canonical studio photographs.
/// Coordinates remove only photographic background, not the printed covers.
/// No generated artwork, substitute SKU, remote fetch or extra bundled media.
private struct EditorialManualCover: View {
    let item: ResolvedStoryProduct
    private var cover: UIImage? {
        guard item.merchant.id == "standards-manual",
              let rect = Self.crops[String(item.product.id)],
              let url = Bundle.main.url(forResource: "prototype-product-\(item.merchant.id)-\(item.product.id)", withExtension: "jpg"),
              let source = UIImage(contentsOfFile: url.path)?.cgImage,
              let cropped = source.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped)
    }
    // Pixel bounds in the verified 840×560 source photographs.
    private static let crops: [String: CGRect] = [
        "1424479363": CGRect(x: 189, y: 51, width: 453, height: 455),
        "5842516163": CGRect(x: 231, y: 51, width: 374, height: 453),
        "92039479320": CGRect(x: 230, y: 51, width: 377, height: 455)
    ]
    var body: some View {
        if let cover {
            Image(uiImage: cover).resizable().scaledToFit().accessibilityHidden(true)
        } else {
            GenerativeProductMedia(item: item)
        }
    }
}
