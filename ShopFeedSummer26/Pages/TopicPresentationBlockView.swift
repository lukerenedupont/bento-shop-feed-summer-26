import SwiftUI

/// Renders every authored Figma block through one interface. Topic-specific
/// files provide data, never another view hierarchy.
struct TopicPresentationBlockView: View {
    let block: AuthoredTopicBlock
    let surfaceColor: Color

    var body: some View {
        switch block {
        case .products(let title, let products):
            titled(title, spacing: GravitySpacing.space16) {
                productRail(products)
            }
        case .cards(let title, let prefix, let count, let width, let height):
            titled(title, spacing: GravitySpacing.space16) {
                cardRail(prefix: prefix, count: count, width: width, height: height)
            }
        case .categories(let title, let categories):
            titled(title, spacing: GravitySpacing.space12) {
                categoryRail(categories)
            }
        case .mosaic(let title, let prefix, let largeHeight, let smallHeight):
            titled(title, spacing: GravitySpacing.space12) {
                mosaicRail(prefix: prefix, largeHeight: largeHeight, smallHeight: smallHeight)
            }
        case .explore(let title, let filters, let products):
            explore(title: title, filters: filters, products: products)
        }
    }

    private func titled<Content: View>(
        _ title: String,
        spacing: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            sectionTitle(title)
            content()
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: GravitySpacing.space6) {
            Text(title)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
        }
        .font(GravityFont.expressiveBold.fixedFont(size: 20))
        .tracking(-0.45)
        .foregroundStyle(.white)
        .padding(.horizontal, GravitySpacing.space12)
    }

    private func productRail(_ products: [AuthoredTopicProduct]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                ForEach(products) { product in
                    ProductCard(
                        image: Image(product.asset),
                        imageURL: nil,
                        merchantName: product.merchant,
                        productName: product.title,
                        price: product.price,
                        showFavoriteButton: true,
                        favoriteIconHasContrastShadow: true
                    )
                    .frame(width: 116)
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
    }

    private func cardRail(
        prefix: String,
        count: Int,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: GravitySpacing.space10) {
                ForEach(1...count, id: \.self) { index in
                    Button { HapticFeedback.light.fire() } label: {
                        Image("\(prefix)-\(index)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: width, height: height)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
    }

    private func categoryRail(_ categories: [AuthoredTopicCategory]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: GravitySpacing.space10) {
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                        VStack(spacing: GravitySpacing.space8) {
                            HStack(spacing: GravitySpacing.space8) {
                                categoryTile(category.assets[0], size: 136)
                                categoryTile(category.assets[1], size: 136)
                            }
                            HStack(spacing: GravitySpacing.space8) {
                                ForEach(Array(category.assets.dropFirst(2)), id: \.self) {
                                    categoryTile($0, size: 88)
                                }
                            }
                        }
                        HStack(spacing: 4) {
                            Text(category.title)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .font(GravityFont.bold.fixedFont(size: 18))
                        .foregroundStyle(.white)
                    }
                    .padding(GravitySpacing.space12)
                    .frame(width: 304, height: 288, alignment: .topLeading)
                    .background(
                        Color.white.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    )
                }
            }
            .padding(.horizontal, GravitySpacing.space12)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
    }

    private func categoryTile(_ asset: String, size: CGFloat) -> some View {
        Image(asset)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
    }

    private func mosaicRail(prefix: String, largeHeight: CGFloat, smallHeight: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space8) {
                mosaicTile("\(prefix)-1", width: 240, height: largeHeight)
                VStack(spacing: GravitySpacing.space8) {
                    HStack(spacing: GravitySpacing.space8) {
                        mosaicTile("\(prefix)-2", width: 117, height: smallHeight)
                        mosaicTile("\(prefix)-3", width: 117, height: smallHeight)
                    }
                    HStack(spacing: GravitySpacing.space8) {
                        mosaicTile("\(prefix)-4", width: 117, height: smallHeight)
                        mosaicTile("\(prefix)-5", width: 117, height: smallHeight)
                    }
                }
                mosaicTile("\(prefix)-6", width: 240, height: largeHeight)
            }
            .padding(.horizontal, GravitySpacing.space12)
        }
    }

    private func mosaicTile(_ asset: String, width: CGFloat, height: CGFloat) -> some View {
        Image(asset)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
    }

    private func explore(
        title: String,
        filters: [String],
        products: [AuthoredTopicProduct]
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(filters, id: \.self) { label in
                        Text(label)
                            .font(GravityFont.semiBold.fixedFont(size: 14))
                            .foregroundStyle(label == filters.first ? surfaceColor : .white)
                            .padding(.horizontal, GravitySpacing.space16)
                            .frame(height: 36)
                            .background(
                                label == filters.first ? Color.white : Color.white.opacity(0.14),
                                in: Capsule()
                            )
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
            }
            HStack(alignment: .top, spacing: GravitySpacing.space8) {
                exploreColumn(Array(products.enumerated()).filter { $0.offset.isMultiple(of: 2) })
                exploreColumn(Array(products.enumerated()).filter { !$0.offset.isMultiple(of: 2) })
            }
            .padding(.horizontal, GravitySpacing.space12)
        }
    }

    private func exploreColumn(
        _ items: [(offset: Int, element: AuthoredTopicProduct)]
    ) -> some View {
        VStack(spacing: GravitySpacing.space16) {
            ForEach(items, id: \.element.id) { index, product in
                VStack(alignment: .leading, spacing: 5) {
                    Image(product.asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 185, height: exploreHeight(index: index, asset: product.asset))
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                    Text(product.merchant).font(GravityFont.medium.fixedFont(size: 11))
                    Text(product.title).font(GravityFont.semiBold.fixedFont(size: 12)).lineLimit(2)
                    Text(product.price).font(GravityFont.bold.fixedFont(size: 12))
                }
                .foregroundStyle(.white)
                .frame(width: 185, alignment: .leading)
            }
        }
    }

    private func exploreHeight(index: Int, asset: String) -> CGFloat {
        if asset.hasPrefix("sneaker-") {
            return index.isMultiple(of: 3) ? 185 : 221
        }
        return index.isMultiple(of: 3) ? 220 : 185
    }
}
