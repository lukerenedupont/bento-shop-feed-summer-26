import SwiftUI
import Gravity
import UIKit

/// Web parity (`useOmniboxImageAttachment.MAX_IMAGES`).
let shopAgentMaxImageAttachments = 5

/// Feeds the picker's own selection limit. Capping the picker rather than trimming afterwards keeps
/// the loader from writing temporary files for images that would only be discarded.
func shopAgentRemainingImageAttachmentSlots(alreadyAttached: Int) -> Int {
    max(0, shopAgentMaxImageAttachments - alreadyAttached)
}

struct ShopAgentImageAttachmentAsset: Hashable, Sendable {
    let fileURL: URL
    let mimeType: String
    let byteCount: Int
    let sourceIdentifier: String?

    init(
        fileURL: URL,
        mimeType: String,
        byteCount: Int,
        sourceIdentifier: String? = nil
    ) {
        self.fileURL = fileURL
        self.mimeType = mimeType
        self.byteCount = byteCount
        self.sourceIdentifier = sourceIdentifier
    }
}

enum ShopAgentImageAttachmentUploadState: Hashable, Sendable {
    case uploading
    case uploaded(imageID: String)
}

struct ShopAgentImageAttachment: Identifiable, Hashable, Sendable {
    let id: UUID
    let fileURL: URL
    let mimeType: String
    let byteCount: Int
    var uploadState: ShopAgentImageAttachmentUploadState

    init(
        id: UUID = UUID(),
        asset: ShopAgentImageAttachmentAsset,
        uploadState: ShopAgentImageAttachmentUploadState = .uploading
    ) {
        self.id = id
        self.fileURL = asset.fileURL
        self.mimeType = asset.mimeType
        self.byteCount = asset.byteCount
        self.uploadState = uploadState
    }

    var isUploading: Bool {
        if case .uploading = uploadState { return true }
        return false
    }

    var uploadedImageID: String? {
        if case let .uploaded(imageID) = uploadState { return imageID }
        return nil
    }

    var landingContextItem: ShopAgentLandingContextItem? {
        guard let imageID = uploadedImageID, imageID.isEmpty == false else { return nil }
        return ShopAgentLandingContextItem(id: imageID, type: .image)
    }

    var messageContextItem: ShopAgentMessageContextItem? {
        guard let imageID = uploadedImageID, imageID.isEmpty == false else { return nil }
        return ShopAgentMessageContextItem(id: imageID, type: .image, imageID: imageID)
    }
}

extension Array where Element == ShopAgentImageAttachment {
    var hasPendingUpload: Bool {
        contains { $0.isUploading }
    }

    var uploadedLandingContextItems: [ShopAgentLandingContextItem] {
        compactMap(\.landingContextItem)
    }

    var uploadedMessageContextItems: [ShopAgentMessageContextItem] {
        compactMap(\.messageContextItem)
    }

    var hasUploadedImageContext: Bool {
        contains { $0.uploadedImageID?.isEmpty == false }
    }
}
