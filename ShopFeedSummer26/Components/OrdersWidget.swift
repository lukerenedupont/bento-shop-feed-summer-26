import SwiftUI

/// Compact delivery widget for the home top bar.
/// Shows fanned product images + delivery status text.
/// Only appears when there's a delivery arriving within a day.
struct OrdersWidget: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let delivery: DeliveryItem
    let merchant: SampleMerchant?

    /// Animate the fan + text in on appear.
    @State private var appeared = false

    private var arrivalText: String {
        switch delivery.status {
        case .outForDelivery(let headline): return headline
        case .inTransit(let headline): return headline
        case .labelCreated(let headline): return headline
        case .delivered(let date): return "Delivered \(date)"
        }
    }

    private var merchantName: String {
        merchant?.name ?? "Order"
    }

    var body: some View {
        HStack(spacing: GravitySpacing.space4) {
            // Fanned product images
            productFan
                .frame(width: PurlTune.value("Components/OrdersWidget.swift:frame:width:30:31", default: 52), height: PurlTune.value("Components/OrdersWidget.swift:frame:height:30:119", default: 42))

            // Text stack
            VStack(alignment: .leading, spacing: 0) {
                Text(merchantName)
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Components/OrdersWidget.swift:foregroundStyle:_:36:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)

                Text(arrivalText)
                    .gravityTextStyle(GravityTypography.captionBold)
                    .foregroundStyle(PurlTune.token("Components/OrdersWidget.swift:foregroundStyle:_:41:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .lineLimit(1)
            }
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : -8)
            .animation(.spring(response: PurlTune.value("Components/OrdersWidget.swift:spring:response:46:42", default: 0.5), dampingFraction: PurlTune.value("Components/OrdersWidget.swift:spring:dampingFraction:46:144", default: 0.75)).delay(0.15), value: appeared)
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }

    // MARK: - Product Fan

    private var productFan: some View {
        let products = delivery.products.prefix(2)

        return ZStack {
            // Back image — tilted +15°
            if products.count > 0 {
                productThumb(product: products[products.startIndex], index: 0)
                    .rotationEffect(.degrees(appeared ? -8 : 8))
                    .offset(x: appeared ? -6 : 0, y: appeared ? 0 : -2)
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .animation(
                        .spring(response: PurlTune.value("Components/OrdersWidget.swift:spring:response:68:43", default: 0.55), dampingFraction: PurlTune.value("Components/OrdersWidget.swift:spring:dampingFraction:68:146", default: 0.65)).delay(0.05),
                        value: appeared
                    )
            }

            // Front image — tilted -15°
            if products.count > 1 {
                productThumb(product: products[products.index(after: products.startIndex)], index: 1)
                    .rotationEffect(.degrees(appeared ? 8 : -8))
                    .offset(x: appeared ? 6 : 0, y: appeared ? 0 : 2)
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .animation(
                        .spring(response: PurlTune.value("Components/OrdersWidget.swift:spring:response:80:43", default: 0.55), dampingFraction: PurlTune.value("Components/OrdersWidget.swift:spring:dampingFraction:80:146", default: 0.65)).delay(0.1),
                        value: appeared
                    )
            }
        }
    }

    private func productThumb(product: SampleMerchant.Product, index: Int) -> some View {
        ProductFanThumb(imageURL: product.imageURL)
    }
}

// MARK: - Reusable Product Fan Thumb

/// A single 32×32 product image thumbnail with rounded corners, border, and shadow.
struct ProductFanThumb: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let imageURL: String?

    var body: some View {
        Group {
            if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Color(white: 0.95)
                    }
                }
            } else {
                Color(white: 0.95)
            }
        }
        .frame(width: PurlTune.value("Components/OrdersWidget.swift:frame:width:115:23", default: 32), height: PurlTune.value("Components/OrdersWidget.swift:frame:height:115:112", default: 32))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(PurlTune.value("Components/OrdersWidget.swift:opacity:_:124:47", default: 0.08)), radius: PurlTune.value("Components/OrdersWidget.swift:shadow:radius:124:137", default: 4), x: PurlTune.value("Components/OrdersWidget.swift:shadow:x:124:223", default: 0), y: PurlTune.value("Components/OrdersWidget.swift:shadow:y:124:304", default: 2))
        )
    }
}

/// A static (non-animated) fanned pair of product images. Reusable in cards/lists.
struct ProductFanView: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let products: [SampleMerchant.Product]

    var body: some View {
        let items = Array(products.prefix(2))
        ZStack {
            if items.count > 0 {
                ProductFanThumb(imageURL: items[0].imageURL)
                    .rotationEffect(.degrees(-8))
                    .offset(x: PurlTune.value("Components/OrdersWidget.swift:offset:x:139:32", default: -6))
            }
            if items.count > 1 {
                ProductFanThumb(imageURL: items[1].imageURL)
                    .rotationEffect(.degrees(8))
                    .offset(x: PurlTune.value("Components/OrdersWidget.swift:offset:x:144:32", default: 6))
            }
        }
        .frame(width: PurlTune.value("Components/OrdersWidget.swift:frame:width:147:23", default: 52), height: PurlTune.value("Components/OrdersWidget.swift:frame:height:147:112", default: 42))
    }
}

// MARK: - Helper: Get the soonest active delivery

extension DeliveryItem {
    /// Returns the soonest delivery that's arriving within ~1 day, if any.
    @MainActor
    static var soonestArriving: DeliveryItem? {
        active.first { item in
            switch item.status {
            case .outForDelivery: return true
            case .inTransit: return true
            default: return false
            }
        }
    }
}

// MARK: - Preview

#Preview("Orders Widget") {
    let delivery = DeliveryItem.active[0]
    let merchant = SampleMerchant.byId[delivery.merchantId]
    OrdersWidget(delivery: delivery, merchant: merchant)
        .padding()
        .background(Color(.systemBackground))
}
