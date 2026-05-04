import Foundation

/// Typed errors emitted by the import pipeline.
enum ImportError: Error, CustomStringConvertible {
    case fileReadFailed(url: URL, underlying: Error)
    case jsonDecodingFailed(url: URL, underlying: Error)
    case healthKitAuthDenied
    case healthKitSaveFailed(underlying: Error)
    case invalidSamplePoint(key: String, reason: String)

    var description: String {
        switch self {
        case .fileReadFailed(let url, let err):
            return "Could not read \(url.lastPathComponent): \(err.localizedDescription)"
        case .jsonDecodingFailed(let url, let err):
            return "JSON decode failed for \(url.lastPathComponent): \(err.localizedDescription)"
        case .healthKitAuthDenied:
            return "HealthKit authorization was denied. Enable access in Settings → Privacy → Health."
        case .healthKitSaveFailed(let err):
            return "HealthKit write error: \(err.localizedDescription)"
        case .invalidSamplePoint(let key, let reason):
            return "Invalid sample for key '\(key)': \(reason)"
        }
    }
}
