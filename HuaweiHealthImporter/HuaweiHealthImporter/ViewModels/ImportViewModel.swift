import Foundation
import HealthKit
import SwiftUI

/// Phases the import UI transitions through.
enum ImportPhase {
    case welcome
    case permissionGate
    case importing
    case summary
}

/// Main state machine driving the UI. All mutations happen on the main actor.
@MainActor
final class ImportViewModel: ObservableObject {

    // MARK: - Published state

    @Published var phase: ImportPhase = .welcome
    @Published var pickedFolder: URL?
    @Published var progress: ImportProgress = .empty
    @Published var summary: ImportSummary?
    @Published var lastError: ImportError?
    @Published var calorieDivisor: Double = 10.0

    // MARK: - Private

    private let authService: HKAuthService
    private let store: HKHealthStore
    private var importTask: Task<Void, Never>?

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
        self.authService = HKAuthService(store: store)
    }

    // MARK: - User actions

    /// Called when the user picks a folder from the document picker.
    func pickFolder(_ url: URL) {
        pickedFolder = url
        // If we haven't authorized yet, show the permission gate
        if phase == .welcome {
            phase = .permissionGate
        }
    }

    /// Requests HealthKit authorization, then advances to .welcome (ready to start).
    func requestAuthorization() async {
        do {
            try await authService.requestAuthorization()
            phase = .welcome
        } catch {
            lastError = error as? ImportError ?? .healthKitAuthDenied
        }
    }

    /// Kicks off the import pipeline on a background Task.
    func startImport() {
        guard let folder = pickedFolder else { return }
        phase = .importing
        progress = .empty
        summary = nil

        importTask = Task {
            let pipeline = ImportPipeline(store: store)
            await pipeline.setProgressHandler { [weak self] prog in
                Task { @MainActor [weak self] in
                    self?.progress = prog
                }
            }

            let result = await pipeline.run(folder: folder, calorieDivisor: calorieDivisor)
            await MainActor.run { [weak self] in
                self?.summary = result
                self?.phase = .summary
            }
        }
    }

    /// Cancels a running import.
    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        phase = .welcome
    }

    /// Resets state for another import run.
    func reset() {
        importTask?.cancel()
        importTask = nil
        pickedFolder = nil
        progress = .empty
        summary = nil
        lastError = nil
        phase = .welcome
    }

    /// Exports the import summary as a plain-text string (for UIActivityViewController).
    func exportLog() -> String {
        var lines: [String] = []

        lines.append("Huawei Health Import Report")
        lines.append("Date: \(Date().formatted(date: .long, time: .shortened))")

        if let s = summary {
            lines.append(String(format: "Duration: %.1f seconds", s.elapsedSeconds))
            lines.append("Files processed: \(s.totalFilesProcessed)")
            lines.append("")
            lines.append("Results by type:")

            let sorted = s.statsByType.values.sorted { $0.typeName < $1.typeName }
            for stats in sorted {
                lines.append("  \(stats.typeName): \(stats.written) written, \(stats.skippedDuplicate) skipped, \(stats.failed) failed")
            }

            lines.append("")
            lines.append("Totals: \(progress.written) written, \(progress.skippedDuplicate) skipped, \(progress.failed) failed")

            if !s.errors.isEmpty {
                lines.append("")
                lines.append("Errors:")
                s.errors.forEach { lines.append("  \($0)") }
            }
        } else if !progress.logTail.isEmpty {
            lines.append(contentsOf: progress.logTail)
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - ImportPipeline convenience

private extension ImportPipeline {
    func setProgressHandler(_ handler: @Sendable @escaping (ImportProgress) -> Void) async {
        self.progressHandler = handler
    }
}
