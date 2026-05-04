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

    /// Human-readable type display names.
    static let displayName: [String: String] = [
        "heartRate":              "Heart Rate",
        "oxygenSaturation":       "Blood Oxygen",
        "bodyMass":               "Weight",
        "bodyFatPercentage":      "Body Fat %",
        "bodyMassIndex":          "BMI",
        "leanBodyMass":           "Lean Body Mass",
        "height":                 "Height",
        "stepCount":              "Steps",
        "distanceWalkingRunning": "Distance",
        "activeEnergyBurned":     "Active Energy",
        "sleepAnalysis":          "Sleep",
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
