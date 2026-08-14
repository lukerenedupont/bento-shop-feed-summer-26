#!/usr/bin/env swift
// Prints a surface accent color for each cover image as a hex value.
//
// Pixels from the whole frame are bucketed by hue; each qualifying bucket
// (>= 4% coverage) is ranked by the *chroma* of its average color with a
// gentle coverage tiebreaker. Chroma finds the cover's characterful color
// (sky-blue mirror, NYCTA orange, terracotta tile) instead of the biggest
// neutral wall or the shadow band at the frame's bottom - coverage-scored
// bottom-band sampling collapsed most covers into the same muddy brown.
// The winner is then normalized to a dark, white-text-safe surface tone
// with its hue and saturation character preserved.
//
// Usage: swift Scripts/extract_cover_color.swift <image> [<image> ...]
// Output: one "<path> #RRGGBB" line per image.

import CoreImage
import Foundation

let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

func rgbToHSV(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
    let maxC = max(r, g, b), minC = min(r, g, b)
    let delta = maxC - minC
    var h = 0.0
    if delta > 0 {
        if maxC == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxC == g { h = (b - r) / delta + 2 }
        else { h = (r - g) / delta + 4 }
        h *= 60
        if h < 0 { h += 360 }
    }
    let s = maxC == 0 ? 0 : delta / maxC
    return (h, s, maxC)
}

func hsvToRGB(h: Double, s: Double, v: Double) -> (r: Double, g: Double, b: Double) {
    let c = v * s
    let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
    let m = v - c
    let (r, g, b): (Double, Double, Double)
    switch h {
    case ..<60: (r, g, b) = (c, x, 0)
    case ..<120: (r, g, b) = (x, c, 0)
    case ..<180: (r, g, b) = (0, c, x)
    case ..<240: (r, g, b) = (0, x, c)
    case ..<300: (r, g, b) = (x, 0, c)
    default: (r, g, b) = (c, 0, x)
    }
    return (r + m, g + m, b + m)
}

func surfaceAccentHex(url: URL) -> String? {
    guard let image = CIImage(contentsOf: url) else { return nil }
    let band = image

    // Downsample to a small bitmap for the histogram.
    let sampleWidth = 96
    let scale = Double(sampleWidth) / band.extent.width
    let small = band.transformed(by: .init(scaleX: scale, y: scale))
    let w = Int(small.extent.width.rounded()), h = Int(small.extent.height.rounded())
    guard w > 0, h > 0 else { return nil }
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    context.render(
        small, toBitmap: &pixels, rowBytes: w * 4,
        bounds: CGRect(x: small.extent.minX, y: small.extent.minY, width: CGFloat(w), height: CGFloat(h)),
        format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
    )

    // Bucket by hue (24 buckets); score = coverage x (saturation + floor).
    // The floor keeps near-neutral covers from losing to a few loud pixels.
    let buckets = 24
    var score = [Double](repeating: 0, count: buckets)
    var sumR = [Double](repeating: 0, count: buckets)
    var sumG = [Double](repeating: 0, count: buckets)
    var sumB = [Double](repeating: 0, count: buckets)
    var weight = [Double](repeating: 0, count: buckets)
    var count = [Int](repeating: 0, count: buckets)
    var totalCount = 0
    for i in stride(from: 0, to: pixels.count, by: 4) {
        let r = Double(pixels[i]) / 255, g = Double(pixels[i + 1]) / 255, b = Double(pixels[i + 2]) / 255
        let (hue, s, v) = rgbToHSV(r: r, g: g, b: b)
        // Skip near-black and blown-out pixels; they carry no hue identity.
        guard v > 0.08, v < 0.97 else { continue }
        let bucket = min(buckets - 1, Int(hue / 360 * Double(buckets)))
        let pixelWeight = s + 0.08
        count[bucket] += 1
        totalCount += 1
        score[bucket] += pixelWeight
        sumR[bucket] += r * pixelWeight
        sumG[bucket] += g * pixelWeight
        sumB[bucket] += b * pixelWeight
        weight[bucket] += pixelWeight
    }
    // A bucket qualifies if it covers a real share of the frame; among
    // qualifiers the most chromatic average wins. Chroma (s x v) keeps
    // near-black shadow fringes from beating an airy oak room, and the
    // gentle coverage factor keeps a dominant surface (terracotta tile)
    // from losing to a sliver of highlight with marginally higher chroma.
    let minCount = max(1, Int(Double(totalCount) * 0.04))
    var winner = -1
    var winnerRank = -1.0
    for b in 0..<buckets where count[b] >= minCount && weight[b] > 0 {
        let hsv = rgbToHSV(r: sumR[b] / weight[b], g: sumG[b] / weight[b], b: sumB[b] / weight[b])
        let coverage = Double(count[b]) / Double(totalCount)
        let rank = hsv.s * hsv.v * pow(coverage, 0.15)
        if rank > winnerRank { winnerRank = rank; winner = b }
    }
    guard winner >= 0 else { return nil }

    let r = sumR[winner] / weight[winner]
    let g = sumG[winner] / weight[winner]
    let b = sumB[winner] / weight[winner]
    var (hue, s, v) = rgbToHSV(r: r, g: g, b: b)

    // Normalize toward a dark, white-text-safe surface while keeping the
    // cover's own character: saturation is amplified (not pinned) and value
    // is compressed into a dark band instead of flattened to one number —
    // a bright airy cover should still yield a lighter surface than a
    // moody one.
    s = min(max(s * 1.6, 0.16), 0.78)
    v = min(max(v * 0.85, 0.18), 0.46)
    let (outR, outG, outB) = hsvToRGB(h: hue, s: s, v: v)
    return String(format: "#%02X%02X%02X", Int(outR * 255), Int(outG * 255), Int(outB * 255))
}

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    if let hex = surfaceAccentHex(url: url) {
        print("\(path) \(hex)")
    } else {
        FileHandle.standardError.write("Failed to read \(path)\n".data(using: .utf8)!)
        exit(1)
    }
}
