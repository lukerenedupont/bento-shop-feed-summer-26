import AVFoundation
import Foundation
import LiveKitWebRTC
import SwiftMsgpack
import UIKit

enum DecartProductMode: Equatable {
    case wearable
    case object

    init(product: ResolvedStoryProduct) {
        let searchableText = Self.normalized(
            ([product.product.productType, product.product.title] + product.product.tags)
                .compactMap { $0 }
                .joined(separator: " ")
        )

        self = Self.wearableKeywords.contains { keyword in
            searchableText.contains(" \(Self.normalized(keyword).trimmingCharacters(in: .whitespaces)) ")
        } ? .wearable : .object
    }

    var falApp: String {
        switch self {
        case .wearable: "decart/lucy2-vton"
        case .object: "decart/lucy-2-5"
        }
    }

    var label: String {
        switch self {
        case .wearable: "TRY ON"
        case .object: "PLACE"
        }
    }

    var systemImage: String {
        switch self {
        case .wearable: "tshirt.fill"
        case .object: "cube.fill"
        }
    }

    func applyingStatus(for product: ResolvedStoryProduct) -> String {
        switch self {
        case .wearable: "Trying on \(product.product.title)…"
        case .object: "Placing \(product.product.title)…"
        }
    }

    func prompt(for product: ResolvedStoryProduct) -> String {
        guard self == .object else {
            return "Substitute the current top with the outfit from the reference image, matching its color, material, and fit."
        }

        let productName = product.product.title
        let productType = product.product.productType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = productType.flatMap { $0.isEmpty ? nil : $0 } ?? "product"
        let searchableText = Self.normalized("\(descriptor) \(productName)")

        let placement: String
        if Self.containsAny(searchableText, keywords: ["mirror", "print", "poster", "artwork", "wall art"]) {
            placement = "Mount it naturally on the most visible wall, fully in frame."
        } else if Self.containsAny(searchableText, keywords: [
            "chair", "stool", "table", "dresser", "crib", "bed", "furniture", "rug", "mat",
        ]) {
            placement = "Place it naturally on the floor in the clearest open area, fully in frame."
        } else if Self.containsAny(searchableText, keywords: [
            "mug", "cup", "glass", "bottle", "book", "binocular", "kettle", "coffee maker",
            "phone", "flatware", "vase", "bowl",
        ]) {
            placement = "Place it naturally on the nearest clear surface, fully visible and at realistic scale."
        } else {
            placement = "Place it naturally in the clearest open area of the scene, fully visible and at realistic scale."
        }

        return """
        Add the exact \(productName), a \(descriptor), from the reference image to the live scene. \
        \(placement) Preserve its exact shape, proportions, color, materials, markings, and logos. \
        Match the scene's perspective, lighting, contact shadows, and scale. Keep everything else unchanged.
        """
    }

    private static let wearableKeywords = [
        "apparel", "clothing", "footwear", "shoe", "shoes", "sneaker", "sneakers", "boot", "boots",
        "sandal", "sandals", "shirt", "t shirt", "tee", "tank top", "crop top", "blouse", "sweater", "hoodie", "fleece",
        "jacket", "outerwear", "coat", "dress", "skirt", "pants", "trousers", "jeans", "shorts",
        "swimwear", "headwear", "hat", "baseball cap", "beanie", "bracelet", "necklace", "watch", "eyewear", "sunglasses",
        "backpack", "handbag",
    ]

    private static func normalized(_ value: String) -> String {
        let words = value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        return " \(words.joined(separator: " ")) "
    }

    private static func containsAny(_ normalizedText: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            normalizedText.contains(" \(normalized(keyword).trimmingCharacters(in: .whitespaces)) ")
        }
    }
}

@MainActor
final class DecartTryOnSession: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case starting
        case live
        case applying
        case simulator
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var detail = ""
    @Published private(set) var localVideoTrack: LKRTCVideoTrack?
    @Published private(set) var remoteVideoTrack: LKRTCVideoTrack?
    @Published private(set) var activeMode: DecartProductMode?
    @Published private(set) var needsCameraSettings = false

    private var factory: LKRTCPeerConnectionFactory?
    private var cameraSource: LKRTCVideoSource?
    private var cameraCapturer: LKRTCCameraVideoCapturer?
    private var cameraDevice: AVCaptureDevice?
    private var peerConnection: LKRTCPeerConnection?
    private var socket: FalRealtimeSocket?
    private var remoteDescriptionIsSet = false
    private var queuedRemoteCandidates: [LKRTCIceCandidate] = []
    private var readyFallbackTask: Task<Void, Never>?
    private var applyTask: Task<Void, Never>?

    var isConnected: Bool {
        peerConnection?.connectionState == .connected && (phase == .live || phase == .applying)
    }

    var isBusy: Bool { phase == .starting || phase == .applying }

    var statusText: String {
        switch phase {
        case .idle: "Turn on your camera"
        case .starting: detail.isEmpty ? "Connecting to the studio…" : detail
        case .live: detail
        case .applying: detail.isEmpty ? "Transforming…" : detail
        case .simulator: "Live camera requires an iPhone"
        case .failed(let message): message
        }
    }

    func start(product: ResolvedStoryProduct?) async {
        guard phase == .idle || phase == .simulator || isFailure else { return }

#if targetEnvironment(simulator)
        phase = .simulator
        detail = "Browse every product here, then run on a real device for fal’s live stream."
        return
#else
        phase = .starting
        detail = "Starting camera…"
        needsCameraSettings = false

        do {
            try await ensureCameraPermission()
            try await startCamera()
            if let product {
                apply(product: product)
            } else {
                phase = .live
                detail = "Choose a product to begin"
            }
        } catch {
            await stopTransportAndCamera()
            needsCameraSettings = (error as? FalTryOnError) == .cameraPermissionDenied
            phase = .failed(Self.message(for: error))
        }
#endif
    }

    func apply(product: ResolvedStoryProduct) {
        let previousTask = applyTask
        applyTask?.cancel()
        phase = .applying
        let mode = DecartProductMode(product: product)
        detail = mode.applyingStatus(for: product)

        applyTask = Task { [weak self] in
            await previousTask?.value
            guard let self else { return }

            do {
                try Task.checkCancellation()
                let referenceImageURL = try await Self.referenceImageDataURL(for: product)
                let input: [String: Any] = [
                    "prompt": mode.prompt(for: product),
                    "reference_image_url": referenceImageURL,
                    // fal bootstraps the WebRTC worker from the first image
                    // message, then hands subsequent frames to the RTC track.
                    "image_url": referenceImageURL,
                ]

                if mode != activeMode || socket == nil {
                    detail = mode == .object ? "Opening object studio…" : "Opening fitting studio…"
                    try await connect(for: mode, input: input)
                } else {
                    try await socket?.send(input)
                }

                try Task.checkCancellation()
                phase = .live
                detail = ""
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(Self.message(for: error))
            }
        }
    }

    func switchCamera() async {
        guard let capturer = cameraCapturer else { return }
        let currentPosition = cameraDevice?.position ?? .front
        let desired: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        guard let device = LKRTCCameraVideoCapturer.captureDevices().first(where: { $0.position == desired }),
              let format = Self.captureFormat(for: device) else { return }

        await withCheckedContinuation { continuation in
            capturer.stopCapture {
                capturer.startCapture(with: device, format: format, fps: Self.captureFPS(for: format)) { [weak self] error in
                    Task { @MainActor in
                        if error == nil { self?.cameraDevice = device }
                        continuation.resume()
                    }
                }
            }
        }
    }

    func stop() async {
        let pendingApply = applyTask
        pendingApply?.cancel()
        applyTask = nil
        readyFallbackTask?.cancel()
        readyFallbackTask = nil
        await pendingApply?.value
        await stopTransportAndCamera()
        phase = .idle
        detail = ""
        activeMode = nil
        needsCameraSettings = false
    }

    private var isFailure: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func ensureCameraPermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                throw FalTryOnError.cameraPermissionDenied
            }
        case .denied, .restricted: throw FalTryOnError.cameraPermissionDenied
        @unknown default: throw FalTryOnError.cameraPermissionDenied
        }
    }

    private func startCamera() async throws {
        LKRTCInitializeSSL()
        let factory = LKRTCPeerConnectionFactory()
        let source = factory.videoSource()
        let capturer = LKRTCCameraVideoCapturer(delegate: source)
        guard let device = LKRTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front }),
              let format = Self.captureFormat(for: device) else {
            throw FalTryOnError.cameraUnavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            capturer.startCapture(with: device, format: format, fps: Self.captureFPS(for: format)) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }

        self.factory = factory
        cameraSource = source
        cameraCapturer = capturer
        cameraDevice = device
        localVideoTrack = factory.videoTrack(with: source, trackId: "shop-try-it-live-camera")
    }

    private func connect(for mode: DecartProductMode, input: [String: Any]) async throws {
        guard localVideoTrack != nil else { throw FalTryOnError.cameraUnavailable }
        await stopTransport()
        try Task.checkCancellation()

        let token = try await FalTokenProvider().token(for: mode.falApp)
        guard var components = URLComponents(string: "wss://fal.run/\(mode.falApp)/realtime") else {
            throw FalTryOnError.invalidRealtimeURL
        }
        components.queryItems = [URLQueryItem(name: "fal_jwt_token", value: token)]
        guard let url = components.url else { throw FalTryOnError.invalidRealtimeURL }

        let socket = FalRealtimeSocket(
            onMessage: { [weak self] message in
                Task { @MainActor in await self?.handleRealtimeMessage(message) }
            },
            onDisconnect: { [weak self] error in
                Task { @MainActor in self?.handleSocketDisconnect(error) }
            }
        )
        self.socket = socket
        try await socket.connect(to: url)
        try Task.checkCancellation()
        activeMode = mode
        try await socket.send(input)
    }

    private func handleRealtimeMessage(_ message: [String: Any]) async {
        guard let type = message["type"] as? String else { return }

        switch type.lowercased() {
        case "ready":
            guard peerConnection == nil else { return }
            readyFallbackTask?.cancel()
            readyFallbackTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                try? await self?.setupPeerConnection(iceServers: [])
            }
        case "iceservers":
            readyFallbackTask?.cancel()
            readyFallbackTask = nil
            let rawServers = (message["iceServers"] ?? message["ice_servers"] ?? message["iceservers"]) as? [[String: Any]] ?? []
            do { try await setupPeerConnection(iceServers: Self.iceServers(from: rawServers)) }
            catch { phase = .failed(Self.message(for: error)) }
        case "answer":
            guard let sdp = message["sdp"] as? String else { return }
            do { try await applyAnswer(sdp) }
            catch { phase = .failed(Self.message(for: error)) }
        case "icecandidate":
            guard let payload = message["candidate"] as? [String: Any],
                  let candidate = Self.iceCandidate(from: payload) else { return }
            if remoteDescriptionIsSet {
                try? await peerConnection?.add(candidate)
            } else {
                queuedRemoteCandidates.append(candidate)
            }
        case "x-fal-error":
            let reason = message["reason"] as? String
            phase = .failed(reason?.isEmpty == false
                ? "The live studio couldn’t start: \(reason!)"
                : "The live studio couldn’t start. Please try again.")
        default:
            break
        }
    }

    private func setupPeerConnection(iceServers: [LKRTCIceServer]) async throws {
        guard peerConnection == nil, let factory, let localVideoTrack else { return }
        let configuration = LKRTCConfiguration()
        configuration.sdpSemantics = .unifiedPlan
        configuration.iceServers = iceServers
        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        guard let peer = factory.peerConnection(with: configuration, constraints: constraints, delegate: self) else {
            throw FalTryOnError.peerConnectionFailed
        }
        peerConnection = peer
        guard peer.add(localVideoTrack, streamIds: ["shop-camera"]) != nil else {
            throw FalTryOnError.peerConnectionFailed
        }

        let offer = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LKRTCSessionDescription, Error>) in
            let offerConstraints = LKRTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveVideo": "true", "OfferToReceiveAudio": "false"],
                optionalConstraints: nil
            )
            peer.offer(for: offerConstraints) { description, error in
                if let error { continuation.resume(throwing: error) }
                else if let description { continuation.resume(returning: description) }
                else { continuation.resume(throwing: FalTryOnError.peerConnectionFailed) }
            }
        }
        try await setLocalDescription(offer, on: peer)
        try await socket?.send(["type": "offer", "sdp": offer.sdp])
    }

    private func applyAnswer(_ sdp: String) async throws {
        guard let peerConnection else { return }
        let answer = LKRTCSessionDescription(type: .answer, sdp: sdp)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection.setRemoteDescription(answer) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
        remoteDescriptionIsSet = true
        let candidates = queuedRemoteCandidates
        queuedRemoteCandidates.removeAll()
        for candidate in candidates {
            try await peerConnection.add(candidate)
        }
    }

    private func setLocalDescription(_ description: LKRTCSessionDescription, on peer: LKRTCPeerConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peer.setLocalDescription(description) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func handleSocketDisconnect(_ error: Error?) {
        guard socket != nil, phase != .idle else { return }
        phase = .failed(error == nil
            ? "The live studio disconnected. Tap to try again."
            : Self.message(for: error!))
    }

    private func stopTransport() async {
        readyFallbackTask?.cancel()
        readyFallbackTask = nil
        socket?.close()
        socket = nil
        peerConnection?.close()
        peerConnection = nil
        remoteVideoTrack = nil
        remoteDescriptionIsSet = false
        queuedRemoteCandidates.removeAll()
        activeMode = nil
    }

    private func stopTransportAndCamera() async {
        await stopTransport()
        if let cameraCapturer {
            await withCheckedContinuation { continuation in
                cameraCapturer.stopCapture { continuation.resume() }
            }
        }
        cameraCapturer = nil
        cameraDevice = nil
        cameraSource = nil
        localVideoTrack = nil
        factory = nil
        LKRTCCleanupSSL()
    }

    private static func referenceImageDataURL(for product: ResolvedStoryProduct) async throws -> String {
        guard let imageURL = product.product.imageURL, let url = URL(string: imageURL) else {
            throw FalTryOnError.invalidProductImage
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let image = UIImage(data: data) else {
            throw FalTryOnError.productImageDownloadFailed
        }
        let maximumSide: CGFloat = 512
        let scale = min(1, maximumSide / max(image.size.width, image.size.height))
        let size = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.78) else {
            throw FalTryOnError.invalidProductImage
        }
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }

    private static func captureFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        LKRTCCameraVideoCapturer.supportedFormats(for: device).min { lhs, rhs in
            let left = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let right = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            let leftDistance = abs(Int(left.width) - 720) + abs(Int(left.height) - 1280)
            let rightDistance = abs(Int(right.width) - 720) + abs(Int(right.height) - 1280)
            return leftDistance < rightDistance
        }
    }

    private static func captureFPS(for format: AVCaptureDevice.Format) -> Int {
        let maximum = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
        return min(30, max(15, Int(maximum)))
    }

    private static func iceServers(from payloads: [[String: Any]]) -> [LKRTCIceServer] {
        payloads.compactMap { payload in
            let urls: [String]
            if let values = payload["urls"] as? [String] { urls = values }
            else if let value = payload["urls"] as? String { urls = [value] }
            else { return nil }
            return LKRTCIceServer(
                urlStrings: urls,
                username: payload["username"] as? String,
                credential: payload["credential"] as? String
            )
        }
    }

    private static func iceCandidate(from payload: [String: Any]) -> LKRTCIceCandidate? {
        guard let candidate = payload["candidate"] as? String else { return nil }
        let lineIndex: Int32
        if let value = payload["sdpMLineIndex"] as? Int { lineIndex = Int32(value) }
        else if let value = payload["sdpMLineIndex"] as? NSNumber { lineIndex = value.int32Value }
        else { lineIndex = 0 }
        return LKRTCIceCandidate(
            sdp: candidate,
            sdpMLineIndex: lineIndex,
            sdpMid: payload["sdpMid"] as? String
        )
    }

    private static func message(for error: Error) -> String {
        if let error = error as? FalTryOnError {
            return error.errorDescription ?? "Couldn’t start the live studio."
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return "Check your connection and try again." }
        let lowered = error.localizedDescription.lowercased()
        if lowered.contains("permission") || lowered.contains("denied") {
            return "Camera access is off. Enable it in Settings and try again."
        }
        if lowered.contains("401") || lowered.contains("403") || lowered.contains("unauthorized") {
            return "The fal session token was rejected. Check the Shopify AI proxy configuration."
        }
        return "Couldn’t start the live studio. Please try again."
    }
}

extension DecartTryOnSession: LKRTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {}
    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {}

    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            var candidatePayload: [String: Any] = [
                "candidate": candidate.sdp,
                "sdpMLineIndex": Int(candidate.sdpMLineIndex),
            ]
            if let sdpMid = candidate.sdpMid {
                candidatePayload["sdpMid"] = sdpMid
            }
            try? await socket?.send([
                "type": "icecandidate",
                "candidate": candidatePayload,
            ])
        }
    }

    nonisolated func peerConnection(
        _ peerConnection: LKRTCPeerConnection,
        didAdd receiver: LKRTCRtpReceiver,
        streams: [LKRTCMediaStream]
    ) {
        guard let track = receiver.track as? LKRTCVideoTrack else { return }
        Task { @MainActor [weak self] in
            self?.remoteVideoTrack = track
            if self?.phase != .applying { self?.phase = .live }
            self?.detail = ""
        }
    }

    nonisolated func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCPeerConnectionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch newState {
            case .connected:
                if phase != .applying { phase = .live }
                detail = ""
            case .failed, .disconnected:
                phase = .failed("The live studio disconnected. Tap to try again.")
            default:
                break
            }
        }
    }
}

/// Mints short-lived fal JWTs from the server-side token endpoint. Shared by
/// the live Decart studio and the Try your faves FASHN pipeline so the fal
/// API key itself never ships in the app.
struct FalTokenProvider {
    func token(for app: String) async throws -> String {
        let values = Self.configurationValues()

        if let rawEndpoint = values["FAL_TOKEN_ENDPOINT"],
           !rawEndpoint.isEmpty,
           let endpoint = URL(string: rawEndpoint) {
            return try await requestToken(from: endpoint, app: app, authorization: nil)
        }

#if DEBUG
        if let proxyKey = values["SHOPIFY_PROXY_KEY"], !proxyKey.isEmpty,
           let endpoint = URL(string: "https://proxy.shopify.ai/vendors/fal-rest-alpha/tokens/") {
            return try await requestToken(from: endpoint, app: app, authorization: "Bearer \(proxyKey)")
        }
#endif
        throw FalTryOnError.missingConfiguration
    }

    private func requestToken(from endpoint: URL, app: String, authorization: String?) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authorization { request.setValue(authorization, forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "allowed_apps": [app],
            "token_expiration": 60,
            "extra_data": ["prototype": "shop-feed-summer-26"],
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FalTryOnError.tokenRequestFailed
        }
        if let token = try? JSONDecoder().decode(String.self, from: data), !token.isEmpty { return token }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = (object["token"] ?? object["jwt"] ?? object["access_token"]) as? String,
           !token.isEmpty { return token }
        throw FalTryOnError.tokenRequestFailed
    }

    /// Merged configuration: process environment, Info.plist, and (DEBUG) the
    /// bundled ShopServer.env copied from `.env.local`. Shared with the
    /// Try your faves FASHN client so both prototypes read the same keys.
    static func configurationValues() -> [String: String] {
        var values = ProcessInfo.processInfo.environment
        if let endpoint = Bundle.main.object(forInfoDictionaryKey: "FalTokenEndpoint") as? String,
           !endpoint.isEmpty, !endpoint.contains("$(") {
            values["FAL_TOKEN_ENDPOINT"] = endpoint
        }
#if DEBUG
        if let url = Bundle.main.url(forResource: "ShopServer", withExtension: "env"),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            for line in contents.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else { continue }
                let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespacesAndNewlines)
                var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if value.hasPrefix("\"") && value.hasSuffix("\"") { value.removeFirst(); value.removeLast() }
                values[key] = value
            }
        }
#endif
        return values
    }
}

private final class FalRealtimeSocket: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let onMessage: @Sendable ([String: Any]) -> Void
    private let onDisconnect: @Sendable (Error?) -> Void
    private let lock = NSLock()
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var openContinuation: CheckedContinuation<Void, Error>?
    private var intentionallyClosed = false

    init(
        onMessage: @escaping @Sendable ([String: Any]) -> Void,
        onDisconnect: @escaping @Sendable (Error?) -> Void
    ) {
        self.onMessage = onMessage
        self.onDisconnect = onDisconnect
    }

    func connect(to url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            openContinuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.webSocketTask(with: url)
            self.session = session
            self.task = task
            lock.unlock()
            task.resume()
        }
    }

    func send(_ object: [String: Any]) async throws {
        guard JSONSerialization.isValidJSONObject(object) else { throw FalTryOnError.invalidRealtimeMessage }
        let json = try JSONSerialization.data(withJSONObject: object)
        let encodable = try JSONDecoder().decode([String: AnyCodable].self, from: json)
        let payload = try MsgPackEncoder().encode(encodable)
        guard let task else {
            throw FalTryOnError.realtimeDisconnected
        }
        try await task.send(.data(payload))
    }

    func close() {
        lock.lock()
        intentionallyClosed = true
        let continuation = openContinuation
        openContinuation = nil
        let task = task
        let session = session
        self.task = nil
        self.session = nil
        lock.unlock()
        continuation?.resume(throwing: CancellationError())
        task?.cancel(with: .normalClosure, reason: nil)
        session?.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        lock.lock()
        let continuation = openContinuation
        openContinuation = nil
        lock.unlock()
        continuation?.resume()
        receiveNext()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        finish(error: nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(error: error) }
    }

    private func receiveNext() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if let object = Self.decode(message) { onMessage(object) }
                receiveNext()
            case .failure(let error):
                finish(error: error)
            }
        }
    }

    private func finish(error: Error?) {
        lock.lock()
        let continuation = openContinuation
        openContinuation = nil
        let shouldNotify = !intentionallyClosed
        lock.unlock()
        continuation?.resume(throwing: error ?? FalTryOnError.realtimeDisconnected)
        if shouldNotify { onDisconnect(error) }
    }

    private static func decode(_ message: URLSessionWebSocketTask.Message) -> [String: Any]? {
        switch message {
        case .string(let string):
            return (try? JSONSerialization.jsonObject(with: Data(string.utf8))) as? [String: Any]
        case .data(let value):
            guard let decoded = try? MsgPackDecoder().decode([String: AnyCodable].self, from: value) else {
                return nil
            }
            return decoded.mapValues { unwrap($0) }
        @unknown default: return nil
        }
    }

    private static func unwrap(_ value: Any) -> Any {
        if let value = value as? AnyCodable { return unwrap(value.base) }
        if let values = value as? [AnyCodable] { return values.map { unwrap($0) } }
        if let values = value as? [AnyCodable: AnyCodable] {
            var result: [String: Any] = [:]
            for (key, value) in values {
                guard let key = unwrap(key) as? String else { continue }
                result[key] = unwrap(value)
            }
            return result
        }
        return value
    }
}

private enum FalTryOnError: LocalizedError, Equatable {
    case missingConfiguration
    case tokenRequestFailed
    case invalidProductImage
    case productImageDownloadFailed
    case cameraUnavailable
    case cameraPermissionDenied
    case invalidRealtimeURL
    case invalidRealtimeMessage
    case realtimeDisconnected
    case peerConnectionFailed

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "Add FAL_TOKEN_ENDPOINT to .env.local. Debug builds can use the local SHOPIFY_PROXY_KEY fallback."
        case .tokenRequestFailed:
            "Couldn’t create a fal session through Shopify’s AI proxy."
        case .invalidProductImage, .productImageDownloadFailed:
            "That product image couldn’t be sent to the live studio. Try another item."
        case .cameraUnavailable:
            "The camera stopped unexpectedly. Reopen the live studio and try again."
        case .cameraPermissionDenied:
            "Camera access is off. Allow it in Settings to use the live studio."
        case .invalidRealtimeURL, .invalidRealtimeMessage, .realtimeDisconnected, .peerConnectionFailed:
            "Couldn’t connect to fal’s live studio. Please try again."
        }
    }
}
