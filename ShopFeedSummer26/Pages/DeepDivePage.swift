import SwiftUI

/// Dossier-powered product destination: the third level of the hierarchy
/// (cover → bento → deep dive). Products with a saved dossier route here
/// instead of the plain PDP.
///
/// The dossier payload schema is still landing, so this page renders what is
/// reliably present today — the ambient films and catalog facts — and lists
/// the payload's top-level sections generically. Typed dossier sections
/// replace `payloadSections` once the schema settles.
struct DeepDivePage: View {
    let merchantId: String
    let productId: Int

    @Environment(NavigationCoordinator.self) private var coordinator

    private var merchant: SampleMerchant? {
        SampleMerchant.all.first { $0.id == merchantId }
    }
    private var product: SampleMerchant.Product? {
        merchant?.products.first { $0.id == productId }
    }
    private var dossier: ProductDossier? {
        DossierStore.dossier(merchantID: merchantId, productID: productId)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroFilm

                if let product, let merchant {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.title)
                            .font(.system(size: 28, weight: .heavy))
                            .tracking(-0.8)
                        Text("\(formatPrice(product.price)) · \(merchant.displayName)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)

                    if let description = product.productDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                            .padding(.horizontal, 16)
                    }

                    payloadSections

                    Button {
                        coordinator.pushRoute(.product(merchantId: merchantId, productId: productId))
                    } label: {
                        Text("View product")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(.black, in: Capsule())
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 120)
        }
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var heroFilm: some View {
        AmbientProductVideo(
            videoURL: dossier?.deepDiveVideoURL,
            posterImageURL: product?.imageURL
        )
        .frame(height: 520)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
    }

    /// Generic rendering of whatever top-level string content the dossier
    /// payload carries, so dropped JSON is visible before it's typed.
    @ViewBuilder
    private var payloadSections: some View {
        if let payload = dossier?.payload {
            let entries = payload
                .compactMapValues { $0 as? String }
                .filter { !$0.value.isEmpty && $0.value.count > 40 }
                .sorted { $0.key < $1.key }
            ForEach(entries, id: \.key) { key, value in
                VStack(alignment: .leading, spacing: 6) {
                    Text(key.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.system(size: 13, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeepDivePage(
            merchantId: SampleMerchant.preview.id,
            productId: SampleMerchant.preview.products.first?.id ?? 0
        )
    }
    .environment(NavigationCoordinator())
}
