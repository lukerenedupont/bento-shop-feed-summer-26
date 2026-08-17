import SwiftUI

/// Account page — profile header, saved/following, recently viewed, order history, payment methods.
struct AccountPage: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var userProfile = UserProfileService.shared
    @State private var showSettings = false
    let namespace: Namespace.ID

    @ObservedObject private var merchantService = RemoteMerchantService.shared
    private var merchants: [SampleMerchant] { merchantService.merchants }

    private var savedProducts: [(SampleMerchant, SampleMerchant.Product)] {
        merchants
            .flatMap { m in m.products.compactMap { p in p.imageURL != nil ? (m, p) : nil } }
            .prefix(5)
            .map { $0 }
    }

    private var followingMerchants: [SampleMerchant] {
        Array(merchants.prefix(5))
    }

    private var recentlyViewedProducts: [(SampleMerchant, SampleMerchant.Product)] {
        merchants
            .flatMap { m in m.products.compactMap { p in p.imageURL != nil ? (m, p) : nil } }
            .dropFirst(5)
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: GravitySpacing.space24) {
                savedFollowingRow
                    .padding(.top, PurlTune.token("Pages/AccountPage.swift:padding:_:36:36", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                recentlyViewedSection
                orderHistorySection
                paymentMethodsSection
                signOutButton
            }
            .padding(.horizontal, PurlTune.token("Pages/AccountPage.swift:padding:_:42:35", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.bottom, PurlTune.value("Pages/AccountPage.swift:padding:_:43:31", default: 120))
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, offset in
            coordinator.updateScrollOffset(offset)
        }
        .background(PurlTune.token("Pages/AccountPage.swift:background:_:50:21", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
        .safeAreaBar(edge: .top) {
            topBar
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTransition(.zoom(sourceID: "account-avatar", in: namespace))
        .sheet(isPresented: $showSettings) {
            SettingsPage()
        }
        .purlInjectable()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: GravitySpacing.space12) {
            ZStack {
                if let avatarURL = userProfile.avatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle().fill(shopGradient)
                                .overlay(
                                    Text(userProfile.initial)
                                        .gravityTextStyle(GravityTypography.bodyTitleLarge)
                                        .foregroundStyle(.white)
                                )
                        }
                    }
                } else {
                    Image("luke-avatar")
                        .resizable()
                        .scaledToFill()
                }
            }
                .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:91:31", default: 44), height: PurlTune.value("Pages/AccountPage.swift:frame:height:91:113", default: 44))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(userProfile.displayName)
                    .gravityTextStyle(GravityTypography.sectionTitle)
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:97:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                HStack(spacing: 2) {
                    Text("View profile")
                        .gravityTextStyle(GravityTypography.caption)
                        .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:101:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                    GravityIcon.rightChevron.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:105:39", default: 12), height: PurlTune.value("Pages/AccountPage.swift:frame:height:105:122", default: 12))
                        .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:106:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                }
            }

            Spacer()

            Button {
                HapticFeedback.light.fire()
                showSettings = true
            } label: {
                GravityIcon.settingsFilled.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:119:35", default: 20), height: PurlTune.value("Pages/AccountPage.swift:frame:height:119:118", default: 20))
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:120:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:121:35", default: 44), height: PurlTune.value("Pages/AccountPage.swift:frame:height:121:118", default: 44))
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        }
        .padding(.horizontal, GravitySpacing.screenMargin)
        .padding(.bottom, PurlTune.token("Pages/AccountPage.swift:padding:_:127:27", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
    }

    // MARK: - Saved + Following

    private var savedFollowingRow: some View {
        HStack(spacing: GravitySpacing.space8) {
            savedCard
            followingCard
        }
    }

    private var savedCard: some View {
        VStack(spacing: GravitySpacing.space12) {
            HStack(spacing: -12) {
                let rotations: [Double] = [0, -5, 3, -8, 6]
                ForEach(Array(savedProducts.enumerated()), id: \.element.1.id) { index, pair in
                    productThumbnail(imageURL: pair.1.imageURL)
                        .rotationEffect(.degrees(rotations[index % rotations.count]))
                }
                Spacer(minLength: 0)
            }
            .padding(.top, PurlTune.token("Pages/AccountPage.swift:padding:_:149:28", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
            .padding(.trailing, PurlTune.token("Pages/AccountPage.swift:padding:_:150:33", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))

            HStack {
                Text("Saved")
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:155:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                Spacer()
                GravityIcon.arrowRight.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:160:35", default: 16), height: PurlTune.value("Pages/AccountPage.swift:frame:height:160:118", default: 16))
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:161:38", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
            }
            .padding(.horizontal, PurlTune.token("Pages/AccountPage.swift:padding:_:163:35", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        }
        .padding(PurlTune.token("Pages/AccountPage.swift:padding:_:165:18", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Pages/AccountPage.swift:background:_:166:21", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
    }

    private var followingCard: some View {
        VStack(spacing: GravitySpacing.space12) {
            HStack(spacing: -12) {
                let rotations: [Double] = [0, -5, 3, -8, 6]
                ForEach(Array(followingMerchants.enumerated()), id: \.element.id) { index, merchant in
                    MerchantAvatarView(merchant: merchant, size: 32, shape: .roundedRect(cornerRadius: GravityRadius.r8))
                        .gravityShadow(GravityShadows.small)
                        .rotationEffect(.degrees(rotations[index % rotations.count]))
                }
                Spacer(minLength: 0)
            }
            .padding(.top, PurlTune.token("Pages/AccountPage.swift:padding:_:186:28", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
            .padding(.trailing, PurlTune.token("Pages/AccountPage.swift:padding:_:187:33", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))

            HStack {
                Text("Following")
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:192:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                Spacer()
                GravityIcon.arrowRight.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:197:35", default: 16), height: PurlTune.value("Pages/AccountPage.swift:frame:height:197:118", default: 16))
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:198:38", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
            }
            .padding(.horizontal, PurlTune.token("Pages/AccountPage.swift:padding:_:200:35", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
        }
        .padding(PurlTune.token("Pages/AccountPage.swift:padding:_:202:18", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
        .background(PurlTune.token("Pages/AccountPage.swift:background:_:203:21", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
    }

    private func productThumbnail(imageURL: String?) -> some View {
        Group {
            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Rectangle().fill(PurlTune.token("Pages/AccountPage.swift:fill:_:220:42", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                    }
                }
            } else {
                Rectangle().fill(PurlTune.token("Pages/AccountPage.swift:fill:_:224:34", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
            }
        }
        .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:227:23", default: 32), height: PurlTune.value("Pages/AccountPage.swift:frame:height:227:106", default: 32))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r8, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .gravityShadow(GravityShadows.small)
    }

    // MARK: - Recently Viewed (no card wrapper, horizontal ProductCard rail)

    private var recentlyViewedSection: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionHeader(title: "Recently viewed")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(recentlyViewedProducts, id: \.1.id) { merchant, product in
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(.product(merchantId: merchant.id, productId: product.id))
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: product.imageURL,
                                showFavoriteButton: true
                            )
                            .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:254:43", default: 120))
                            .matchedTransitionSource(id: product.id, in: namespace)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Order History (title outside card, matches Figma)

    private var orderHistorySection: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionHeader(title: "Order history")

            VStack(spacing: GravitySpacing.space16) {
                ForEach(Array(DeliveryItem.past.prefix(3).enumerated()), id: \.element.id) { index, item in
                    if let merchant = SampleMerchant.byId[item.merchantId] {
                        if index > 0 {
                            Divider().foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:275:55", default: GravityColors.border, options: GravityColors.purlTuneColorOptions))
                        }
                        orderRow(item: item, merchant: merchant)
                    }
                }
            }
            .padding(PurlTune.token("Pages/AccountPage.swift:padding:_:281:22", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .background(PurlTune.token("Pages/AccountPage.swift:background:_:282:25", default: GravityColors.bgFill, options: GravityColors.purlTuneColorOptions))
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                    .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
            )
            .gravityShadow(GravityShadows.small)
        }
    }

    private func orderRow(item: DeliveryItem, merchant: SampleMerchant) -> some View {
        HStack(spacing: GravitySpacing.space8) {
            // Merchant avatar + info
            MerchantAvatarView(merchant: merchant, size: 32)

            VStack(alignment: .leading, spacing: 0) {
                Text(merchant.name)
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:300:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                Text(item.statusSubtitle)
                    .gravityTextStyle(GravityTypography.caption)
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:303:38", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
            }

            Spacer()

            // Product thumbnails on the right
            HStack(spacing: -8) {
                ForEach(Array(item.products.prefix(3).enumerated()), id: \.element.id) { index, product in
                    if let urlString = product.imageURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                            default:
                                Rectangle().fill(PurlTune.token("Pages/AccountPage.swift:fill:_:317:50", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                            }
                        }
                        .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:320:39", default: 24), height: PurlTune.value("Pages/AccountPage.swift:frame:height:320:122", default: 24))
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    }
                }
                if item.products.count > 3 {
                    Text("+\(item.products.count - 3)")
                        .gravityTextStyle(GravityTypography.bodyTitleSmall)
                        .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:328:42", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                        .padding(.leading, PurlTune.token("Pages/AccountPage.swift:padding:_:329:44", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
                }
            }
        }
    }

    // MARK: - Payment Methods (ShopPlayground style cards)

    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space12) {
            sectionHeader(title: "Payment methods")

            ZStack(alignment: .top) {
                mastercardView
                shopCashCard
                    .padding(.top, PurlTune.value("Pages/AccountPage.swift:padding:_:344:36", default: 44))
            }

            Button {} label: {
                Text("Add card")
                    .gravityTextStyle(GravityTypography.bodyTitleSmall)
                    .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:350:38", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, PurlTune.token("Pages/AccountPage.swift:padding:_:352:41", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))
                    .background(PurlTune.token("Pages/AccountPage.swift:background:_:353:33", default: GravityColors.bgOverlayFixedDark04, options: GravityColors.purlTuneColorOptions))
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var mastercardView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1A1A2E), Color(hex: 0x2D2D44)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: GravitySpacing.space12) {
                HStack(spacing: GravitySpacing.space8) {
                    ZStack {
                        Circle().fill(Color(hex: 0xEB001B)).frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:374:74", default: 15), height: PurlTune.value("Pages/AccountPage.swift:frame:height:374:157", default: 15))
                        Circle().fill(Color(hex: 0xF79E1B)).frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:375:74", default: 15), height: PurlTune.value("Pages/AccountPage.swift:frame:height:375:157", default: 15))
                            .offset(x: PurlTune.value("Pages/AccountPage.swift:offset:x:376:40", default: 10))
                    }
                    .frame(width: PurlTune.value("Pages/AccountPage.swift:frame:width:378:35", default: 24), height: PurlTune.value("Pages/AccountPage.swift:frame:height:378:118", default: 15))
                    Text("••••  3515")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(PurlTune.value("Pages/AccountPage.swift:padding:_:385:22", default: 16))
        }
        .frame(height: PurlTune.value("Pages/AccountPage.swift:frame:height:387:24", default: 206))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(GravityColors.borderImage, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(PurlTune.value("Pages/AccountPage.swift:opacity:_:393:39", default: 0.16)), radius: PurlTune.value("Pages/AccountPage.swift:shadow:radius:393:123", default: 24), x: PurlTune.value("Pages/AccountPage.swift:shadow:x:393:204", default: 0), y: PurlTune.value("Pages/AccountPage.swift:shadow:y:393:279", default: 4))
    }

    private var shopCashCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x5433EB),
                            Color(hex: 0x785BF2),
                            Color(hex: 0x9C83F8),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shop Cash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Spend anywhere you pay with Shop")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(PurlTune.value("Pages/AccountPage.swift:opacity:_:418:57", default: 0.75)))
                }

                Spacer()

                Text("$5.00")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.white)
                    .tracking(-1.5)
            }
            .padding(.horizontal, PurlTune.value("Pages/AccountPage.swift:padding:_:428:35", default: 22))
            .padding(.top, PurlTune.value("Pages/AccountPage.swift:padding:_:429:28", default: 16))
            .padding(.bottom, PurlTune.value("Pages/AccountPage.swift:padding:_:430:31", default: 20))
        }
        .frame(height: PurlTune.value("Pages/AccountPage.swift:frame:height:432:24", default: 160))
        .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous)
                .strokeBorder(.white.opacity(PurlTune.value("Pages/AccountPage.swift:opacity:_:436:46", default: 0.15)), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(PurlTune.value("Pages/AccountPage.swift:opacity:_:438:39", default: 0.16)), radius: PurlTune.value("Pages/AccountPage.swift:shadow:radius:438:123", default: 24), x: PurlTune.value("Pages/AccountPage.swift:shadow:x:438:204", default: 0), y: PurlTune.value("Pages/AccountPage.swift:shadow:y:438:279", default: 4))
    }

    // MARK: - Sign Out (text button, no bg)

    private var signOutButton: some View {
        Button {
            HapticFeedback.light.fire()
        } label: {
            Text("Sign out")
                .gravityTextStyle(GravityTypography.bodyTitleSmall)
                .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:449:34", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Header

    /// Gravity: sectionTitle (20pt semibold) — heads a grouped list (Recently viewed, Order history, etc.).
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .gravityTextStyle(GravityTypography.sectionTitle)
            .foregroundStyle(PurlTune.token("Pages/AccountPage.swift:foregroundStyle:_:460:30", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
    }

    private var shopGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#5433EB"), Color(hex: "#9C83F8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    @Previewable @Namespace var ns
    NavigationStack {
        AccountPage(namespace: ns)
    }
    .environment(NavigationCoordinator())
}
