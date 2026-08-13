import SwiftUI

/// Horizontal product shelf for agent conversation results.
/// Shows section header + scrollable product cards.
struct AgentProductShelf: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let section: AgentProductSection
    var onProductTap: ((AgentProduct) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            // Section header
            if let title = section.title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .gravityTextStyle(GravityTypography.subtitle)
                        .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentProductShelf.swift:foregroundStyle:_:16:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .lineLimit(2)

                    if let subtitle = section.subtitle {
                        Text(subtitle)
                            .gravityTextStyle(GravityTypography.bodySmall)
                            .foregroundStyle(PurlTune.token("Components/Search/Agent/AgentProductShelf.swift:foregroundStyle:_:22:46", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, PurlTune.token("Components/Search/Agent/AgentProductShelf.swift:padding:_:26:39", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                .padding(.horizontal, GravitySpacing.screenMargin)
            }

            // Horizontal product scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(section.products) { product in
                        Button {
                            HapticFeedback.light.fire()
                            onProductTap?(product)
                        } label: {
                            AgentProductCard(
                                imageURL: product.imageURL?.absoluteString,
                                merchantName: product.shopName,
                                productName: product.title,
                                rating: product.rating,
                                ratingCount: product.ratingCount,
                                price: product.price,
                                originalPrice: product.originalPrice
                            )
                            .frame(width: PurlTune.value("Components/Search/Agent/AgentProductShelf.swift:frame:width:47:43", default: 140))
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.95))
                    }
                }
                .padding(.horizontal, GravitySpacing.screenMargin)
            }
        }
    }
}

#Preview {
    AgentProductShelf(section: .preview)
        .padding(.vertical)
        .background(PurlTune.token("Components/Search/Agent/AgentProductShelf.swift:background:_:61:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
