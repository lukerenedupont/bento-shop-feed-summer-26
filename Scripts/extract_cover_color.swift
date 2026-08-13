#!/usr/bin/env swift
// Prints the average color of the bottom band of each image as a hex value.
// The topic header fades its cover into the page background, so sampling the
// bottom ~22% of the image yields the color that blends most seamlessly.
//
// Usage: swift Scripts/extract_cover_color.swift <image> [<image> ...]
// Output: one "<path> #RRGGBB" line per image.

import CoreImage
import Foundation

let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

func bottomBandAverageHex(url: URL) -> String? {
    guard let image = CIImage(contentsOf: url) else { return nil }
    // CoreImage's origin is bottom-left, so y=0 is the visual bottom.
    let band = CGRect(
        x: 0, y: 0,
        width: image.extent.width,
        height: (image.extent.height * 0.22).rounded()
    )
    guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
        kCIInputImageKey: image.cropped(to: band),
        kCIInputExtentKey: CIVector(cgRect: band),
    ]), let output = filter.outputImage else { return nil }

    var pixel = [UInt8](repeating: 0, count: 4)
    context.render(
        output,
        toBitmap: &pixel,
        rowBytes: 4,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
    )

    var r = Double(pixel[0]) / 255
    var g = Double(pixel[1]) / 255
    var b = Double(pixel[2]) / 255

    // Topic surfaces render white text and use a dark color scheme, so cap
    // the value (HSV brightness) while preserving hue and saturation.
    let maxComponent = max(r, g, b)
    let brightnessCap = 0.42
    if maxComponent > brightnessCap {
        let scale = brightnessCap / maxComponent
        r *= scale
        g *= scale
        b *= scale
    }

    return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
}

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    if let hex = bottomBandAverageHex(url: url) {
        print("\(path) \(hex)")
    } else {
        FileHandle.standardError.write("Failed to read \(path)\n".data(using: .utf8)!)
        exit(1)
    }
}
