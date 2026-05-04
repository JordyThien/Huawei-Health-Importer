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

    /// Exports the current log as a plain-text string (for UIActivityViewController).
    func exportLog() -> String {
        progress.logTail.joined(separator: "\n")
    }
}

// MARK: - ImportPipeline convenience

private extension ImportPipeline {
    func setProgressHandler(_ handler: @Sendable @escaping (ImportProgress) -> Void) async {
        self.progressHandler = handler
    }
}
