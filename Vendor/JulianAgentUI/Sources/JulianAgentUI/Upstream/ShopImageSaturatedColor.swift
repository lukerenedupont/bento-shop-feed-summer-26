import Nuke
import SwiftUI
import UIKit

/// A small sRGB ↔ OKLCH converter for perceptual color adjustments.
///
/// OKLCH lets callers normalize lightness without changing the sampled hue,
/// and enforce a useful amount of color without relying on HSL saturation.
struct ShopOKLCHColor: Equatable, Sendable {
    let lightness: Double
    let chroma: Double
    let hue: Double

    init(red: Double, green: Double, blue: Double) {
        let red = Self.linearComponent(red)
        let green = Self.linearComponent(green)
        let blue = Self.linearComponent(blue)

        let l = 0.412_221_470_8 * red + 0.536_332_536_3 * green + 0.051_445_992_9 * blue
        let m = 0.211_903_498_2 * red + 0.680_699_545_1 * green + 0.107_396_956_6 * blue
        let s = 0.088_302_461_9 * red + 0.281_718_837_6 * green + 0.629_978_700_5 * blue

        let lRoot = cbrt(l)
        let mRoot = cbrt(m)
        let sRoot = cbrt(s)
        let a = 1.977_998_495_1 * lRoot - 2.428_592_205 * mRoot + 0.450_593_709_9 * sRoot
        let b = 0.025_904_037_1 * lRoot + 0.782_771_766_2 * mRoot - 0.808_675_766 * sRoot

        lightness = 0.210_454_255_3 * lRoot + 0.793_617_785 * mRoot - 0.004_072_046_8 * sRoot
        chroma = hypot(a, b)
        hue = atan2(b, a)
    }

    init?(hex: String?) {
        guard var hex else { return nil }
        hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }
        guard hex.count >= 6,
              let value = UInt64(String(hex.prefix(6)), radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Returns the requested perceptual color, reducing chroma only when the
    /// fixed-lightness color falls outside the sRGB display gamut.
    func normalized(
        lightness: Double,
        minimumChroma: Double,
        chromaScale: Double = 1
    ) -> ShopOKLCHColor {
        let target = ShopOKLCHColor(
            lightness: lightness.clamped(to: 0...1),
            chroma: max(chroma * chromaScale, minimumChroma),
            hue: hue
        )
        guard target.unclampedSRGB.isInGamut == false else { return target }

        var lowerChroma = 0.0
        var upperChroma = target.chroma
        for _ in 0..<16 {
            let candidateChroma = (lowerChroma + upperChroma) / 2
            let candidate = ShopOKLCHColor(
                lightness: target.lightness,
                chroma: candidateChroma,
                hue: target.hue
            )
            if candidate.unclampedSRGB.isInGamut {
                lowerChroma = candidateChroma
            } else {
                upperChroma = candidateChroma
            }
        }
        return ShopOKLCHColor(lightness: target.lightness, chroma: lowerChroma, hue: target.hue)
    }

    var color: Color {
        let components = unclampedSRGB
        return Color(
            red: components.red.clamped(to: 0...1),
            green: components.green.clamped(to: 0...1),
            blue: components.blue.clamped(to: 0...1)
        )
    }

    private init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    private var unclampedSRGB: SRGBComponents {
        let a = chroma * cos(hue)
        let b = chroma * sin(hue)
        let lRoot = lightness + 0.396_337_777_4 * a + 0.215_803_757_3 * b
        let mRoot = lightness - 0.105_561_345_8 * a - 0.063_854_172_8 * b
        let sRoot = lightness - 0.089_484_177_5 * a - 1.291_485_548 * b
        let l = lRoot * lRoot * lRoot
        let m = mRoot * mRoot * mRoot
        let s = sRoot * sRoot * sRoot

        return SRGBComponents(
            red: Self.sRGBComponent(4.076_741_662_1 * l - 3.307_711_591_3 * m + 0.230_969_929_2 * s),
            green: Self.sRGBComponent(-1.268_438_004_6 * l + 2.609_757_401_1 * m - 0.341_319_396_5 * s),
            blue: Self.sRGBComponent(-0.004_196_086_3 * l - 0.703_418_614_7 * m + 1.707_614_701 * s)
        )
    }

    private static func linearComponent(_ component: Double) -> Double {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }

    private static func sRGBComponent(_ component: Double) -> Double {
        component <= 0.0031308
            ? 12.92 * component
            : 1.055 * pow(component, 1 / 2.4) - 0.055
    }

    private struct SRGBComponents {
        let red: Double
        let green: Double
        let blue: Double

        var isInGamut: Bool {
            (0...1).contains(red) && (0...1).contains(green) && (0...1).contains(blue)
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Samples thumbnails off the main actor, sharing Nuke's image cache with the UI.
/// Ignore transparent pixels and near-black/white backgrounds, then choose the
/// most saturated visible color across the whole image stack.
actor ShopImageSaturatedColor {
    static let shared = ShopImageSaturatedColor()
    private var cache: [URL: Sample] = [:]

    struct Sample: Sendable {
        let red: Double
        let green: Double
        let blue: Double

        var saturation: Double {
            let maximum = max(red, green, blue)
            return maximum == 0 ? 0 : (maximum - min(red, green, blue)) / maximum
        }

        var oklch: ShopOKLCHColor { ShopOKLCHColor(red: red, green: green, blue: blue) }
    }

    func sample(urls: [URL]) async -> Sample? {
        var best: Sample?
        for url in urls {
            guard !Task.isCancelled else { return nil }
            let sample: Sample?
            if let cached = cache[url] {
                sample = cached
            } else {
                var request = ImageRequest(url: url)
                request.thumbnail = .init(size: CGSize(width: 64, height: 64), unit: .pixels, contentMode: .aspectFill)
                guard let image = try? await ImagePipeline.shared.image(for: request),
                      let cgImage = image.cgImage else { continue }
                sample = Self.sample(image: cgImage)
                if let sample {
                    if cache.count >= 128 { cache.removeAll(keepingCapacity: true) }
                    cache[url] = sample
                }
            }
            if let sample, best == nil || sample.saturation > best!.saturation { best = sample }
        }
        return best
    }

    nonisolated static func sample(image: CGImage) -> Sample? {
        let size = 32
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            let rgba = bytes.bindMemory(to: UInt8.self)
            var best: Sample?
            for offset in stride(from: 0, to: rgba.count, by: 4) {
                let alpha = Double(rgba[offset + 3]) / 255
                guard alpha > 0.9 else { continue }
                let sample = Sample(red: Double(rgba[offset]) / 255 / alpha,
                                    green: Double(rgba[offset + 1]) / 255 / alpha,
                                    blue: Double(rgba[offset + 2]) / 255 / alpha)
                let lightness = (max(sample.red, sample.green, sample.blue) + min(sample.red, sample.green, sample.blue)) / 2
                guard lightness > 0.12, lightness < 0.92, sample.saturation > 0.08 else { continue }
                if best == nil || sample.saturation > best!.saturation { best = sample }
            }
            return best
        }
    }
}
