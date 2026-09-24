import SwiftUI

/// Reviewed alpha-matted merchant photography, never a generated furniture shape.
/// The same handle resolves the role control, room invitation and room editor.
struct ReadingCornerCutout: View {
    let piece: ReadingCornerPiece
    private static let images: [String: UIImage] = Dictionary(uniqueKeysWithValues:
        ReadingCornerCatalog.snapshot.pieces.compactMap { piece in
            imageURL(for: piece).flatMap { UIImage(contentsOfFile: $0.path) }.map { (piece.handle, $0) }
        })

    static func imageURL(for piece: ReadingCornerPiece) -> URL? {
        let url = ShopCanvasLibrary.rootURL.appendingPathComponent("catalog/reading-corner/cutouts/\(piece.handle).webp")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    var body: some View {
        Group {
            if let image = Self.images[piece.handle] {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                // An unreviewed future product must not inherit another product's cutout.
                CornerArtwork(url: ShopCanvasLibrary.resolve(piece.product.image), ratio: piece.imageAspectRatio)
            }
        }.accessibilityHidden(true)
    }
}
