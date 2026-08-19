import SwiftUI

/// Full search results list page — shown after tapping "View more" on the quick search card.
/// Vertical list of product cards with filter chips at top.
struct SearchResultsPage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let products: [AgentProduct]
    var onProductTap: ((AgentProduct) -> Void)? = nil
    var namespace: Namespace.ID? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: AgentProduct?

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: GravitySpacing.space8) {
                    ForEach(products) { product in
                        Button {
                            HapticFeedback.light.fire()
                            selectedProduct = product
                        } label: {
                            searchResultRow(product)
                        }
                        .buttonStyle(PressScaleButtonStyle(scale: 0.98))
                    }
                }
                .padding(.horizontal, GravitySpacing.screenMargin)
                .padding(.top, PurlTune.value("Pages/Search/SearchResultsPage.swift:padding:_:27:32", default: 64)) // room for chips
                .padding(.bottom, PurlTune.value("Pages/Search/SearchResultsPage.swift:padding:_:28:35", default: 120))
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.5),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:height:44:36", default: 100))
                    .ignoresSafeArea(edges: .top)
            }
            
            filterChips
        }
        .background(PurlTune.token("Pages/Search/SearchResultsPage.swift:background:_:50:21", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedProduct) { product in
            if let ns = namespace {
                ProductPage(
                    agentProduct: product,
                    namespace: ns
                )
            }
        }
        .purlInjectable()
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GravitySpacing.space4) {
                filterChip {
                    GravityIcon.filter.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:width:72:39", default: 16), height: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:height:72:134", default: 16))
                        .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:73:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                }

                filterChip {
                    HStack(spacing: 4) {
                        Text("Sells from")
                            .gravityTextStyle(GravityTypography.buttonMedium)
                            .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:80:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        Text("🇺🇸").font(.system(size: 14))
                    }
                }

                filterChip {
                    Text("Your deals")
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:88:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                }

                filterChip {
                    Text("Following")
                        .gravityTextStyle(GravityTypography.buttonMedium)
                        .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:94:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                }
            }
            .padding(.horizontal, GravitySpacing.screenMargin)
            .padding(.vertical, PurlTune.token("Pages/Search/SearchResultsPage.swift:padding:_:98:33", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
        }
    }

    private func filterChip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Button(action: {}) {
            content()
                .padding(.horizontal, PurlTune.token("Pages/Search/SearchResultsPage.swift:padding:_:105:39", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                .padding(.vertical, PurlTune.token("Pages/Search/SearchResultsPage.swift:padding:_:106:37", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                .background(GravityColors.bgFillFloat, in: Capsule())
                .overlay(
                    Capsule().stroke(GravityColors.borderSecondary, lineWidth: 0.5)
                )
        }
        .gravityShadow(GravityShadows.small)
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
    }

    private func searchResultRow(_ product: AgentProduct) -> some View {
        HStack(spacing: 8) {
            // Product image — 108×108, r20
            ZStack(alignment: .bottomTrailing) {
                Color.white
                    .frame(width: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:width:121:35", default: 108), height: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:height:121:132", default: 108))
                    .overlay {
                        if let url = product.imageURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Rectangle().fill(PurlTune.token("Pages/Search/SearchResultsPage.swift:fill:_:129:54", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                }
                            }
                        }
                    }
                    .overlay { Color.black.opacity(PurlTune.value("Pages/Search/SearchResultsPage.swift:opacity:_:134:52", default: 0.04)) }
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))

                // Favorite button
                ProductFavoriteButton()
                .padding(PurlTune.value("Pages/Search/SearchResultsPage.swift:padding:_:151:26", default: 6))
            }

            // Right side — space-between vertically
            VStack(alignment: .leading, spacing: 0) {
                // Top: title, rating, price
                VStack(alignment: .leading, spacing: 0) {
                    Text(product.title)
                        .gravityTextStyle(GravityTypography.captionBold)
                        .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:160:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        .lineLimit(1)

                    if let rating = product.rating, let count = product.ratingCount, count > 0 {
                        HStack(spacing: 2) {
                            HStack(spacing: 0) {
                                ForEach(0..<5) { i in
                                    GravityIcon.starFilled.image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:width:170:55", default: 12), height: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:height:170:151", default: 12))
                                        .foregroundStyle(
                                            Double(i) < rating
                                                ? Color(hex: 0xFFB800)
                                                : GravityColors.bgFillSecondary
                                        )
                                }
                            }
                            Text("(\(count))")
                                .gravityTextStyle(GravityTypography.caption)
                                .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:180:50", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                        }
                    }

                    Text(product.price)
                        .gravityTextStyle(GravityTypography.captionMedium)
                        .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:186:42", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                }

                Spacer(minLength: 0)

                // Bottom: merchant avatar + name
                HStack(spacing: 8) {
                    Group {
                        if let url = product.shopLogoURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                default:
                                    Circle().fill(PurlTune.token("Pages/Search/SearchResultsPage.swift:fill:_:200:51", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                        .overlay(
                                            Text(String((product.shopName ?? "S").prefix(1)).uppercased())
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:204:66", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                                        )
                                }
                            }
                        } else {
                            Circle().fill(PurlTune.token("Pages/Search/SearchResultsPage.swift:fill:_:209:43", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                .overlay(
                                    Text(String((product.shopName ?? "S").prefix(1)).uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:213:58", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                                )
                        }
                    }
                    .frame(width: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:width:217:35", default: 24), height: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:height:217:131", default: 24))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(GravityColors.borderImage, lineWidth: 0.5))

                    if let name = product.shopName {
                        Text(name)
                            .gravityTextStyle(GravityTypography.badgeBold)
                            .foregroundStyle(PurlTune.token("Pages/Search/SearchResultsPage.swift:foregroundStyle:_:224:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
            .padding(PurlTune.value("Pages/Search/SearchResultsPage.swift:padding:_:231:22", default: 4))
            .frame(height: PurlTune.value("Pages/Search/SearchResultsPage.swift:frame:height:232:28", default: 108))
        }
        .padding(PurlTune.value("Pages/Search/SearchResultsPage.swift:padding:_:234:18", default: 8))
        .background(GravityColors.bgFill, in: RoundedRectangle(cornerRadius: GravityRadius.r28))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r28)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
    }
}

#Preview {
    NavigationStack {
        SearchResultsPage(products: AgentProduct.previews(limit: 12))
    }
    .environment(NavigationCoordinator())
}
