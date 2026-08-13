#if DEBUG
import Foundation
import SwiftUI
import Darwin
import os.log

private let purlTuneLog = OSLog(subsystem: "com.shopify.purl", category: "inject")

private struct PurlTunePayload: Decodable {
    var version: Int?
    var sequence: Int
    var sourceFile: String
    var values: [String: String]
    var writtenAt: TimeInterval
}

private struct PendingPurlTunePayload {
    var url: URL
    var payload: PurlTunePayload
}

private struct PurlTuneRevisionKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var purlTuneRevision: Int {
        get { self[PurlTuneRevisionKey.self] }
        set { self[PurlTuneRevisionKey.self] = newValue }
    }
}

@MainActor
final class PurlTuneRuntime: ObservableObject {
    static let shared = PurlTuneRuntime()

    @Published private(set) var revision = 0

    private var values: [String: String] = [:]
    private var processedFiles: Set<String> = []
    private var source: DispatchSourceFileSystemObject?
    private var pollingTimer: Timer?
    private var directoryFileDescriptor: CInt = -1

    private var eventsDirectoryURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("purl-reload", isDirectory: true)
            .appendingPathComponent("events", isDirectory: true)
    }

    private init() {}

    func install() {
        do {
            try FileManager.default.createDirectory(
                at: eventsDirectoryURL,
                withIntermediateDirectories: true
            )
            processPendingPayloads()
            startWatcher()
            startPollingFallback()
            os_log("[PURL_INJECT] installed bridge=filesystem path=%{public}@",
                   log: purlTuneLog,
                   type: .info,
                   eventsDirectoryURL.path)
        } catch {
            os_log("[PURL_INJECT] error message=%{public}@",
                   log: purlTuneLog,
                   type: .error,
                   error.localizedDescription)
        }
    }

    func floatingValue<T: BinaryFloatingPoint>(_ key: String, default defaultValue: T) -> T {
        guard let raw = values[key], let value = Double(raw) else { return defaultValue }
        return T(value)
    }

    func integerValue<T: BinaryInteger>(_ key: String, default defaultValue: T) -> T {
        guard let raw = values[key], let value = Double(raw) else { return defaultValue }
        return T(value.rounded())
    }

    /// Resolve a token-typed Tune value. The bridge stores the picked token
    /// member name (e.g. "space16") and we look it up in the caller-supplied
    /// options table to recover the concrete numeric value. Falls back to the
    /// default literal when the registry has no entry yet or the stored name
    /// is unknown.
    func tokenValue<T>(_ key: String, default defaultValue: T, options: [String: T]) -> T {
        guard let raw = values[key] else { return defaultValue }
        // The bridge writes the picked literal back to source as
        // "Namespace.member", and that same string also lands in the JSON
        // payload values map. Accept either "member" or "Namespace.member"
        // so callers don't have to know which form the bridge picked.
        let member: String
        if let dot = raw.lastIndex(of: ".") {
            member = String(raw[raw.index(after: dot)...])
        } else {
            member = raw
        }
        guard let resolved = options[member] else { return defaultValue }
        return resolved
    }

    private func startWatcher() {
        guard source == nil else { return }
        directoryFileDescriptor = open(eventsDirectoryURL.path, O_EVTONLY)
        guard directoryFileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: directoryFileDescriptor,
            eventMask: [.write, .extend, .attrib, .link, .rename],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.processPendingPayloads()
        }
        source.setCancelHandler { [directoryFileDescriptor] in
            close(directoryFileDescriptor)
        }
        source.resume()
        self.source = source
    }

    private func startPollingFallback() {
        guard pollingTimer == nil else { return }
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingPayloads()
            }
        }
    }

    private func processPendingPayloads() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: eventsDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // Two things care about this list: the FS watcher (fires on every
        // create + write) and the 0.25 s polling fallback. Both run on the
        // main actor so they serialize, but to keep things bulletproof we
        // claim each candidate file's name into processedFiles *before*
        // decoding. If decoding fails (the writer is still flushing), the
        // claim is released so the next tick retries.
        let candidates = files
            .filter { $0.pathExtension == "json" && !processedFiles.contains($0.lastPathComponent) }
        guard !candidates.isEmpty else { return }

        for url in candidates {
            processedFiles.insert(url.lastPathComponent)
        }

        let payloads = candidates
            .compactMap { url -> PendingPurlTunePayload? in
                guard let data = try? Data(contentsOf: url), !data.isEmpty else {
                    processedFiles.remove(url.lastPathComponent)
                    return nil
                }
                guard let payload = try? JSONDecoder().decode(PurlTunePayload.self, from: data) else {
                    // Most likely a partial write from the host. Release the
                    // claim so the next polling tick can pick it up once the
                    // writer flushes.
                    processedFiles.remove(url.lastPathComponent)
                    return nil
                }
                return PendingPurlTunePayload(url: url, payload: payload)
            }
            .sorted { lhs, rhs in
                lhs.payload.sequence < rhs.payload.sequence
            }

        for pending in payloads {
            applyPayload(pending.payload, from: pending.url)
        }
    }

    private func applyPayload(_ payload: PurlTunePayload, from url: URL) {
        for (key, value) in payload.values {
            values[key] = value
        }
        revision += 1

        NotificationCenter.default.post(
            name: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"),
            object: nil
        )
        os_log("[PURL_INJECT] applied timestamp=%{public}f sequence=%{public}d source=%{public}@",
               log: purlTuneLog,
               type: .info,
               Date().timeIntervalSince1970,
               payload.sequence,
               payload.sourceFile)
    }
}

@MainActor
enum PurlTune {
    static func value<T: BinaryFloatingPoint>(_ key: String, default defaultValue: T) -> T {
        PurlTuneRuntime.shared.floatingValue(key, default: defaultValue)
    }

    static func value<T: BinaryInteger>(_ key: String, default defaultValue: T) -> T {
        PurlTuneRuntime.shared.integerValue(key, default: defaultValue)
    }

    static func token<T>(_ key: String, default defaultValue: T, options: [String: T]) -> T {
        PurlTuneRuntime.shared.tokenValue(key, default: defaultValue, options: options)
    }
}
#else
@MainActor
enum PurlTune {
    static func value<T: BinaryFloatingPoint>(_ key: String, default defaultValue: T) -> T {
        defaultValue
    }

    static func value<T: BinaryInteger>(_ key: String, default defaultValue: T) -> T {
        defaultValue
    }

    static func token<T>(_ key: String, default defaultValue: T, options: [String: T]) -> T {
        defaultValue
    }
}
#endif
