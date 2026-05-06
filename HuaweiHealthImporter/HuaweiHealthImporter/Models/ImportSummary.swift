import Foundation

/// Per-type counters collected at the end of an import run.
struct ImportSummary {
    struct TypeStats {
        let typeName: String
        var written: Int = 0
        var skippedDuplicate: Int = 0
        var failed: Int = 0
        var parsed: Int = 0
    }

    var statsByType: [String: TypeStats] = [:]
    var totalFilesProcessed: Int = 0
    var totalFilesSkipped: Int = 0
    var elapsedSeconds: TimeInterval = 0
    var errors: [String] = []

    /// Human-readable type display names keyed by HKSampleType.identifier.
    static let displayName: [String: String] = [
        "HKQuantityTypeIdentifierHeartRate":              "Heart Rate",
        "HKQuantityTypeIdentifierOxygenSaturation":       "Blood Oxygen",
        "HKQuantityTypeIdentifierBodyMass":               "Weight",
        "HKQuantityTypeIdentifierBodyFatPercentage":      "Body Fat %",
        "HKQuantityTypeIdentifierBodyMassIndex":          "BMI",
        "HKQuantityTypeIdentifierLeanBodyMass":           "Lean Body Mass",
        "HKQuantityTypeIdentifierHeight":                 "Height",
        "HKQuantityTypeIdentifierStepCount":              "Steps",
        "HKQuantityTypeIdentifierDistanceWalkingRunning": "Distance",
        "HKQuantityTypeIdentifierActiveEnergyBurned":     "Active Energy",
        "HKCategoryTypeIdentifierSleepAnalysis":          "Sleep",
    ]

    mutating func record(typeId: String, parsed: Int = 0, written: Int = 0, skipped: Int = 0, failed: Int = 0) {
        var s = statsByType[typeId] ?? TypeStats(typeName: ImportSummary.displayName[typeId] ?? typeId)
        s.parsed += parsed
        s.written += written
        s.skippedDuplicate += skipped
        s.failed += failed
        statsByType[typeId] = s
    }
}
