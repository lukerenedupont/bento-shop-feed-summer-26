// macOS foreground extraction for reviewed merchant photographs.
// Usage: swift extract_product_foreground.swift input.jpg output.png [instanceID]
// Requires macOS 14+. Does not generate furniture or grant media reuse rights.
// Cutout source URLs and shipped-file checksums live in cutouts/provenance.json.
import Foundation
import Vision
import CoreImage

guard CommandLine.arguments.count >= 3 else {
    fatalError("Usage: extract_product_foreground.swift input.jpg output.png [instanceID]")
}
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let handler = VNImageRequestHandler(url: input)
let request = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([request])
guard let result = request.results?.first else { fatalError("No foreground observation") }
let instances: IndexSet
if CommandLine.arguments.count > 3, let instance = Int(CommandLine.arguments[3]) {
    guard result.allInstances.contains(instance) else { fatalError("Requested instance is absent") }
    instances = IndexSet([instance])
} else {
    instances = result.allInstances
}
guard !instances.isEmpty else { fatalError("No foreground instances") }
let buffer = try result.generateMaskedImage(ofInstances: instances, from: handler, croppedToInstancesExtent: true)
try CIContext().writePNGRepresentation(of: CIImage(cvPixelBuffer: buffer), to: output,
                                       format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
print("Extracted \(instances.count) foreground instance(s); review the result before publishing.")
