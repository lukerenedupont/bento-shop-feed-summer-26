import SwiftUI
import UIKit

/// The tones the stage chrome borrows from the look currently on screen.
///
/// Every look is a flat photograph with its own environment baked in, so there
/// is no fixed backdrop colour to design against — a warm interior and a
/// mountaintop want completely different chrome. A single grey canvas read as
/// too light behind the warm frames and made the header and panel fades look
/// like bands laid over the photo instead of extensions of it.
///
/// Sampling the photograph fixes that by construction: the fade dissolves into
/// the image because it is made of the image.
enum TryFavesStageColors {

    struct Bands: Equatable {
        /// Mean of the frame's top edge, behind the header chrome.
        let skyRGB: RGB
        /// Mean of the frame's bottom edge, behind the look panel.
        let groundRGB: RGB

        /// The canvas under the lifted frame. Exactly the frame's own ground
        /// tone, so the strip the lift leaves reads as more floor rather than
        /// as a step.
        var canvas: Color { groundRGB.color }

        /// The chrome fades. Deliberately *not* the exact band tone: a fade
        /// tinted with the colour it sits on is invisible, and white type over
        /// bare photography has nothing holding it. Darkening the frame's own
        /// tone gives the type a footing while still belonging to the image —
        /// which a neutral grey scrim never does.
        var skyScrim: Color { skyRGB.darkened(by: Self.scrimDarkening).color }
        var groundScrim: Color { groundRGB.darkened(by: Self.scrimDarkening).color }

        private static let scrimDarkening = 0.16

        /// Used until a look's render is available, and for looks whose image
        /// can't be read.
        static let neutral = Bands(
            skyRGB: RGB(red: 0.918, green: 0.918, blue: 0.918),
            groundRGB: RGB(red: 0.918, green: 0.918, blue: 0.918)
        )
    }

    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double

        var color: Color { Color(red: red, green: green, blue: blue) }

        func darkened(by amount: Double) -> RGB {
            let factor = 1 - amount
            return RGB(red: red * factor, green: green * factor, blue: blue * factor)
        }
    }

    /// Keyed by the look's cache key. Renders are immutable once generated, so
    /// a hit is always valid, and the set is small.
    @MainActor private static var cache: [String: Bands] = [:]

    @MainActor
    static func bands(for image: UIImage, key: String) -> Bands {
        if let cached = cache[key] { return cached }
        let bands = sample(image) ?? .neutral
        cache[key] = bands
        return bands
    }

    /// Draws the frame into a narrow strip and averages its first and last
    /// rows. A strip is plenty: these bands are broad areas of wall, sky, and
    /// floor, and the point is the average rather than any detail.
    private static func sample(_ image: UIImage) -> Bands? {
        guard let cgImage = image.cgImage else { return nil }
        let width = 24
        let height = 64
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func mean(rows: Range<Int>) -> RGB {
            var red = 0, green = 0, blue = 0, count = 0
            for row in rows {
                for column in 0..<width {
                    let offset = (row * width + column) * 4
                    red += Int(pixels[offset])
                    green += Int(pixels[offset + 1])
                    blue += Int(pixels[offset + 2])
                    count += 1
                }
            }
            guard count > 0 else { return Bands.neutral.groundRGB }
            return RGB(
                red: Double(red) / Double(count) / 255,
                green: Double(green) / Double(count) / 255,
                blue: Double(blue) / Double(count) / 255
            )
        }

        // CoreGraphics draws bottom-up, so row 0 is the foot of the frame.
        return Bands(
            skyRGB: mean(rows: (height - 8)..<height),
            groundRGB: mean(rows: 0..<8)
        )
    }
}
