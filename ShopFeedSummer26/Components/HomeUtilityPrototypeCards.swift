import SwiftUI

/// Shared tint decisions for the top-of-feed utility shelf so the rail cards
/// read correctly on both the light For You canvas and dark topic surfaces.
struct UtilityShelfPalette {
    let primary: Color
    let secondary: Color
    let controlFill: Color
    let surfaceFill: Color
    let surfaceBorder: Color

    init(onLightSurface: Bool) {
        let primary: Color = onLightSurface ? .black : .white
        self.primary = primary
        secondary = primary.opacity(0.62)
        controlFill = primary.opacity(onLightSurface ? 0.07 : 0.14)
        surfaceFill = onLightSurface ? .white : .black.opacity(0.40)
        surfaceBorder = primary.opacity(onLightSurface ? 0.08 : 0.18)
    }
}

/// Compact cart hand-off card for the utility rail.
struct CartSyncUtilityCard: View {
    let item: ResolvedStoryProduct
    let width: CGFloat
    let height: CGFloat
    let palette: UtilityShelfPalette
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            onTap()
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text(item.merchant.displayName.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined())
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.primary)
                        .frame(width: 38, height: 38)
                        .background(palette.controlFill, in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.merchant.displayName)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.primary)
                            .lineLimit(1)
                        Text("Subtotal \(formatPrice(item.product))")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    ProductImageView(product: item.product, merchant: item.merchant)
                        .frame(width: 60, height: 60)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            Text("1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(palette.primary)
                                .frame(width: 18, height: 18)
                                .background(palette.controlFill, in: Circle())
                                .offset(x: -6, y: -6)
                        }
                }

                Spacer(minLength: 10)

                Text("Continue to checkout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(palette.controlFill, in: Capsule())
            }
            .padding(GravitySpacing.space12)
            .frame(width: width, height: height)
            .utilityRailSurface(
                fill: palette.surfaceFill,
                border: palette.surfaceBorder
            )
        }
        .buttonStyle(.plain)
    }
}

/// PROTOTYPE — a feed-card-scale treatment of the same utility information as
/// the compact rail. It intentionally reuses the order, cart, and product
/// primitives so the two presentations can be compared without data drift.
/// Not in the live feed; switch `ForYouUtilityPresentation` to restore it.
struct FullHeightUtilityCard: View {
    let width: CGFloat
    let height: CGFloat
    let products: [ResolvedStoryProduct]
    let cartItem: ResolvedStoryProduct?
    let isActive: Bool

    @Environment(NavigationCoordinator.self) private var coordinator

    private var deliveryMerchants: [SampleMerchant] {
        var seen = Set<String>()
        return products
            .map(\.merchant)
            .filter { seen.insert($0.id).inserted && !$0.products.isEmpty }
    }

    var body: some View {
        let buyAgain = Array(products.dropFirst(3).prefix(3))
        let recentlyViewed = Array(products.prefix(4))

        return ZStack {
            LinearGradient(
                colors: [
                    deliveryMerchants.first?.brandColor.opacity(0.24) ?? Color.black.opacity(0.06),
                    Color(hex: 0xF2F1ED),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("Your Shop right now")
                    .feedCardTitleStyle()
                    .foregroundStyle(.black)
                    .lineLimit(2)

                if let merchant = deliveryMerchants.first {
                    orderSummary(merchant: merchant)
                }

                if let cartItem {
                    cartSummary(item: cartItem)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Buy again")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)

                    HStack(spacing: 8) {
                        ForEach(buyAgain) { item in
                            Button {
                                HapticFeedback.light.fire()
                                coordinator.pushRoute(
                                    .product(merchantId: item.merchant.id, productId: item.product.id)
                                )
                            } label: {
                                ProductCard(
                                    image: nil,
                                    imageURL: item.product.imageURL,
                                    priceBadge: formatPrice(item.product),
                                    showFavoriteButton: true
                                )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently viewed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)

                    HStack(spacing: 8) {
                        ForEach(recentlyViewed) { item in
                            Button {
                                HapticFeedback.light.fire()
                                coordinator.pushRoute(
                                    .product(merchantId: item.merchant.id, productId: item.product.id)
                                )
                            } label: {
                                ProductImageView(product: item.product, merchant: item.merchant)
                                    .frame(width: 58, height: 58)
                                    .background(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 0.5)
                                    }
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                }
            }
            .padding(20)
            .opacity(isActive ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isActive)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                .strokeBorder(.white.opacity(0.24), lineWidth: 0.5)
        }
        .gravityShadow(GravityShadows.medium)
    }

    private func orderSummary(merchant: SampleMerchant) -> some View {
        let deliveryProducts = Array(merchant.products.prefix(2))

        return Button {
            HapticFeedback.light.fire()
            coordinator.navigateToPage(1)
        } label: {
            HStack(spacing: 10) {
                MerchantLogoImage(merchant: merchant, size: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(merchant.displayName)
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.58))
                    Text("Arriving today 3–6pm")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.78)

                Spacer(minLength: 2)

                HStack(spacing: 5) {
                    ForEach(deliveryProducts) { product in
                        ProductImageView(product: product, merchant: merchant)
                            .frame(width: 44, height: 44)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
            .padding(12)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    private func cartSummary(item: ResolvedStoryProduct) -> some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.navigateToPage(4)
        } label: {
            HStack(spacing: 12) {
                ProductImageView(product: item.product, merchant: item.merchant)
                    .frame(width: 64, height: 64)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cart ready")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("Subtotal \(formatPrice(item.product))")
                        .font(.system(size: 14))
                        .foregroundStyle(.black.opacity(0.58))
                }

                Spacer(minLength: 4)

                Text("Checkout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(.black, in: Capsule())
            }
            .padding(12)
            .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
