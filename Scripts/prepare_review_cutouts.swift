// PROTOTYPE — remove backgrounds from canonical product photographs, without generating product pixels.
// swift Scripts/prepare_review_cutouts.swift input.jpg output.png
import Foundation
import Vision
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let source = CGImageSourceCreateWithURL(input as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let handler = VNImageRequestHandler(cgImage: image)
let request = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([request])
guard let result = request.results?.first, !result.allInstances.isEmpty else {
    fatalError("No foreground object found in \(input.lastPathComponent)")
}
let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
let foreground = CIImage(cgImage: image)
let cutout = foreground.applyingFilter("CIBlendWithMask", parameters: [
    kCIInputBackgroundImageKey: CIImage(color: .clear).cropped(to: foreground.extent),
    kCIInputMaskImageKey: CIImage(cvPixelBuffer: mask)
])
let cg = CIContext().createCGImage(cutout, from: foreground.extent)!
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, cg, nil)
precondition(CGImageDestinationFinalize(destination))
