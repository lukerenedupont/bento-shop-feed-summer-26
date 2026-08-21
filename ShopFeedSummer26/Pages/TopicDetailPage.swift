import SwiftUI
import UIKit
import AVFoundation

/// Immersive destination for a tapped feed story. The Figma-derived header
/// and first commerce rails resolve from the story, so every buyer and topic
/// shares one presentation instead of branching into profile-specific views.
struct TopicDetailPage: View {
    let story: FeedStory
    let merchants: [SampleMerchant]

    @Environment(NavigationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var showsControls = false
    @State private var isFollowingTopic = false
    @State private var focusedDealID: String?
    @State private var postService = ShopPostService.shared
    @State private var sampledSurfaceColor: DominantVideoColor?

    private var products: [ResolvedStoryProduct] {
        story.resolvedProducts(from: merchants)
    }

    private var relatedMerchants: [SampleMerchant] {
        var seen = Set<String>()
        return products.map(\.merchant).filter { seen.insert($0.id).inserted }
    }

    private var relatedDeals: [RelatedDeal] {
        let dealMerchants = featuredMerchants.isEmpty ? relatedMerchants : featuredMerchants
        return dealMerchants.prefix(6).map { merchant in
            var seen = Set<Int>()
            let topicProducts = products
                .filter { $0.merchant.id == merchant.id }
                .map(\.product)
            let resolvedProducts = (topicProducts + merchant.products)
                .filter { seen.insert($0.id).inserted }

            return RelatedDeal(
                merchant: merchant,
                products: Array(resolvedProducts.prefix(3))
            )
        }
    }

    private var newProducts: [ResolvedStoryProduct] {
        Array(products.prefix(6))
    }

    private var bestSellerProducts: [ResolvedStoryProduct] {
        let offset = min(3, max(0, products.count - 1))
        let shifted = Array(products.dropFirst(offset).prefix(6))
        return shifted.count >= 3 ? shifted : Array(products.reversed().prefix(6))
    }

    /// Prefer posts from merchants already represented in this topic. The
    /// authenticated Shop feed remains the source of truth; we never invent a
    /// social tile from catalog photography.
    private var recentPosts: [ShopPost] {
        let merchantNames = Set(relatedMerchants.map { normalizedMerchantName($0.displayName) })
        let verified = postService.posts(for: BuyerPreviewStore.shared.selected)
            .filter { $0.media.previewURL != nil }
        let topicMatches = verified.filter {
            merchantNames.contains(normalizedMerchantName($0.merchant.name))
        }
        return Array((topicMatches.isEmpty ? verified : topicMatches).prefix(6))
    }

    private func normalizedMerchantName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Deal cards are brand-led, so they only render when we have a real
    /// merchant wordmark rather than manufacturing a text approximation.
    private func hasRenderableDealWordmark(_ merchant: SampleMerchant) -> Bool {
        if UIImage(named: MerchantBrandAssets.wordmarkName(for: merchant.id)) != nil {
            return true
        }
        guard let rawURL = merchant.bestWordmarkURL,
              let url = URL(string: rawURL) else { return false }
        return url.pathExtension.lowercased() != "svg"
    }

    private var specificTopicTerms: Set<String> {
        let genericTerms: Set<String> = [
            "best", "black", "brass", "cream", "design", "designed", "designs", "featured", "high",
            "hardware", "lighting", "living", "modern", "pieces", "products",
            "mount", "mounted", "nickel", "shop", "style", "wall", "white",
        ]
        let copyTerms = Set(
            "\(story.title) \(story.subtitle)"
                .lowercased()
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count > 3 && !genericTerms.contains($0) }
        )
        let productTerms = products
            .flatMap { item in
                item.product.title.lowercased()
                    .split { !$0.isLetter && !$0.isNumber }
                    .map(String.init)
            }
            .filter { $0.count > 3 && !genericTerms.contains($0) }
        let recurringProductTerms = Dictionary(grouping: productTerms, by: { $0 })
            .compactMap { term, occurrences in occurrences.count >= 2 ? term : nil }
        return copyTerms.union(recurringProductTerms)
    }

    private func relevance(of merchant: SampleMerchant) -> Int {
        let merchantText = "\(merchant.name) \(merchant.description) \(merchant.productCategory ?? "") \(merchant.products.map(\.title).joined(separator: " "))"
            .lowercased()
        return specificTopicTerms.reduce(0) { score, term in
            score + (merchantText.contains(term) ? 1 : 0)
        }
    }

    private func hasPriceFit(_ merchant: SampleMerchant) -> Bool {
        guard let band = HypothesisShelfCatalog.priceBandUSD(for: story.id) else {
            return true
        }
        let expandedBand = (band.lowerBound * 0.75)...(band.upperBound * 1.25)
        return merchant.products.lazy.compactMap { Double($0.price) }
            .filter { expandedBand.contains($0) }
            .prefix(2)
            .count >= 2
    }

    private var featuredCollections: [FeedStory] {
        let curatedIDs = HypothesisShelfCatalog.relatedStoryIDs(for: story.id)
        if !curatedIDs.isEmpty {
            let storiesByID = Dictionary(
                uniqueKeysWithValues: PersonalizedFeedStories.all.map { ($0.id, $0) }
            )
            return curatedIDs.compactMap { storiesByID[$0] }
        }

        let topicKeys = Set(story.topicKeys.filter { $0 != "catalog-only-media" })
        let currentMerchantIDs = Set(products.map(\.merchant.id))
        return PersonalizedFeedStories.all
            .filter { candidate in
                guard candidate.id != story.id,
                      candidate.topicKeys.contains("merchant-card") == false else { return false }
                let sharesTopic = !topicKeys.isDisjoint(with: candidate.topicKeys)
                let sharesMerchant = candidate.resolvedProducts(from: merchants).contains {
                    currentMerchantIDs.contains($0.merchant.id)
                }
                return sharesTopic || sharesMerchant
            }
            .prefix(6)
            .map { $0 }
    }

    private var featuredMerchants: [SampleMerchant] {
        var seen = Set<String>()
        var result: [SampleMerchant] = []

        for merchant in relatedMerchants {
            guard merchant.products.count >= 3,
                  hasRenderableDealWordmark(merchant),
                  seen.insert(merchant.id).inserted else { continue }
            result.append(merchant)
        }

        let canonicalCandidates = merchants
            .filter {
                $0.coverImageURL != nil
                    && $0.products.count >= 3
                    && hasRenderableDealWordmark($0)
                    && relevance(of: $0) >= 2
                    && hasPriceFit($0)
            }
            .sorted { relevance(of: $0) > relevance(of: $1) }

        for merchant in canonicalCandidates {
            guard seen.insert(merchant.id).inserted else { continue }
            result.append(merchant)
        }
        return Array(result.prefix(6))
    }

    private var exploreProducts: [ResolvedStoryProduct] {
        var seen = Set<String>()
        var result = products.filter { seen.insert($0.id).inserted }
        for merchant in featuredMerchants {
            for product in merchant.products {
                let resolved = ResolvedStoryProduct(merchant: merchant, product: product)
                guard seen.insert(resolved.id).inserted else { continue }
                result.append(resolved)
            }
        }
        return result
    }

    private var surfaceColor: Color {
        guard let sampledSurfaceColor else { return Color(hex: story.accentHex) }
        return Color(
            red: sampledSurfaceColor.red,
            green: sampledSurfaceColor.green,
            blue: sampledSurfaceColor.blue
        )
    }

    private var heroVideoURL: URL? {
        FeedCoverCatalog.presentation(for: story)?.source.videoURL
            ?? products.lazy.flatMap {
                $0.product.ambientFilmURLs(merchantID: $0.merchant.id)
            }.first
    }

    private var usesCuratedSculpturalHierarchy: Bool {
        story.id == "shelf-luke-2-sculptural-living-room-pieces"
    }

    private var windowSafeAreaTopInset: CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let keyWindow = windowScene.windows.first(where: \.isKeyWindow) else {
            return 0
        }
        return keyWindow.safeAreaInsets.top
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                surfaceColor
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        hero(width: geometry.size.width)

                        VStack(alignment: .leading, spacing: GravitySpacing.space24) {
                            productRail(
                                title: usesCuratedSculpturalHierarchy ? "The edit" : "New this week",
                                items: usesCuratedSculpturalHierarchy ? products : newProducts
                            )
                            if !usesCuratedSculpturalHierarchy, !relatedDeals.isEmpty {
                                dealRail(containerWidth: geometry.size.width)
                            }
                            if !usesCuratedSculpturalHierarchy {
                                productRail(title: "Best sellers", items: bestSellerProducts)
                            }
                            if !featuredMerchants.isEmpty { featuredMerchantRail }
                            if !featuredCollections.isEmpty { collectionRail }
                            if !recentPosts.isEmpty { recentPostRail }
                            exploreMore(containerWidth: geometry.size.width)
                        }
                        .padding(.bottom, 120)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)

                HStack {
                    closeButton
                    Spacer()
                    followButton
                }
                    .frame(width: geometry.size.width)
                    .padding(.top, windowSafeAreaTopInset + GravitySpacing.space4)
                    .opacity(showsControls ? 1 : 0)
                    .zIndex(10)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .dark)
        .task(id: story.id) {
            showsControls = false
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                focusedDealID = relatedDeals.first?.id
            }
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.18)) { showsControls = true }
        }
        .task(id: heroVideoURL) {
            sampledSurfaceColor = nil
            guard let heroVideoURL,
                  let color = await DominantVideoColorSampler.sample(from: heroVideoURL),
                  !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.24)) {
                sampledSurfaceColor = color
            }
        }
        .onAppear { coordinator.showNavBar = false }
        .onDisappear {
            coordinator.resetScrollState()
            coordinator.showNavBar = true
        }
    }

    private func hero(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            surfaceColor

            StoryFeedCard(
                story: story,
                merchants: merchants,
                width: width,
                height: 560,
                isActive: true,
                showsForegroundContent: false,
                showsFooterArrow: false,
                backgroundPlaybackEnabled: true,
                cornerRadius: 0,
                freezesParallax: true
            )
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.60),
                        .init(color: .white.opacity(0.72), location: 0.76),
                        .init(color: .white.opacity(0.22), location: 0.90),
                        .init(color: .clear, location: 0.98),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .clear, location: 0.26),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer()

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: surfaceColor.opacity(0.36), location: 0.34),
                        .init(color: surfaceColor.opacity(0.86), location: 0.70),
                        .init(color: surfaceColor, location: 0.92),
                        .init(color: surfaceColor, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 190)

                // A solid overlap prevents a one-pixel compositing seam where
                // the hero hands off to the page surface.
                surfaceColor.frame(height: 12)
            }

            VStack(alignment: .leading, spacing: GravitySpacing.space10) {
                Text(story.title)
                    .font(FeedEditorialTypography.titleFont)
                    .tracking(FeedEditorialTypography.titleTracking)
                    .lineSpacing(FeedEditorialTypography.titleLineSpacing)
                    .tightMultilineLeading(FeedEditorialTypography.titleLineTightening)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if !story.subtitle.isEmpty {
                    Text(story.subtitle)
                        .font(GravityFont.medium.fixedFont(size: 17))
                        .tracking(-0.2)
                        .lineSpacing(1)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .frame(maxWidth: min(width - 48, 340), alignment: .leading)
                }
            }
            .foregroundStyle(.white)
            .gravityShadow(GravityShadows.feedText)
            .frame(
                maxWidth: width - 32,
                maxHeight: .infinity,
                alignment: .bottomLeading
            )
            .padding(.horizontal, GravitySpacing.space16)
            .padding(.bottom, GravitySpacing.space20)
        }
        .frame(width: width, height: 560)
        .clipped()
    }

    private func productRail(
        title: String,
        items: [ResolvedStoryProduct]
    ) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(items) { item in
                        Button {
                            HapticFeedback.light.fire()
                            coordinator.pushRoute(.product(merchantId: item.merchant.id, productId: item.product.id))
                        } label: {
                            ProductCard(
                                image: nil,
                                imageURL: item.product.imageURL,
                                merchantName: item.merchant.displayName,
                                productName: item.product.title,
                                price: formatPrice(item.product.price),
                                showFavoriteButton: true
                            )
                            .frame(width: 132)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GravitySpacing.space16)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func dealRail(containerWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle("Featured deals")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .center, spacing: GravitySpacing.space10) {
                    ForEach(relatedDeals) { deal in
                        RelatedDealCard(deal: deal)
                            .id(deal.id)
                            .scrollTransition(.interactive, axis: .horizontal) { card, phase in
                                card.scaleEffect(phase.isIdentity ? 1 : 0.9)
                            }
                    }
                }
                .padding(.horizontal, max(GravitySpacing.space12, (containerWidth - 266) / 2))
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $focusedDealID, anchor: .center)
        }
    }

    private var collectionRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle("Related collections")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(featuredCollections) { collection in
                        TopicCollectionCard(story: collection, merchants: merchants)
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private var featuredMerchantRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle("Top merchants")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: GravitySpacing.space10) {
                    ForEach(featuredMerchants) { merchant in
                        TopicMerchantShowcaseCard(merchant: merchant)
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private var recentPostRail: some View {
        VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle("Recent posts")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: GravitySpacing.space8) {
                    ForEach(recentPosts) { post in
                        TopicRecentPostCard(post: post)
                    }
                }
                .padding(.horizontal, GravitySpacing.space12)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }

    private func exploreMore(containerWidth: CGFloat) -> some View {
        let columnGap = GravitySpacing.space10
        let padding = GravitySpacing.space12
        let width = (containerWidth - padding * 2 - columnGap) / 2
        let left = exploreProducts.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? $0.element : nil }
        let right = exploreProducts.enumerated().compactMap { $0.offset.isMultiple(of: 2) ? nil : $0.element }

        return VStack(alignment: .leading, spacing: GravitySpacing.space16) {
            sectionTitle(usesCuratedSculpturalHierarchy ? "More to explore" : "Explore more")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GravitySpacing.space8) {
                    ForEach(["All", "On sale", "Under $100", "New"], id: \.self) { filter in
                        Text(filter)
                            .font(GravityFont.medium.fixedFont(size: 14))
                            .foregroundStyle(filter == "All" ? surfaceColor : .white)
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(filter == "All" ? Color.white : Color.white.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, padding)
            }

            HStack(alignment: .top, spacing: columnGap) {
                VStack(spacing: GravitySpacing.space16) {
                    ForEach(left) { item in
                        TopicMasonryCard(item: .product(item), cardWidth: width)
                    }
                }
                .frame(width: width)

                VStack(spacing: GravitySpacing.space16) {
                    ForEach(right) { item in
                        TopicMasonryCard(item: .product(item), cardWidth: width)
                    }
                }
                .frame(width: width)
            }
            .padding(.horizontal, padding)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack(spacing: GravitySpacing.space8) {
            Text(title)
            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .bold))
        }
        .font(GravityFont.expressiveBold.fixedFont(size: 22))
        .tracking(-0.45)
        .foregroundStyle(.white)
        .gravityShadow(GravityShadows.feedText)
        .padding(.horizontal, GravitySpacing.space12)
    }

    private var closeButton: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.showNavBar = true
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.leading, GravitySpacing.space16)
        .accessibilityLabel("Close")
    }

    private var followButton: some View {
        Button {
            HapticFeedback.light.fire()
            withAnimation(.easeInOut(duration: 0.18)) {
                isFollowingTopic.toggle()
            }
        } label: {
            Text(isFollowingTopic ? "Following" : "Follow")
                .font(GravityFont.semiBold.fixedFont(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, GravitySpacing.space16)
                .frame(height: 40)
                .background(.ultraThinMaterial, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.trailing, GravitySpacing.space16)
        .accessibilityLabel(isFollowingTopic ? "Unfollow this topic" : "Follow this topic")
        .accessibilityAddTraits(isFollowingTopic ? .isSelected : [])
    }

}

private struct DominantVideoColor: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
}

/// Samples one representative video frame into a tiny quantized histogram.
/// The work runs off the main actor once per topic and stores only three color
/// channels, so scrolling and video playback never pay for the analysis.
private enum DominantVideoColorSampler {
    private struct Bucket {
        var count = 0
        var red = 0
        var green = 0
        var blue = 0
    }

    static func sample(from url: URL) async -> DominantVideoColor? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 96, height: 96)

            let frame: CGImage
            do {
                frame = try await generator.image(
                    at: CMTime(seconds: 1, preferredTimescale: 600)
                ).image
            } catch {
                return nil
            }
            return dominantColor(in: frame)
        }.value
    }

    private static func dominantColor(in image: CGImage) -> DominantVideoColor? {
        let width = 48
        let height = 48
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var buckets: [Int: Bucket] = [:]
        for offset in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let alpha = Int(pixels[offset + 3])
            let luminance = (red * 3 + green * 6 + blue) / 10
            guard alpha > 160, luminance > 22, luminance < 238 else { continue }

            let key = (red / 32 << 6) | (green / 32 << 3) | (blue / 32)
            var bucket = buckets[key, default: Bucket()]
            bucket.count += 1
            bucket.red += red
            bucket.green += green
            bucket.blue += blue
            buckets[key] = bucket
        }

        guard let winner = buckets.values.max(by: { $0.count < $1.count }),
              winner.count > 0 else { return nil }
        return DominantVideoColor(
            red: Double(winner.red) / Double(winner.count) / 255,
            green: Double(winner.green) / Double(winner.count) / 255,
            blue: Double(winner.blue) / Double(winner.count) / 255
        )
    }
}

private struct RelatedDeal: Identifiable {
    let merchant: SampleMerchant
    let products: [SampleMerchant.Product]

    var id: String { merchant.id }
}

private struct RelatedDealCard: View {
    let deal: RelatedDeal
    @Environment(NavigationCoordinator.self) private var coordinator

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.store(merchantId: deal.merchant.id))
        } label: {
            ZStack {
                MerchantCoverImage(merchant: deal.merchant)
                    .frame(width: 266, height: 263)
                    .clipped()

                LinearGradient(
                    stops: [
                        .init(color: deal.merchant.brandColor.opacity(0.10), location: 0),
                        .init(color: deal.merchant.brandColor, location: 0.50),
                        .init(color: deal.merchant.brandColor, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: GravitySpacing.space12) {
                    merchantIdentity.frame(height: 100)
                    productRow

                    Text("Save $10 on orders over $50")
                        .gravityTextStyle(GravityTypography.buttonSmall)
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(.white.opacity(0.64), in: Capsule())
                }
                .padding(GravitySpacing.space12)
            }
            .frame(width: 266, height: 263)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Shop all from \(deal.merchant.displayName)")
    }

    private var merchantIdentity: some View {
        VStack(spacing: GravitySpacing.space8) {
            if MerchantBrandAssets.hasVerifiedBundledWordmark(for: deal.merchant.id)
                || hasUsableRemoteWordmark {
                MerchantWordmarkImage(
                    merchant: deal.merchant,
                    maxHeight: 40,
                    maxWidth: 120,
                    bundledAssetName: MerchantBrandAssets.wordmarkName(for: deal.merchant.id)
                )
            } else {
                Text(deal.merchant.displayName)
                    .font(GravityFont.expressiveBold.fixedFont(size: 24))
                    .tracking(-0.5)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }

            if deal.merchant.totalRatings > 0 {
                HStack(spacing: GravitySpacing.space2) {
                    Text(String(format: "%.1f", deal.merchant.rating))
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("(\(compactRatingCount(deal.merchant.totalRatings)))")
                }
                .gravityTextStyle(GravityTypography.captionMedium)
            }
        }
        .foregroundStyle(.black)
        .shadow(color: .black.opacity(0.24), radius: 20, y: 8)
        .frame(maxWidth: .infinity)
    }

    private var hasUsableRemoteWordmark: Bool {
        guard let source = deal.merchant.bestWordmarkURL,
              let url = URL(string: source) else { return false }
        return url.pathExtension.lowercased() != "svg"
    }

    private var productRow: some View {
        HStack(spacing: GravitySpacing.space8) {
            ForEach(deal.products) { product in
                ProductImageView(product: product, merchant: deal.merchant)
                    .frame(width: 75, height: 75)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous)
                            .strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
                    }
            }
        }
        .frame(width: 241, height: 75)
    }

    private func compactRatingCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return String(count)
    }
}

private struct TopicCollectionCard: View {
    let story: FeedStory
    let merchants: [SampleMerchant]

    @Environment(NavigationCoordinator.self) private var coordinator

    private var lifestyleURL: URL? {
        if let presentation = FeedCoverCatalog.presentation(for: story) {
            return presentation.coverURL(from: merchants)
        }
        return story.lifestyleImageURL(
            from: merchants,
            format: .landscape,
            role: "topic-featured-collection"
        )
    }

    private var fallbackProduct: ResolvedStoryProduct? {
        story.resolvedProducts(from: merchants).first
    }

    private var bundledCoverName: String? {
        if let presentation = FeedCoverCatalog.presentation(for: story),
           let name = presentation.source.bundledAssetName {
            return name
        }
        return FeedCoverCatalog.fallbackImageName(for: story)
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.story(storyId: story.id))
        } label: {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let lifestyleURL {
                        CachedAsyncImage(url: lifestyleURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else if let fallbackProduct {
                                ProductImageView(product: fallbackProduct.product, merchant: fallbackProduct.merchant)
                            } else {
                                Color(hex: story.accentHex)
                            }
                        }
                    } else if let bundledCoverName {
                        Image(bundledCoverName)
                            .resizable()
                            .scaledToFill()
                    } else if let fallbackProduct {
                        ProductImageView(product: fallbackProduct.product, merchant: fallbackProduct.merchant)
                    } else {
                        Color(hex: story.accentHex)
                    }
                }
                .frame(width: 344, height: 220)
                .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.72)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(alignment: .bottom, spacing: GravitySpacing.space12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(story.title)
                            .font(GravityFont.expressiveBold.fixedFont(size: 23))
                            .tracking(-0.5)
                            .lineLimit(2)
                        if !story.subtitle.isEmpty {
                            Text(story.subtitle)
                                .font(GravityFont.medium.fixedFont(size: 13))
                                .lineLimit(1)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space16)
            }
            .frame(width: 344, height: 220)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}

private struct TopicRecentPostCard: View {
    let post: ShopPost

    private var previewURL: URL? { post.media.previewURL }

    private var displayCopy: String {
        [post.title, post.caption, post.subtitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? post.merchant.name
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            guard let actionURL = post.actionURL else { return }
            UIApplication.shared.open(actionURL)
        } label: {
            VStack(alignment: .leading, spacing: GravitySpacing.space8) {
                ZStack(alignment: .bottomLeading) {
                    if let previewURL {
                        CachedAsyncImage(url: previewURL) { phase in
                            if case let .success(image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Color.white.opacity(0.08)
                            }
                        }
                    } else {
                        Color.white.opacity(0.08)
                    }

                    LinearGradient(
                        colors: [.clear, .black.opacity(0.46)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    HStack(spacing: GravitySpacing.space6) {
                        if let logoURL = post.merchant.logoURL {
                            CachedAsyncImage(url: logoURL) { phase in
                                if case let .success(image) = phase {
                                    image.resizable().scaledToFit()
                                } else {
                                    Color.clear
                                }
                            }
                            .padding(4)
                            .frame(width: 28, height: 28)
                            .background(.white, in: Circle())
                        }

                        Text(post.merchant.name)
                            .font(GravityFont.semiBold.fixedFont(size: 12))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .gravityShadow(GravityShadows.feedText)
                    .padding(GravitySpacing.space8)
                }
                .frame(width: 148, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20, style: .continuous))

                Text(displayCopy)
                    .font(GravityFont.medium.fixedFont(size: 12))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(width: 148, alignment: .leading)
            }
            .frame(width: 148, alignment: .leading)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Post from \(post.merchant.name): \(displayCopy)")
    }
}

private struct TopicMerchantShowcaseCard: View {
    let merchant: SampleMerchant

    @Environment(NavigationCoordinator.self) private var coordinator

    private var products: [SampleMerchant.Product] {
        Array(merchant.products.prefix(3))
    }

    /// Merchant cover art frequently arrives as a baked campaign collage.
    /// Use one product's authored alternate frame instead so the card always
    /// has a single clean photographic background.
    private var backgroundImageURL: String? {
        merchant.products.lazy.compactMap { product in
            product.allImageURLs.dropFirst().first
        }.first
            ?? merchant.products.first?.imageURL
            ?? merchant.featuredImageURLs.first
    }

    var body: some View {
        Button {
            HapticFeedback.light.fire()
            coordinator.pushRoute(.store(merchantId: merchant.id))
        } label: {
            ZStack {
                MerchantImage(merchant: merchant, urlString: backgroundImageURL)
                    .frame(width: 344, height: 382)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.28), .clear, .black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: 0) {
                    HStack {
                        MerchantWordmarkImage(
                            merchant: merchant,
                            maxHeight: 34,
                            maxWidth: 150,
                            bundledAssetName: MerchantBrandAssets.wordmarkName(for: merchant.id)
                        )
                        Spacer()
                        if merchant.totalRatings > 0 {
                            Label(String(format: "%.1f", merchant.rating), systemImage: "star.fill")
                                .font(GravityFont.medium.fixedFont(size: 12))
                        }
                    }
                    .frame(height: 46)

                    Spacer(minLength: GravitySpacing.space16)

                    HStack(spacing: GravitySpacing.space8) {
                        ForEach(products) { product in
                            ProductImageView(product: product, merchant: merchant)
                                .frame(width: 101, height: 101)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r16, style: .continuous))
                                .gravityShadow(GravityShadows.small)
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(GravitySpacing.space12)
            }
            .frame(width: 344, height: 382)
            .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: GravityRadius.r28, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Shop \(merchant.displayName)")
    }
}
