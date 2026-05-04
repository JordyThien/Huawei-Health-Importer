import Foundation

/// Live progress snapshot published by `ImportViewModel` during an active import.
struct ImportProgress {
    var currentFileName: String = ""
    var filesCompleted: Int = 0
    var filesTotal: Int = 0

    var parsed: Int = 0
    var written: Int = 0
    var skippedDuplicate: Int = 0
    var failed: Int = 0

    /// Recent log lines (capped at 200 entries).
    var logTail: [String] = []

    static let empty = ImportProgress()

    var fileProgress: Double {
        guard filesTotal > 0 else { return 0 }
        return Double(filesCompleted) / Double(filesTotal)
    }

    mutating func appendLog(_ line: String) {
        logTail.append(line)
        if logTail.count > 200 { logTail.removeFirst(logTail.count - 200) }
    }
}
