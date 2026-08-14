import SwiftUI

/// A film URL an ancestor surface on this screen is already playing.
/// `AmbientProductVideo` consults it so the same clip never loops twice in
/// one place — the descendant keeps its poster instead.
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
    let videoURL: URL?
    let posterImageURL: String?
    @Environment(\.claimedFilmURL) private var claimedFilmURL
    @State private var videoReady = false

    /// The same film never plays twice on one screen: when an ancestor has
    /// already claimed this URL (e.g. the topic header playing the lead
    /// hero's film above a bento that contains the same product), this
    /// surface quietly keeps its poster.
    private var effectiveVideoURL: URL? {
        videoURL == claimedFilmURL ? nil : videoURL
    }

    /// Resolves the product's ambient film from the dossier drop zone.
    init(product: SampleMerchant.Product, merchant: SampleMerchant) {
        self.videoURL = DossierStore.ambientVideoURL(merchantID: merchant.id, productID: product.id)
        self.posterImageURL = product.imageURL
    }

    init(videoURL: URL?, posterImageURL: String?) {
        self.videoURL = videoURL
        self.posterImageURL = posterImageURL
    }

    var body: some View {
        Color.clear
            .overlay {
                ZStack {
                    if let posterImageURL, let posterURL = URL(string: posterImageURL) {
                        CachedAsyncImage(url: posterURL) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color.black.opacity(0.15)
                            }
                        }
                    }
                    if let videoURL = effectiveVideoURL {
                        LoopingVideoPlayer(url: videoURL)
                            .opacity(videoReady ? 1 : 0)
                            .onAppear {
                                // Brief poster hold covers player spin-up so
                                // cells never flash black.
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
