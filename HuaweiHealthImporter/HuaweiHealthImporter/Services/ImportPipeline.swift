import Foundation
import HealthKit

/// Orchestrates the full import: parse → map → dedup → write → progress updates.
///
/// Designed to run entirely on a background `Task`. All UI updates go through the
/// `progressHandler` which dispatches to `@MainActor` via `ImportViewModel`.
actor ImportPipeline {

    private let parser   = ParserService.self
    private let enumerator = FolderEnumerator.self
    private let writer: HKWriteService
    private let store:  HKHealthStore

    /// Handler called on every meaningful progress event. Runs on background; callers
    /// must dispatch to MainActor themselves.
    var progressHandler: (@Sendable (ImportProgress) -> Void)?

    init(store: HKHealthStore = HKHealthStore()) {
        self.store  = store
        self.writer = HKWriteService(store: store)
    }

    // MARK: - Public

    /// Runs the full import from `folder`, with an optional CH100 scale CSV. Returns a completed `ImportSummary`.
    func run(folder: URL,
             csvURL: URL? = nil,
             calorieDivisor: Double = 10.0) async -> ImportSummary {
        StepsCaloriesMapper.calorieDivisor = calorieDivisor

        let files = enumerator.enumerate(folder: folder)
        var progress = ImportProgress()
        progress.filesTotal = files.filter { $0.kind != .unknown }.count + (csvURL != nil ? 1 : 0)
        emit(progress)

        var summary = ImportSummary()
        let startTime = Date()

        for file in files {
            guard !Task.isCancelled else { break }

            switch file.kind {
            case .healthDetail:
                await processHealthDetail(file: file.url, progress: &progress, summary: &summary)
            case .sportPerMinute:
                await processSportPerMinute(file: file.url, progress: &progress, summary: &summary)
            case .motionPath:
                // Seam for v2 (GPS/workout routes) — skip for now
                progress.appendLog("Skipped (workout routes, v2): \(file.url.lastPathComponent)")
            case .unknown:
                continue
            }

            progress.filesCompleted += 1
            emit(progress)
        }

        if let csvURL {
            await processCSV(url: csvURL, progress: &progress, summary: &summary)
            progress.filesCompleted += 1
            emit(progress)
        }

        summary.totalFilesProcessed = progress.filesCompleted
        summary.elapsedSeconds = Date().timeIntervalSince(startTime)
        summary.errors = Array(progress.logTail.filter { $0.hasPrefix("Error") })
        return summary
    }

    // MARK: - CH100 scale CSV

    private func processCSV(url: URL,
                            progress: inout ImportProgress,
                            summary: inout ImportSummary) async {
        progress.currentFileName = url.lastPathComponent
        emit(progress)

        let rows: [CH100Row]
        do {
            rows = try CH100CSVParser.parse(url: url)
        } catch {
            progress.appendLog("Error parsing \(url.lastPathComponent): \(error)")
            emit(progress)
            return
        }

        var samplesByType: [String: [HKSample]] = [:]
        for row in rows {
            let samples = CH100BodyCompositionMapper.samples(from: row)
            for s in samples {
                samplesByType[s.sampleType.identifier, default: []].append(s)
            }
            progress.parsed += samples.count
        }

        for (typeId, samples) in samplesByType {
            guard !Task.isCancelled else { return }
            do {
                let (written, skipped) = try await writer.deduplicateAndSave(
                    samples: samples,
                    progressHandler: { _, _ in }
                )
                progress.written += written
                progress.skippedDuplicate += skipped
                summary.record(typeId: typeId, parsed: samples.count, written: written, skipped: skipped)
            } catch {
                progress.failed += samples.count
                progress.appendLog("Error writing scale \(typeId): \(error)")
                summary.record(typeId: typeId, failed: samples.count)
            }
            emit(progress)
        }
    }

    // MARK: - Health detail files

    private func processHealthDetail(file: URL,
                                     progress: inout ImportProgress,
                                     summary: inout ImportSummary) async {
        progress.currentFileName = file.lastPathComponent
        emit(progress)

        let records: [HuaweiRecord]
        do {
            records = try ParserService.decodeHealthRecords(at: file)
        } catch {
            progress.appendLog("Error decoding \(file.lastPathComponent): \(error)")
            emit(progress)
            return
        }

        // Accumulate samples by HK type
        var samplesByType: [String: [HKSample]] = [:]

        for record in records {
            for point in record.samplePoints {
                let target = HKMapping.target(forKey: point.key)
                switch target {
                case .quantity(let typeId, _):
                    let sample: HKSample?
                    switch point.key {
                    case "DATA_POINT_DYNAMIC_HEARTRATE",
                         "DATA_POINT_REST_HEARTRATE",
                         "DYNAMIC_HEART_RATE",
                         "RESTING_HEART_RATE":
                        sample = HeartRateMapper.sample(from: point, recordId: record.recordId, deviceCode: record.deviceCode)
                    case "BLOOD_OXYGEN_SATURATION":
                        sample = BloodOxygenMapper.sample(from: point, recordId: record.recordId, deviceCode: record.deviceCode)
                    default:
                        sample = nil
                    }
                    if let s = sample {
                        samplesByType[typeId.rawValue, default: []].append(s)
                        progress.parsed += 1
                    }

                case .category(let typeId, _):
                    if let s = SleepMapper.sample(from: point, recordId: record.recordId, deviceCode: record.deviceCode) {
                        samplesByType[typeId.rawValue, default: []].append(s)
                        progress.parsed += 1
                    }

                case .bodyComposition:
                    let samples = BodyCompositionMapper.samples(from: point, recordId: record.recordId, deviceCode: record.deviceCode)
                    for s in samples {
                        samplesByType[s.sampleType.identifier, default: []].append(s)
                    }
                    progress.parsed += samples.count

                case .skip:
                    break
                }

                if progress.parsed % 100 == 0 { emit(progress) }
            }
        }

        // Write each type's accumulated samples
        for (typeId, samples) in samplesByType {
            guard !Task.isCancelled else { return }
            do {
                let (written, skipped) = try await writer.deduplicateAndSave(
                    samples: samples,
                    progressHandler: { w, s in }
                )
                progress.written += written
                progress.skippedDuplicate += skipped
                summary.record(typeId: typeId, parsed: samples.count, written: written, skipped: skipped)
            } catch {
                progress.failed += samples.count
                progress.appendLog("Error writing \(typeId): \(error)")
                summary.record(typeId: typeId, failed: samples.count)
            }
            emit(progress)
        }
    }

    // MARK: - Sport per minute files

    private func processSportPerMinute(file: URL,
                                       progress: inout ImportProgress,
                                       summary: inout ImportSummary) async {
        progress.currentFileName = file.lastPathComponent
        emit(progress)

        let sportRecords: [HuaweiSportRecord]
        do {
            sportRecords = try ParserService.decodeSportRecords(at: file)
        } catch {
            progress.appendLog("Error decoding \(file.lastPathComponent): \(error)")
            emit(progress)
            return
        }

        var allSamples: [HKSample] = []
        for sportRecord in sportRecords {
            for entry in sportRecord.sportDataUserData {
                let samples = StepsCaloriesMapper.samples(from: entry)
                allSamples.append(contentsOf: samples)
                progress.parsed += samples.count
            }
        }

        guard !allSamples.isEmpty else { return }

        // Group by type and write
        var byType: [String: [HKSample]] = [:]
        for s in allSamples { byType[s.sampleType.identifier, default: []].append(s) }

        for (typeId, samples) in byType {
            guard !Task.isCancelled else { return }
            do {
                let (written, skipped) = try await writer.deduplicateAndSave(
                    samples: samples,
                    progressHandler: { w, s in }
                )
                progress.written += written
                progress.skippedDuplicate += skipped
                summary.record(typeId: typeId, parsed: samples.count, written: written, skipped: skipped)
            } catch {
                progress.failed += samples.count
                progress.appendLog("Error writing sport \(typeId): \(error)")
                summary.record(typeId: typeId, failed: samples.count)
            }
            emit(progress)
        }
    }

    // MARK: - Private helpers

    private func emit(_ progress: ImportProgress) {
        progressHandler?(progress)
    }
}
