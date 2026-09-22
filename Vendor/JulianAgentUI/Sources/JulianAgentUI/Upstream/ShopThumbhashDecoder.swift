import CoreImage
import Foundation
import UIKit

private final class ShopThumbhashImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, UIImage>()

    init(countLimit: Int, totalCostLimit: Int? = nil) {
        cache.countLimit = countLimit
        if let totalCostLimit {
            cache.totalCostLimit = totalCostLimit
        }
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String, cost: Int = 0) {
        if cost > 0 {
            cache.setObject(image, forKey: key as NSString, cost: cost)
        } else {
            cache.setObject(image, forKey: key as NSString)
        }
    }
}

// Decodes https://evanw.github.io/thumbhash/ strings into UIImage placeholders.

enum ShopThumbhashDecoder {
    private static let cache = ShopThumbhashImageCache(countLimit: 1_000)
    private static let renderedCache = ShopThumbhashImageCache(
        countLimit: 300,
        totalCostLimit: 48 * 1_024 * 1_024
    )

    static func image(from thumbhash: String?) -> UIImage? {
        guard let thumbhash = normalizedThumbhash(thumbhash) else {
            return nil
        }

        if let cachedImage = cache.image(forKey: thumbhash) {
            return cachedImage
        }

        guard let data = data(from: thumbhash),
              let image = decode(data) else {
            return nil
        }

        cache.setImage(image, forKey: thumbhash)
        return image
    }

    static func renderedImageCacheKey(
        from thumbhash: String?,
        targetSize: CGSize,
        contentMode: UIView.ContentMode,
        scale: CGFloat
    ) -> String? {
        guard let thumbhash = normalizedThumbhash(thumbhash),
              let pixelSize = renderedPixelSize(for: targetSize, scale: scale) else {
            return nil
        }

        return "\(thumbhash)|\(Int(pixelSize.width))x\(Int(pixelSize.height))|\(contentMode.cacheKey)"
    }

    static func cachedRenderedImage(for cacheKey: String) -> UIImage? {
        renderedCache.image(forKey: cacheKey)
    }

    static func renderedImage(
        from thumbhash: String?,
        targetSize: CGSize,
        contentMode: UIView.ContentMode,
        scale: CGFloat
    ) -> UIImage? {
        guard let cacheKey = renderedImageCacheKey(
            from: thumbhash,
            targetSize: targetSize,
            contentMode: contentMode,
            scale: scale
        ) else {
            return nil
        }

        if let cachedImage = cachedRenderedImage(for: cacheKey) {
            return cachedImage
        }

        guard let baseImage = image(from: thumbhash),
              let pixelSize = renderedPixelSize(for: targetSize, scale: scale),
              let renderedImage = render(baseImage, pixelSize: pixelSize, contentMode: contentMode, scale: scale) else {
            return nil
        }

        let cost = Int(pixelSize.width * pixelSize.height * 4)
        renderedCache.setImage(renderedImage, forKey: cacheKey, cost: cost)
        return renderedImage
    }

    private static func normalizedThumbhash(_ thumbhash: String?) -> String? {
        guard let thumbhash = thumbhash?.trimmingCharacters(in: .whitespacesAndNewlines),
              thumbhash.isEmpty == false else {
            return nil
        }

        return thumbhash
    }

    private static func renderedPixelSize(for targetSize: CGSize, scale: CGFloat) -> CGSize? {
        guard targetSize.width.isFinite,
              targetSize.height.isFinite,
              targetSize.width > 0,
              targetSize.height > 0,
              scale.isFinite,
              scale > 0 else {
            return nil
        }

        return CGSize(
            width: max((targetSize.width * scale).rounded(), 1),
            height: max((targetSize.height * scale).rounded(), 1)
        )
    }

    private static func render(
        _ image: UIImage,
        pixelSize: CGSize,
        contentMode: UIView.ContentMode,
        scale: CGFloat
    ) -> UIImage? {
        guard pixelSize.width > 0,
              pixelSize.height > 0 else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard

        let renderer = UIGraphicsImageRenderer(size: pixelSize, format: format)
        let renderedImage = renderer.image { context in
            context.cgContext.interpolationQuality = .high
            image.draw(in: drawRect(
                imageSize: image.size,
                canvasSize: pixelSize,
                contentMode: contentMode
            ))
        }

        guard let cgImage = renderedImage.cgImage else {
            return renderedImage
        }

        if let blurredCGImage = blurredImage(
            from: cgImage,
            radius: blurRadius(sourceImage: image, pixelSize: pixelSize)
        ) {
            return UIImage(cgImage: blurredCGImage, scale: scale, orientation: .up)
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private static func blurRadius(sourceImage: UIImage, pixelSize: CGSize) -> CGFloat {
        guard let sourceCGImage = sourceImage.cgImage else {
            return 0
        }

        let sourceWidth = max(CGFloat(sourceCGImage.width), 1)
        let sourceHeight = max(CGFloat(sourceCGImage.height), 1)
        let scaleFactor = max(pixelSize.width / sourceWidth, pixelSize.height / sourceHeight)
        return min(max(scaleFactor * 0.4, 1.5), 16)
    }

    private static func blurredImage(from cgImage: CGImage, radius: CGFloat) -> CGImage? {
        guard radius > 0 else {
            return cgImage
        }

        let inputImage = CIImage(cgImage: cgImage)
        let outputImage = inputImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: inputImage.extent)

        return CIContext().createCGImage(outputImage, from: inputImage.extent)
    }

    private static func drawRect(
        imageSize: CGSize,
        canvasSize: CGSize,
        contentMode: UIView.ContentMode
    ) -> CGRect {
        let widthScale = canvasSize.width / max(imageSize.width, 1)
        let heightScale = canvasSize.height / max(imageSize.height, 1)
        let scale = contentMode == .scaleAspectFit ? min(widthScale, heightScale) : max(widthScale, heightScale)
        let drawSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: (canvasSize.width - drawSize.width) / 2,
            y: (canvasSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    private static func data(from thumbhash: String) -> Data? {
        var base64 = thumbhash
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }

        return Data(base64Encoded: base64)
    }

    private static func decode(_ hash: Data) -> UIImage? {
        guard let (width, height, decodedRGBA) = thumbHashToRGBA(hash: hash) else {
            return nil
        }

        var rgba = decodedRGBA
        rgba.withUnsafeMutableBytes { bytes in
            guard var pointer = bytes.baseAddress?.bindMemory(to: UInt8.self, capacity: bytes.count) else {
                return
            }

            let pixelCount = width * height
            for _ in 0 ..< pixelCount {
                let alpha = UInt16(pointer[3])
                if alpha < 255 {
                    pointer[0] = UInt8(min(255, UInt16(pointer[0]) * alpha / 255))
                    pointer[1] = UInt8(min(255, UInt16(pointer[1]) * alpha / 255))
                    pointer[2] = UInt8(min(255, UInt16(pointer[2]) * alpha / 255))
                }
                pointer = pointer.advanced(by: 4)
            }
        }

        guard let provider = CGDataProvider(data: rgba as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(
                    rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .perceptual
              ) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private static func thumbHashToRGBA(hash: Data) -> (width: Int, height: Int, rgba: Data)? {
        guard hash.count >= 5 else {
            return nil
        }

        let h0 = UInt32(hash[0])
        let h1 = UInt32(hash[1])
        let h2 = UInt32(hash[2])
        let h3 = UInt16(hash[3])
        let h4 = UInt16(hash[4])
        let header24 = h0 | (h1 << 8) | (h2 << 16)
        let header16 = h3 | (h4 << 8)

        var luminanceDC = Float32(header24 & 63)
        var pDC = Float32((header24 >> 6) & 63)
        var qDC = Float32((header24 >> 12) & 63)
        luminanceDC /= 63
        pDC = pDC / 31.5 - 1
        qDC = qDC / 31.5 - 1

        var luminanceScale = Float32((header24 >> 18) & 31)
        luminanceScale /= 31

        let hasAlpha = (header24 >> 23) != 0
        var pScale = Float32((header16 >> 3) & 63)
        var qScale = Float32((header16 >> 9) & 63)
        pScale /= 63
        qScale /= 63

        let isLandscape = (header16 >> 15) != 0
        let lx16 = max(UInt16(3), isLandscape ? (hasAlpha ? UInt16(5) : UInt16(7)) : (header16 & 7))
        let ly16 = max(UInt16(3), isLandscape ? (header16 & 7) : (hasAlpha ? UInt16(5) : UInt16(7)))
        let lx = Int(lx16)
        let ly = Int(ly16)

        var alphaDC = Float32(1)
        var alphaScale = Float32(1)
        if hasAlpha {
            guard hash.count > 5 else {
                return nil
            }
            alphaDC = Float32(hash[5] & 15) / 15
            alphaScale = Float32(hash[5] >> 4) / 15
        }

        let acStart = hasAlpha ? 6 : 5
        var acIndex = 0
        let decodeChannel: (_ nx: Int, _ ny: Int, _ scale: Float32) -> [Float32]? = { nx, ny, scale in
            var ac: [Float32] = []
            for cy in 0 ..< ny {
                var cx = cy > 0 ? 0 : 1
                while cx * ny < nx * (ny - cy) {
                    let byteIndex = acStart + (acIndex >> 1)
                    guard byteIndex < hash.count else {
                        return nil
                    }

                    let quantizedCoefficient = (hash[byteIndex] >> ((acIndex & 1) << 2)) & 15
                    let coefficient = (Float32(quantizedCoefficient) / 7.5 - 1) * scale
                    ac.append(coefficient)
                    acIndex += 1
                    cx += 1
                }
            }
            return ac
        }

        guard let luminanceAC = decodeChannel(lx, ly, luminanceScale),
              let pAC = decodeChannel(3, 3, pScale * 1.25),
              let qAC = decodeChannel(3, 3, qScale * 1.25) else {
            return nil
        }

        let alphaAC: [Float32]
        if hasAlpha {
            guard let decodedAlphaAC = decodeChannel(5, 5, alphaScale) else {
                return nil
            }
            alphaAC = decodedAlphaAC
        } else {
            alphaAC = []
        }

        let ratio = approximateAspectRatio(hash: hash)
        let floatWidth = round(ratio > 1 ? 32 : 32 * ratio)
        let floatHeight = round(ratio > 1 ? 32 / ratio : 32)
        let width = max(Int(floatWidth), 1)
        let height = max(Int(floatHeight), 1)

        var rgba = Data(count: width * height * 4)
        let cxStop = max(lx, hasAlpha ? 5 : 3)
        let cyStop = max(ly, hasAlpha ? 5 : 3)
        var fx = [Float32](repeating: 0, count: cxStop)
        var fy = [Float32](repeating: 0, count: cyStop)

        rgba.withUnsafeMutableBytes { bytes in
            guard var pixel = bytes.baseAddress?.bindMemory(to: UInt8.self, capacity: bytes.count) else {
                return
            }

            for y in 0 ..< height {
                for x in 0 ..< width {
                    var luminance = luminanceDC
                    var p = pDC
                    var q = qDC
                    var alpha = alphaDC

                    for cx in 0 ..< cxStop {
                        fx[cx] = cos(Float32.pi / Float32(width) * (Float32(x) + 0.5) * Float32(cx))
                    }
                    for cy in 0 ..< cyStop {
                        fy[cy] = cos(Float32.pi / Float32(height) * (Float32(y) + 0.5) * Float32(cy))
                    }

                    var index = 0
                    for cy in 0 ..< ly {
                        var cx = cy > 0 ? 0 : 1
                        let doubledYFactor = fy[cy] * 2
                        while cx * ly < lx * (ly - cy) {
                            luminance += luminanceAC[index] * fx[cx] * doubledYFactor
                            index += 1
                            cx += 1
                        }
                    }

                    index = 0
                    for cy in 0 ..< 3 {
                        var cx = cy > 0 ? 0 : 1
                        let doubledYFactor = fy[cy] * 2
                        while cx < 3 - cy {
                            let factor = fx[cx] * doubledYFactor
                            p += pAC[index] * factor
                            q += qAC[index] * factor
                            index += 1
                            cx += 1
                        }
                    }

                    if hasAlpha {
                        index = 0
                        for cy in 0 ..< 5 {
                            var cx = cy > 0 ? 0 : 1
                            let doubledYFactor = fy[cy] * 2
                            while cx < 5 - cy {
                                alpha += alphaAC[index] * fx[cx] * doubledYFactor
                                index += 1
                                cx += 1
                            }
                        }
                    }

                    var blue = luminance - 2 / 3 * p
                    var red = (3 * luminance - blue + q) / 2
                    var green = red - q
                    red = max(0, 255 * min(1, red))
                    green = max(0, 255 * min(1, green))
                    blue = max(0, 255 * min(1, blue))
                    alpha = max(0, 255 * min(1, alpha))

                    pixel[0] = UInt8(red)
                    pixel[1] = UInt8(green)
                    pixel[2] = UInt8(blue)
                    pixel[3] = UInt8(alpha)
                    pixel = pixel.advanced(by: 4)
                }
            }
        }

        return (width, height, rgba)
    }

    private static func approximateAspectRatio(hash: Data) -> Float32 {
        let header = hash[3]
        let hasAlpha = (hash[2] & 0x80) != 0
        let isLandscape = (hash[4] & 0x80) != 0
        let lx = isLandscape ? (hasAlpha ? UInt8(5) : UInt8(7)) : (header & 7)
        let ly = isLandscape ? (header & 7) : (hasAlpha ? UInt8(5) : UInt8(7))
        return Float32(max(lx, 1)) / Float32(max(ly, 1))
    }
}

private extension UIView.ContentMode {
    var cacheKey: String {
        switch self {
        case .scaleAspectFit:
            "fit"
        case .scaleAspectFill:
            "fill"
        default:
            "other-\(rawValue)"
        }
    }
}
