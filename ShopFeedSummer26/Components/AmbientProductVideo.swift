import SwiftUI

/// A film URL an ancestor surface on this screen is already playing. Child
/// media surfaces omit it so the same clip never loops twice on one screen.
extension EnvironmentValues {
    @Entry var claimedFilmURL: URL? = nil
}

/// An ambient product surface: a muted, autoplaying, looping "in use" film
/// with the product photo as poster/fallback.
///
/// This is the bento compartment texture — video is atmosphere, never a
/// destination. `LoopingVideoPlayer` already mutes, pauses off-screen, and
/// loops, so cells stay cheap in dense layouts. When no film exists for the
/// product (dossier not yet generated/dropped in), the poster renders alone
/// and the layout is identical.
struct AmbientProductVideo: View {
    let videoURLs: [URL]
    let posterImageURL: String?
    var playbackEnabled: Bool
    var playbackGroupID: String?
    @Environment(\.claimedFilmURL) private var claimedFilmURL
    @State private var videoReady = false

    private var effectiveVideoURLs: [URL] {
        videoURLs.filter { $0 != claimedFilmURL }
    }

    /// Resolves the product's ambient film.
    init(
        product: SampleMerchant.Product,
        merchant: SampleMerchant,
        playbackEnabled: Bool = true,
        playbackGroupID: String? = nil
    ) {
        self.videoURLs = product.ambientFilmURL(merchantID: merchant.id).map { [$0] } ?? []
        self.posterImageURL = product.imageURL
        self.playbackEnabled = playbackEnabled
        self.playbackGroupID = playbackGroupID
    }

    init(
        videoURL: URL?,
        posterImageURL: String?,
        playbackEnabled: Bool = true,
        playbackGroupID: String? = nil
    ) {
        self.videoURLs = videoURL.map { [$0] } ?? []
        self.posterImageURL = posterImageURL
        self.playbackEnabled = playbackEnabled
        self.playbackGroupID = playbackGroupID
    }

    init(
        videoURLs: [URL],
        posterImageURL: String?,
        playbackEnabled: Bool = true,
        playbackGroupID: String? = nil
    ) {
        self.videoURLs = videoURLs
        self.posterImageURL = posterImageURL
        self.playbackEnabled = playbackEnabled
        self.playbackGroupID = playbackGroupID
    }

    var body: some View {
        Color.clear
            .overlay {
                ZStack {
                    if playbackGroupID != nil {
                        // Never expose a light poster while a second layer is
                        // attaching to an already-running shared card player.
                        Color.black
                    } else if let posterImageURL, let posterURL = URL(string: posterImageURL) {
                        CachedAsyncImage(url: posterURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color.black.opacity(0.15)
                            }
                        }
                    }
                    if !effectiveVideoURLs.isEmpty {
                        LoopingVideoPlayer(
                            urls: effectiveVideoURLs,
                            playbackEnabled: playbackEnabled,
                            playbackGroupID: playbackGroupID
                        )
                        // A shared card player is already rendering in the
                        // source view, so revealing its second layer
                        // immediately avoids flashing the poster during zoom.
                        .opacity(playbackGroupID != nil || videoReady ? 1 : 0)
                        .onAppear {
                            guard playbackGroupID == nil else { return }
                            // Brief poster hold covers first-time player spin-up.
                            withAnimation(.easeIn(duration: 0.3).delay(0.15)) {
                                videoReady = true
                            }
                        }
                    }
                }
            }
            .clipped()
    }
}

extension SampleMerchant.Product {
    /// The ambient film for this product, from whichever source has one.
    ///
    /// The feed API ships a generated clip per product on `videoUrl`; bundled
    /// products instead have films dropped into `Dossiers/` and keyed by
    /// (merchant, product). Preferring the served URL means a live feed plays
    /// films for products the bundle has never heard of, while offline runs
    /// keep working exactly as before.
    func ambientFilmURL(merchantID: String) -> URL? {
        if let videoUrl, let url = URL(string: videoUrl) { return url }
        return DossierStore.ambientVideoURL(merchantID: merchantID, productID: id)
    }
}

/// A product tile that plays its ambient film when there is one and shows the
/// product photo when there is not.
///
/// The film is layered *over* `ProductImageView` rather than replacing it, so
/// the photo acts as the poster during player spin-up and keeps that view's
/// merchant-image fallback for products with no usable photo. The footprint is
/// identical in both states, so a film arriving never shifts a layout.
struct ProductMediaView: View {
    let product: SampleMerchant.Product
    let merchant: SampleMerchant
    var fallbackIndex: Int = 0

    @State private var filmReady = false

    private var filmURL: URL? { product.ambientFilmURL(merchantID: merchant.id) }

    var body: some View {
        ProductImageView(product: product, merchant: merchant, fallbackIndex: fallbackIndex)
            .overlay {
                if let filmURL {
                    LoopingVideoPlayer(url: filmURL)
                        .opacity(filmReady ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeIn(duration: 0.3).delay(0.15)) {
                                filmReady = true
                            }
                        }
                }
            }
            .clipped()
    }
}

#Preview("Poster only (no film yet)") {
    AmbientProductVideo(
        product: SampleMerchant.preview.products[0],
        merchant: SampleMerchant.preview
    )
    .frame(width: 220, height: 300)
    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
    .padding()
    .background(GravityColors.bg)
}

#Preview("With ambient film") {
    // Reuse the kit's bundled "map" video so the preview works offline.
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("preview-ambient.mp4")
    let _ = NSDataAsset(name: "map").map { try? $0.data.write(to: tempURL) }
    AmbientProductVideo(
        videoURL: FileManager.default.fileExists(atPath: tempURL.path) ? tempURL : nil,
        posterImageURL: SampleMerchant.preview.products.first?.imageURL
    )
    .frame(width: 220, height: 300)
    .clipShape(RoundedRectangle(cornerRadius: GravityRadius.r20))
    .padding()
    .background(GravityColors.bg)
}
