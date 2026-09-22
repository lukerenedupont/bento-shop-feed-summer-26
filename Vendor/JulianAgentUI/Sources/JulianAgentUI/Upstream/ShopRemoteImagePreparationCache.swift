import CoreGraphics
import Foundation
import Nuke
import os

/// Bounded, thread-safe memoization for deterministic image-preparation values, so body
/// evaluations with unchanged inputs don't repeat URL parsing and request construction.
/// Entries are tiny and rebuildable; decoded image data stays in Nuke's own caches.
final class ShopRemoteImageMemoCache<Key: Hashable & Sendable, Value: Sendable>: Sendable {
    private let maximumEntryCount: Int
    private let entries: OSAllocatedUnfairLock<[Key: Value]>

    init(maximumEntryCount: Int) {
        self.maximumEntryCount = max(maximumEntryCount, 1)
        self.entries = OSAllocatedUnfairLock(initialState: [:])
    }

    var entryCount: Int {
        entries.withLock { $0.count }
    }

    /// `compute` runs outside the lock; duplicate concurrent computes are deterministic.
    func value(for key: Key, compute: () -> Value) -> Value {
        if let cached = entries.withLock({ $0[key] }) {
            return cached
        }

        let value = compute()
        entries.withLock { entries in
            if entries[key] == nil,
               entries.count >= maximumEntryCount,
               let keyToEvict = entries.keys.first {
                entries.removeValue(forKey: keyToEvict)
            }
            entries[key] = value
        }
        return value
    }

    func removeAll() {
        entries.withLock { $0.removeAll(keepingCapacity: true) }
    }
}

/// Every input that affects a prepared request; any change produces a new cache key.
struct ShopRemoteImagePreparedRequestKey: Hashable, Sendable {
    let sourceURL: String
    let requestWidth: CGFloat
    let requestHeight: CGFloat
    let displayScale: CGFloat
    let contentMode: ImageProcessingOptions.ContentMode
}

extension ShopRemoteImageRequestBuilder {
    private static let preparedRequestCache = ShopRemoteImageMemoCache<
        ShopRemoteImagePreparedRequestKey,
        ShopRemoteImagePreparedRequest?
    >(maximumEntryCount: 512)

    /// Memoized `prepare`; failed preparations are memoized too.
    static func preparedRequest(
        sourceURL: String,
        requestSize: CGSize,
        displayScale: CGFloat,
        contentMode: ImageProcessingOptions.ContentMode
    ) -> ShopRemoteImagePreparedRequest? {
        let key = ShopRemoteImagePreparedRequestKey(
            sourceURL: sourceURL,
            requestWidth: requestSize.width,
            requestHeight: requestSize.height,
            displayScale: displayScale,
            contentMode: contentMode
        )
        return preparedRequestCache.value(for: key) {
            prepare(
                sourceURL: sourceURL,
                requestSize: requestSize,
                displayScale: displayScale,
                contentMode: contentMode
            )
        }
    }
}

extension ShopRemoteImagePreviewIdentity {
    private static let identityCache = ShopRemoteImageMemoCache<
        String,
        ShopRemoteImagePreviewIdentity?
    >(maximumEntryCount: 512)

    /// Memoized `make(from:)`.
    static func cachedIdentity(for sourceURL: String) -> ShopRemoteImagePreviewIdentity? {
        identityCache.value(for: sourceURL) {
            make(from: sourceURL)
        }
    }
}

extension ShopRemoteImageGIF {
    private static let animatedURLCache = ShopRemoteImageMemoCache<String, URL?>(maximumEntryCount: 128)

    /// Memoized `animatedURL(for:)`.
    static func cachedAnimatedURL(for sourceURL: String) -> URL? {
        animatedURLCache.value(for: sourceURL) {
            animatedURL(for: sourceURL)
        }
    }
}
