import SwiftUI

/// Handles both empty state (headline) and typeahead results.
struct TypeaheadResultsView: View {
#if DEBUG
    @ObservedObject private var _purlTuneRuntime = PurlTuneRuntime.shared
#endif
    let query: String
    let results: [SearchSuggestion]
    let isLoading: Bool
    var onSelect: (String) -> Void = { _ in }
    var onShopSelect: ((SearchSuggestion.ShopResult) -> Void)? = nil
    /// Optional namespace + resolver to anchor a zoom transition from each shop
    /// row to its destination store page. The resolver returns the merchantId
    /// matching the `.zoom(sourceID:)` on `StorePage`.
    var transitionNamespace: Namespace.ID? = nil
    var merchantIdFor: ((SearchSuggestion.ShopResult) -> String?)? = nil

    /// Cap shop results to 2, keep all query results
    private var displayResults: [SearchSuggestion] {
        var shopCount = 0
        return results.filter { suggestion in
            switch suggestion {
            case .shop:
                shopCount += 1
                return shopCount <= 2
            case .query:
                return true
            }
        }
    }

    var body: some View {
        if !query.isEmpty {
            if isLoading && results.isEmpty {
                skeletonView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Suggestions")
                                .gravityTextStyle(GravityTypography.bodySmall)
                                .foregroundStyle(PurlTune.token("Components/Search/TypeaheadResultsView.swift:foregroundStyle:_:40:50", default: GravityColors.textTertiary, options: GravityColors.purlTuneColorOptions))
                            Spacer()
                        }
                        .padding(.horizontal, GravitySpacing.screenMargin)
                        .padding(.bottom, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:44:43", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))

                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(displayResults) { suggestion in
                                Button {
                                    HapticFeedback.light.fire()
                                    switch suggestion {
                                    case .shop(let shop):
                                        if let onShopSelect {
                                            onShopSelect(shop)
                                        } else {
                                            onSelect(shop.name)
                                        }
                                    case .query(let query): onSelect(query.text)
                                    }
                                } label: {
                                    suggestionRow(suggestion)
                                }
                                .buttonStyle(.plain)
                                .modifier(ShopRowTransitionAnchor(
                                    suggestion: suggestion,
                                    namespace: transitionNamespace,
                                    merchantIdFor: merchantIdFor
                                ))
                            }
                        }
                        .padding(.horizontal, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:70:47", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                        .padding(.bottom, PurlTune.value("Components/Search/TypeaheadResultsView.swift:padding:_:71:43", default: 500))
                    }
                    .padding(.top, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:73:36", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func suggestionRow(_ suggestion: SearchSuggestion) -> some View {
        HStack(alignment: .center, spacing: 0) {
            switch suggestion {
            case .shop(let shop): shopRow(shop)
            case .query(let query): queryRow(query)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:91:29", default: GravitySpacing.space6, options: GravitySpacing.purlTuneOptions))
        .padding(.horizontal, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:92:31", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
        .contentShape(Rectangle())
    }

    // MARK: - Shop Row

    private func shopRow(_ shop: SearchSuggestion.ShopResult) -> some View {
        HStack(alignment: .center, spacing: 0) {
            ZStack {
                AsyncImage(url: shop.logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Circle().fill(PurlTune.token("Components/Search/TypeaheadResultsView.swift:fill:_:106:39", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                            .overlay(
                                Text(String(shop.name.prefix(1)).uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(PurlTune.token("Components/Search/TypeaheadResultsView.swift:foregroundStyle:_:110:54", default: GravityColors.textSecondary, options: GravityColors.purlTuneColorOptions))
                            )
                    }
                }
                .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:114:31", default: 34), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:114:135", default: 34))
                .background(Circle().fill(.white))
                .clipShape(Circle())
                .overlay(Circle().stroke(GravityColors.borderImage, lineWidth: 0.5))
                if shop.incentiveText != nil {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: 0x6445ED),
                                    Color(hex: 0x87A9FF),
                                    Color(hex: 0x9C83F8),
                                    Color(hex: 0x5433EB),
                                    Color(hex: 0x6445ED),
                                ],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:133:39", default: 34), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:133:143", default: 34))
                }
            }
            .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:136:27", default: 34), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:136:131", default: 34))
            .padding(.trailing, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:137:33", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))

            // Name
            Text(shop.name)
                .gravityTextStyle(GravityTypography.bodySmall)
                .foregroundStyle(PurlTune.token("Components/Search/TypeaheadResultsView.swift:foregroundStyle:_:142:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .lineLimit(1)

            // Rating + incentive badges
            HStack(alignment: .center, spacing: GravitySpacing.space8) {
                if let rating = shop.rating, let count = shop.ratingCount, count > 0 {
                    HStack(alignment: .center, spacing: 2) {
                        Text(String(format: "%.1f", rating))
                            .gravityTextStyle(GravityTypography.badgeBold)
                            .foregroundStyle(PurlTune.token("Components/Search/TypeaheadResultsView.swift:foregroundStyle:_:151:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                        GravityIcon.starFilled.image
                            .resizable()
                            .scaledToFit()
                            .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:155:43", default: 10), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:155:147", default: 10))
                            .foregroundStyle(PurlTune.token("Components/Search/TypeaheadResultsView.swift:foregroundStyle:_:156:46", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                    }
                    .padding(.horizontal, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:158:43", default: GravitySpacing.space6, options: GravitySpacing.purlTuneOptions))
                    .padding(.vertical, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:159:41", default: GravitySpacing.space2, options: GravitySpacing.purlTuneOptions))
                    .background(GravityColors.bgOverlayFixedDark04, in: Capsule())
                }

                if let text = shop.incentiveText {
                    Text(text)
                        .gravityTextStyle(GravityTypography.badgeBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:167:47", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                        .padding(.vertical, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:168:45", default: GravitySpacing.space2, options: GravitySpacing.purlTuneOptions))
                        .background(GravityColors.bgFillBrand, in: Capsule())
                }
            }
            .padding(.leading, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:172:32", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))

            Spacer(minLength: 0)
        }
        .padding(.vertical, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:176:29", default: GravitySpacing.space4, options: GravitySpacing.purlTuneOptions))
    }

    // MARK: - Query Row

    private func queryRow(_ query: SearchSuggestion.QueryResult) -> some View {
        HStack(alignment: .center, spacing: 0) {
            GravityIcon.search.image
                .resizable()
                .scaledToFit()
                .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:186:31", default: 24), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:186:135", default: 24))
                .foregroundStyle(GravityColors.text.opacity(PurlTune.value("Components/Search/TypeaheadResultsView.swift:opacity:_:187:61", default: 0.6)))
                .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:188:31", default: 34), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:188:135", default: 34))
                .padding(.trailing, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:189:37", default: GravitySpacing.space12, options: GravitySpacing.purlTuneOptions))

            Text(query.text)
                .gravityTextStyle(GravityTypography.bodySmall)
                .foregroundStyle(PurlTune.token("Components/Search/TypeaheadResultsView.swift:foregroundStyle:_:193:34", default: GravityColors.text, options: GravityColors.purlTuneColorOptions))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Shop Row Transition Anchor

    /// Applies `.matchedTransitionSource` to shop rows when a namespace +
    /// resolver are provided. Query rows and unresolved shops pass through.
    private struct ShopRowTransitionAnchor: ViewModifier {
        let suggestion: SearchSuggestion
        let namespace: Namespace.ID?
        let merchantIdFor: ((SearchSuggestion.ShopResult) -> String?)?

        func body(content: Content) -> some View {
            if let namespace,
               let merchantIdFor,
               case .shop(let shop) = suggestion,
               let merchantId = merchantIdFor(shop) {
                content.matchedTransitionSource(id: merchantId, in: namespace)
            } else {
                content
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PurlTune.token("Components/Search/TypeaheadResultsView.swift:fill:_:228:31", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                        .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:229:39", default: 90), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:229:143", default: 14))
                    Spacer()
                }
                .padding(.horizontal, GravitySpacing.screenMargin)
                .padding(.bottom, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:233:35", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))

                VStack(alignment: .leading, spacing: GravitySpacing.space4) {
                    ForEach(0..<8, id: \.self) { i in
                        HStack(spacing: GravitySpacing.space12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(PurlTune.value("Components/Search/TypeaheadResultsView.swift:opacity:_:239:59", default: 0.06)))
                                .frame(width: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:width:240:47", default: 34), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:240:151", default: 34))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(PurlTune.token("Components/Search/TypeaheadResultsView.swift:fill:_:243:39", default: GravityColors.bgFillSecondary, options: GravityColors.purlTuneColorOptions))
                                .frame(width: CGFloat([160, 120, 180, 140, 170, 130, 150, 175][i % 8]), height: PurlTune.value("Components/Search/TypeaheadResultsView.swift:frame:height:244:113", default: 16))

                            Spacer()
                        }
                        .padding(.vertical, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:248:45", default: GravitySpacing.space6, options: GravitySpacing.purlTuneOptions))
                        .padding(.horizontal, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:249:47", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
                    }
                }
                .padding(.horizontal, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:252:39", default: GravitySpacing.space8, options: GravitySpacing.purlTuneOptions))
            }
            .padding(.top, PurlTune.token("Components/Search/TypeaheadResultsView.swift:padding:_:254:28", default: GravitySpacing.space16, options: GravitySpacing.purlTuneOptions))
            .padding(.bottom, PurlTune.value("Components/Search/TypeaheadResultsView.swift:padding:_:255:31", default: 200))
        }
        .pulse()
    }
}

#Preview("With results") {
    TypeaheadResultsView(
        query: "hiking",
        results: SearchSuggestion.previews,
        isLoading: false
    )
    .background(PurlTune.token("Components/Search/TypeaheadResultsView.swift:background:_:267:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}

#Preview("Loading") {
    TypeaheadResultsView(
        query: "hiking",
        results: [],
        isLoading: true
    )
    .background(PurlTune.token("Components/Search/TypeaheadResultsView.swift:background:_:276:17", default: GravityColors.bg, options: GravityColors.purlTuneColorOptions))
}
