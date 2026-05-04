import Foundation
import HealthKit

/// Handles deduplication and batched HealthKit writes.
///
/// Dedup strategy (§6):
/// 1. For each HK type, run ONE `HKSampleQuery` over the full date range of to-write samples.
/// 2. Build an in-memory `Set<UInt64>` of hashed `(typeId|startMs|endMs)` keys.
/// 3. Filter candidates locally against that set.
/// 4. Write in batches of up to 500 samples.
actor HKWriteService {

    private let store: HKHealthStore
    private static let batchSize = 500

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    // MARK: - Public API

    /// Deduplicates `samples` against existing HealthKit data, then writes the remaining
    /// in batches of 500. Returns `(written, skipped)` counts.
    func deduplicateAndSave(
        samples: [HKSample],
        progressHandler: @Sendable @escaping (Int, Int) async -> Void
    ) async throws -> (written: Int, skipped: Int) {
        guard !samples.isEmpty else { return (0, 0) }

        // Group by HK type so we do one query per type
        var byType: [String: [HKSample]] = [:]
        for s in samples {
            let key = s.sampleType.identifier
            byType[key, default: []].append(s)
        }

        var toWrite: [HKSample] = []
        var totalSkipped = 0

        for (_, typeSamples) in byType {
            let (filtered, skipped) = try await deduplicated(typeSamples)
            toWrite.append(contentsOf: filtered)
            totalSkipped += skipped
        }

        // Write in batches
        var totalWritten = 0
        for batch in toWrite.chunked(into: Self.batchSize) {
            do {
                try await store.save(batch)
                totalWritten += batch.count
                await progressHandler(totalWritten, totalSkipped)
            } catch {
                throw ImportError.healthKitSaveFailed(underlying: error)
            }
        }

        return (totalWritten, totalSkipped)
    }

    // MARK: - Private

    private func deduplicated(_ samples: [HKSample]) async throws -> (keep: [HKSample], skippedCount: Int) {
        guard let first = samples.first else { return ([], 0) }
        let sampleType = first.sampleType

        // Compute date range for this type's candidates
        let minStart = samples.map(\.startDate).min()!
        let maxEnd   = samples.map(\.endDate).max()!

        // Fetch all existing samples of this type over the range (one IPC round-trip)
        let existingKeys = try await fetchExistingKeys(type: sampleType, from: minStart, to: maxEnd)

        var kept: [HKSample] = []
        var skipped = 0

        for s in samples {
            let key = dedupKey(type: sampleType.identifier, start: s.startDate, end: s.endDate)
            if existingKeys.contains(key) {
                skipped += 1
            } else {
                kept.append(s)
            }
        }

        return (kept, skipped)
    }

    private func fetchExistingKeys(type: HKSampleType, from start: Date, to end: Date) async throws -> Set<UInt64> {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(sampleType: type,
                                      predicate: predicate,
                                      limit: HKObjectQueryNoLimit,
                                      sortDescriptors: nil) { _, results, error in
                if let error = error {
                    continuation.resume(throwing: ImportError.healthKitSaveFailed(underlying: error))
                    return
                }
                var keys = Set<UInt64>()
                for s in (results ?? []) {
                    keys.insert(self.dedupKey(type: type.identifier, start: s.startDate, end: s.endDate))
                }
                continuation.resume(returning: keys)
            }
            self.store.execute(query)
        }
    }

    nonisolated private func dedupKey(type: String, start: Date, end: Date) -> UInt64 {
        // FNV-1a–style hash of "typeId|startMs|endMs"
        let startMs = Int64(start.timeIntervalSince1970 * 1000)
        let endMs   = Int64(end.timeIntervalSince1970 * 1000)
        var hash: UInt64 = 14_695_981_039_346_656_037
        func mix(_ v: UInt64) { hash ^= v; hash = hash &* 1_099_511_628_211 }
        for byte in type.utf8 { mix(UInt64(byte)) }
        mix(UInt64(bitPattern: startMs))
        mix(UInt64(bitPattern: endMs))
        return hash
    }
}

// MARK: - Array chunking helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
