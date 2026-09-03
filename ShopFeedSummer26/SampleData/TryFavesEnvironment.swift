import SwiftUI

/// The location a look is photographed in.
///
/// The environment is baked into each generation's prompt — every look is one
/// flat photograph of the person in this location. Changing it affects new
/// looks only; existing photographs keep the location they were shot in.
enum TryFavesEnvironment: String, CaseIterable, Codable, Identifiable, Sendable {
    /// The environment the bundled seed avatar is photographed in.
    case warmInterior
    case photoStudio
    case mountaintop

    var id: String { rawValue }

    /// The environment the seed photograph — and the Home feed card — shows.
    static let seed: TryFavesEnvironment = .warmInterior

    var title: String {
        switch self {
        case .warmInterior: "Warm interior"
        case .photoStudio: "Photo studio"
        case .mountaintop: "Mountain pass"
        }
    }

    /// The environment's seed photograph: the picker thumbnail, and the
    /// location reference handed to the generator alongside the prompt so
    /// every frame of the shoot is recognisably the same place. `nil` falls
    /// back to the tint swatch and a prompt-only location.
    var plateAssetName: String? {
        switch self {
        case .warmInterior: "try-faves-stage-warm-interior"
        case .photoStudio: "try-faves-stage-photo-studio"
        case .mountaintop: "try-faves-stage-mountain-pass"
        }
    }

    /// Environments are prompt-driven, so none needs plate photography.
    var isAvailable: Bool { true }

    /// Wall tone of the environment — used by the picker thumbnails.
    var skyTint: Color {
        switch self {
        case .warmInterior: Color(hex: "#A89379")
        case .photoStudio: Color(hex: "#E9E4E3")
        case .mountaintop: Color(hex: "#C9D3DA")
        }
    }

    /// Floor tone of the environment — used by the picker thumbnails.
    var groundTint: Color {
        switch self {
        case .warmInterior: Color(hex: "#A08D74")
        case .photoStudio: Color(hex: "#B2AAA3")
        case .mountaintop: Color(hex: "#9AA6AE")
        }
    }

    /// How the location is described to the generator — the source of truth
    /// for what a look's photograph shows behind the person.
    var promptDescription: String {
        switch self {
        case .warmInterior:
            "a warm plaster interior with a polished stone floor, soft natural light"
        case .photoStudio:
            "a plain off-white photo studio cyclorama with a concrete floor, soft even light"
        case .mountaintop:
            "a sunlit alpine mountain pass — a wildflower meadow with scattered "
                + "rocks, forested ridgelines and snow-capped peaks behind, under "
                + "a bright blue sky"
        }
    }
}
