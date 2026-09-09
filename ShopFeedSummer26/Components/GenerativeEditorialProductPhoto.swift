import SwiftUI

/// Presentation crops remove empty studio margins from verified local photos.
/// The actual garment/chair remains intact; details retain the original image.
struct GenerativeEditorialProductPhoto: View {
    let item: ResolvedStoryProduct
    var comparison = false

    private var photo: UIImage? {
        let key = "\(item.merchant.id)-\(item.product.id)"
        guard let crop = Self.crops[key] else { return nil }
        let suffix = comparison && item.product.id == 7873592721581 ? "-comparison" : ""
        guard let url = Bundle.main.url(forResource: "prototype-product-\(key)\(suffix)", withExtension: "jpg"),
              let source = UIImage(contentsOfFile: url.path)?.cgImage,
              let image = source.cropping(to: crop) else { return nil }
        return UIImage(cgImage: image)
    }

    private static let crops: [String: CGRect] = [
        "feature-salomon-6882430025799": CGRect(x: 175, y: 0, width: 490, height: 840),
        "feature-salomon-6882429796423": CGRect(x: 175, y: 0, width: 490, height: 840),
        "house-of-leon-7873592688813": CGRect(x: 150, y: 190, width: 480, height: 500),
        "house-of-leon-7873592721581": CGRect(x: 180, y: 265, width: 500, height: 490)
    ]

    var body: some View {
        if let photo {
            Image(uiImage: photo).resizable().scaledToFit().accessibilityHidden(true)
        } else {
            GenerativeProductMedia(item: item, presentation: comparison ? "comparison" : nil)
        }
    }
}
