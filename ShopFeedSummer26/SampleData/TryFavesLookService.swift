import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Generates, caches, and persists "Try your faves" looks.
///
/// Rendering runs through fal's queue API against `fal-ai/fashn/tryon/v1.6`.
/// The fal API key never ships in the app: every HTTP call is authorized with
/// a short-lived JWT minted by the same server-side token endpoint the live
/// Decart studio uses (`FAL_TOKEN_ENDPOINT` / Shopify proxy fallback). fal's
/// queue supports webhooks, but a client-only prototype has no callback URL,
/// so completion is observed by polling the queue's status endpoint instead.
@MainActor
@Observable
final class TryFavesLookService {
    static let shared = TryFavesLookService()

    static let modelVersion = "fal-ai/fashn/tryon/v1.6"
    /// Generation settings, frozen into the cache key: balanced mode, one
    /// sample, PNG output.
    static let generationSettings = "balanced|samples=1|png"

    enum LookState: Codable, Hashable {
        case generating
        case ready
        case failed(String)

        var isFailed: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    struct Look: Identifiable, Codable, Hashable {
        let id: UUID
        var title: String
        /// Ordered variant IDs, generation order (bottoms before top).
        let variantIDs: [String]
        let cacheKey: String
        let createdAt: Date
        var state: LookState
        var attemptCount: Int
    }

    enum JobPhase: Equatable {
        case queued
        case applyingBottoms
        case applyingTop
        case applyingOnePiece
        case validating

        var label: String {
            switch self {
            case .queued: "Queued"
            case .applyingBottoms: "Styling bottoms"
            case .applyingTop: "Styling the top"
            case .applyingOnePiece: "Styling the look"
            case .validating: "Checking the result"
            }
        }
    }

    struct Job: Equatable {
        let lookID: UUID
        var phase: JobPhase
        var attempt: Int
    }

    private(set) var looks: [Look] = []
    private(set) var activeJob: Job?
    /// A finished look the shopper hasn't opened yet — drives the
    /// "View new look" chip and its badge.
    private(set) var unseenLookID: UUID?

    private var renderImages: [String: UIImage] = [:]
    private var generationTask: Task<Void, Never>?

    private init() {
        looks = Self.loadLooks()
        // A relaunch mid-generation leaves orphaned `.generating` looks with
        // no task attached. Surface them as retryable instead of spinning.
        for index in looks.indices where looks[index].state == .generating {
            looks[index].state = .failed("Generation was interrupted.")
        }
    }

    // MARK: - Public API

    func resolvedGarments(for look: Look) -> [TryOnGarment] {
        // Present garments top-first regardless of generation order.
        look.variantIDs
            .compactMap(TryFavesCatalog.garment(for:))
            .sorted { lhs, _ in lhs.category != .bottoms }
    }

    /// Submit a new look. Returns the look's ID immediately; generation
    /// continues in the background and publishes through `activeJob` / `looks`.
    @discardableResult
    func generate(outfit: TryFavesOutfit) -> UUID? {
        guard activeJob == nil else { return nil }

        let cacheKey = Self.cacheKey(for: outfit)
        let look = Look(
            id: UUID(),
            title: "Look \(looks.count + 1)",
            variantIDs: outfit.orderedVariantIDs,
            cacheKey: cacheKey,
            createdAt: Date(),
            state: .generating,
            attemptCount: 0
        )
        looks.append(look)
        persistLooks()

        // Cache hit: the identical avatar + variants + model + settings was
        // rendered before. Reuse it without touching the network.
        if let cached = loadCachedRender(for: cacheKey) {
            renderImages[cacheKey] = cached
            finish(lookID: look.id, state: .ready)
            return look.id
        }

        startGeneration(lookID: look.id, outfit: outfit)
        return look.id
    }

    func retry(_ lookID: UUID) {
        guard activeJob == nil,
              let look = looks.first(where: { $0.id == lookID }),
              look.state.isFailed else { return }
        let garments = look.variantIDs.compactMap(TryFavesCatalog.garment(for:))
        guard let outfit = Self.outfit(from: garments) else { return }
        update(lookID: lookID) { $0.state = .generating }
        startGeneration(lookID: lookID, outfit: outfit)
    }

    func delete(_ lookID: UUID) {
        guard activeJob?.lookID != lookID else { return }
        looks.removeAll { $0.id == lookID }
        if unseenLookID == lookID { unseenLookID = nil }
        persistLooks()
    }

    func markSeen(_ lookID: UUID) {
        if unseenLookID == lookID { unseenLookID = nil }
    }

    func renderImage(for look: Look) -> UIImage? {
        if let image = renderImages[look.cacheKey] { return image }
        guard let image = loadCachedRender(for: look.cacheKey) else { return nil }
        renderImages[look.cacheKey] = image
        return image
    }

    // MARK: - Generation pipeline

    private func startGeneration(lookID: UUID, outfit: TryFavesOutfit) {
        let attempt = (looks.first { $0.id == lookID }?.attemptCount ?? 0) + 1
        update(lookID: lookID) { $0.attemptCount = attempt }
        activeJob = Job(lookID: lookID, phase: .queued, attempt: attempt)

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await self.render(outfit: outfit, lookID: lookID)
                let cacheKey = Self.cacheKey(for: outfit)
                self.storeCachedRender(image, for: cacheKey)
                self.renderImages[cacheKey] = image
                self.finish(lookID: lookID, state: .ready)
            } catch is CancellationError {
                self.finish(lookID: lookID, state: .failed("Generation was cancelled."))
            } catch let error as TryFavesRenderError {
                self.finish(lookID: lookID, state: .failed(error.shopperMessage))
            } catch {
                self.finish(lookID: lookID, state: .failed("The look couldn't be generated."))
            }
        }
    }

    private func render(outfit: TryFavesOutfit, lookID: UUID) async throws -> UIImage {
        let client = FashnQueueClient()
        let avatar = try Self.seedAvatarDataURI()

        func pass(
            model: String,
            garment: TryOnGarment,
            phase: JobPhase
        ) async throws -> (image: UIImage, hostedURL: String) {
            activeJob?.phase = phase
            // One automatic retry per pass covers transient queue failures and
            // bad frames; anything after that becomes a user-visible retry.
            var lastError: Error = TryFavesRenderError.generationFailed
            for _ in 0..<2 {
                do {
                    let output = try await client.generate(
                        modelImage: model,
                        garment: garment
                    )
                    activeJob?.phase = .validating
                    let image = try Self.validated(output.imageData)
                    return (image, output.hostedURL)
                } catch {
                    lastError = error
                    try Task.checkCancellation()
                }
            }
            throw lastError
        }

        switch outfit {
        case let .onePiece(garment):
            // One-pieces are a single FASHN request.
            return try await pass(model: avatar, garment: garment, phase: .applyingOnePiece).image

        case let .separates(top, bottom):
            // Bottoms first, then the top applied to the intermediate result.
            // The intermediate stays on fal's CDN, so the second pass passes a
            // URL instead of re-uploading pixels.
            let intermediate = try await pass(model: avatar, garment: bottom, phase: .applyingBottoms)
            return try await pass(model: intermediate.hostedURL, garment: top, phase: .applyingTop).image
        }
    }

    private func finish(lookID: UUID, state: LookState) {
        update(lookID: lookID) { $0.state = state }
        if state == .ready { unseenLookID = lookID }
        activeJob = nil
        generationTask = nil
        persistLooks()
    }

    private func update(lookID: UUID, _ transform: (inout Look) -> Void) {
        guard let index = looks.firstIndex(where: { $0.id == lookID }) else { return }
        transform(&looks[index])
    }

    private static func outfit(from garments: [TryOnGarment]) -> TryFavesOutfit? {
        if garments.count == 1, garments[0].category == .onePieces {
            return .onePiece(garments[0])
        }
        guard let top = garments.first(where: { $0.category == .tops }),
              let bottom = garments.first(where: { $0.category == .bottoms }) else {
            return nil
        }
        return .separates(top: top, bottom: bottom)
    }

    // MARK: - Output validation

    /// Lightweight guard against missing, blank, corrupted, or badly framed
    /// renders before a look is declared ready.
    private static func validated(_ data: Data) throws -> UIImage {
        guard !data.isEmpty, let image = UIImage(data: data) else {
            throw TryFavesRenderError.invalidOutput
        }
        let size = image.size
        guard size.width >= 256, size.height >= 256 else {
            throw TryFavesRenderError.invalidOutput
        }
        // FASHN composes portrait 2:3 frames. A wildly different aspect means
        // the subject came back badly framed.
        let aspect = size.width / size.height
        guard aspect > 0.4, aspect < 1.1 else {
            throw TryFavesRenderError.invalidOutput
        }
        guard !isEffectivelyBlank(image) else {
            throw TryFavesRenderError.invalidOutput
        }
        return image
    }

    /// Samples a coarse grid of pixels; a near-zero luminance spread means an
    /// empty or single-color frame.
    private static func isEffectivelyBlank(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return true }
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return true }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var minLuma = 255.0
        var maxLuma = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let luma = 0.299 * Double(pixels[index])
                + 0.587 * Double(pixels[index + 1])
                + 0.114 * Double(pixels[index + 2])
            minLuma = min(minLuma, luma)
            maxLuma = max(maxLuma, luma)
        }
        return (maxLuma - minLuma) < 8
    }

    // MARK: - Seed avatar

    static let seedAvatarAssetName = "try-faves-avatar"

    /// SHA-256 of the bundled avatar asset. Part of every cache key so a new
    /// seed avatar invalidates old renders.
    private static let seedAvatarHash: String = {
        guard let data = seedAvatarData() else { return "no-avatar" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }()

    private static func seedAvatarData() -> Data? {
        guard let image = UIImage(named: seedAvatarAssetName) else { return nil }
        return image.pngData()
    }

    /// The avatar as a compact JPEG data URI for the first FASHN pass. fal
    /// accepts data URIs directly, which keeps the seed image out of any
    /// third-party storage. The bundled asset is a background-removed cutout
    /// for the canvas treatment, so it is flattened onto studio white here —
    /// generation models expect an opaque photograph, not transparency.
    private static func seedAvatarDataURI() throws -> String {
        guard let cutout = UIImage(named: seedAvatarAssetName) else {
            throw TryFavesRenderError.missingAvatar
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let flattened = UIGraphicsImageRenderer(size: cutout.size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: cutout.size))
            cutout.draw(in: CGRect(origin: .zero, size: cutout.size))
        }
        guard let jpeg = flattened.jpegData(compressionQuality: 0.9) else {
            throw TryFavesRenderError.missingAvatar
        }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    // MARK: - Render cache

    /// Renders are keyed on avatar hash + ordered variant IDs + model version
    /// + generation settings.
    static func cacheKey(for outfit: TryFavesOutfit) -> String {
        let material = [
            seedAvatarHash,
            outfit.orderedVariantIDs.joined(separator: "+"),
            modelVersion,
            generationSettings,
        ].joined(separator: "|")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TryFavesRenders", isDirectory: true)
    }

    private func loadCachedRender(for cacheKey: String) -> UIImage? {
        let url = Self.cacheDirectory.appendingPathComponent("\(cacheKey).png")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func storeCachedRender(_ image: UIImage, for cacheKey: String) {
        guard let data = image.pngData() else { return }
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheDirectory.appendingPathComponent("\(cacheKey).png"))
    }

    // MARK: - Look persistence

    private static var looksFileURL: URL {
        cacheDirectory.appendingPathComponent("looks.json")
    }

    private func persistLooks() {
        try? FileManager.default.createDirectory(at: Self.cacheDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(looks) else { return }
        try? data.write(to: Self.looksFileURL)
    }

    private static func loadLooks() -> [Look] {
        guard let data = try? Data(contentsOf: looksFileURL),
              let looks = try? JSONDecoder().decode([Look].self, from: data) else {
            return []
        }
        return looks
    }
}

enum TryFavesRenderError: Error {
    case missingAvatar
    case missingConfiguration
    case requestFailed
    case generationFailed
    case timedOut
    case invalidOutput

    var shopperMessage: String {
        switch self {
        case .missingAvatar:
            "The avatar image is missing from this build."
        case .missingConfiguration:
            "Add FAL_TOKEN_ENDPOINT to .env.local to enable look generation."
        case .requestFailed, .generationFailed:
            "The look couldn't be generated."
        case .timedOut:
            "Generation took too long."
        case .invalidOutput:
            "The render came back unusable."
        }
    }
}

/// Minimal client for fal's queue API. Submits a FASHN try-on job, polls its
/// status, and downloads the finished PNG. Each HTTP call is authorized with
/// a fresh short-lived JWT so the underlying fal key stays server-side.
private struct FashnQueueClient {
    struct Output {
        let imageData: Data
        /// The render hosted on fal's CDN — reused as the `model_image` for a
        /// chained pass without re-uploading pixels.
        let hostedURL: String
    }

    private static let submitURL = URL(string: "https://queue.fal.run/\(TryFavesLookService.modelVersion)")!
    private static let requestsBase = URL(string: "https://queue.fal.run/fal-ai/fashn/requests")!
    /// Poll cadence and budget. The product target is P95 under 90 seconds
    /// per look; a single pass gets 100s before it is declared timed out.
    private static let pollInterval: Duration = .seconds(2)
    private static let pollBudget: TimeInterval = 100

    func generate(modelImage: String, garment: TryOnGarment) async throws -> Output {
        let requestID = try await submit(modelImage: modelImage, garment: garment)
        let resultURL = try await waitForCompletion(requestID: requestID)
        return try await fetchResult(from: resultURL)
    }

    private func submit(modelImage: String, garment: TryOnGarment) async throws -> String {
        // FASHN balanced mode, explicit category and photo type, one sample,
        // PNG output. `webhookUrl` is intentionally absent: no server to call
        // back — completion is polled instead.
        let payload: [String: Any] = [
            "model_image": modelImage,
            "garment_image": garment.imageURL,
            "category": garment.category.rawValue,
            "garment_photo_type": garment.photoType.rawValue,
            "mode": "balanced",
            "num_samples": 1,
            "output_format": "png",
        ]
        var request = try await authorizedRequest(url: Self.submitURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let object = try await Self.json(for: request)
        guard let requestID = object["request_id"] as? String else {
            throw TryFavesRenderError.requestFailed
        }
        return requestID
    }

    private func waitForCompletion(requestID: String) async throws -> URL {
        let statusURL = Self.requestsBase
            .appendingPathComponent(requestID)
            .appendingPathComponent("status")
        let deadline = Date().addingTimeInterval(Self.pollBudget)

        while Date() < deadline {
            try Task.checkCancellation()
            let request = try await authorizedRequest(url: statusURL)
            let object = try await Self.json(for: request)
            switch object["status"] as? String {
            case "COMPLETED":
                if let responseURL = (object["response_url"] as? String).flatMap(URL.init(string:)) {
                    return responseURL
                }
                return Self.requestsBase.appendingPathComponent(requestID)
            case "IN_QUEUE", "IN_PROGRESS":
                try await Task.sleep(for: Self.pollInterval)
            default:
                throw TryFavesRenderError.generationFailed
            }
        }
        throw TryFavesRenderError.timedOut
    }

    private func fetchResult(from url: URL) async throws -> Output {
        let request = try await authorizedRequest(url: url)
        let object = try await Self.json(for: request)
        guard let images = object["images"] as? [[String: Any]],
              let hostedURL = images.first?["url"] as? String,
              let imageURL = URL(string: hostedURL) else {
            throw TryFavesRenderError.generationFailed
        }
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        return Output(imageData: data, hostedURL: hostedURL)
    }

    private func authorizedRequest(url: URL) async throws -> URLRequest {
        let token: String
        do {
            token = try await FalTokenProvider().token(for: "fal-ai/fashn")
        } catch {
            throw TryFavesRenderError.missingConfiguration
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func json(for request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TryFavesRenderError.requestFailed
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TryFavesRenderError.requestFailed
        }
        return object
    }
}
