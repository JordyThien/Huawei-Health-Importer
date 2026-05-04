import Foundation

/// Handles JSON decoding of Huawei Health export files.
///
/// Default path: `Data(contentsOf:options:.mappedIfSafe)` + `JSONDecoder`.
/// For files >50 MB (rare), a streaming fallback is available via `recordStream(for:)`.
enum ParserService {

    private static let largeSizeThreshold: Int = 50 * 1024 * 1024 // 50 MB

    // MARK: - Health detail data

    /// Decodes a health-detail JSON file into an array of `HuaweiRecord`s.
    /// Uses memory-mapped I/O so only parsed objects land on the heap.
    static func decodeHealthRecords(at url: URL) throws -> [HuaweiRecord] {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return try JSONDecoder().decode([HuaweiRecord].self, from: data)
        } catch let decodeError as DecodingError {
            throw ImportError.jsonDecodingFailed(url: url, underlying: decodeError)
        } catch {
            throw ImportError.fileReadFailed(url: url, underlying: error)
        }
    }

    // MARK: - Sport per minute data

    /// Decodes a sport-per-minute JSON file into an array of `HuaweiSportRecord`s.
    static func decodeSportRecords(at url: URL) throws -> [HuaweiSportRecord] {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return try JSONDecoder().decode([HuaweiSportRecord].self, from: data)
        } catch let decodeError as DecodingError {
            throw ImportError.jsonDecodingFailed(url: url, underlying: decodeError)
        } catch {
            throw ImportError.fileReadFailed(url: url, underlying: error)
        }
    }

    // MARK: - Streaming fallback (§5.2 seam — dormant in v1)

    /// Returns an `AsyncThrowingStream` that yields one `HuaweiRecord` at a time.
    /// Only activated when the file size exceeds `largeSizeThreshold`.
    /// This path is **not used by default** — it ships as a dormant seam for v2.
    static func recordStream(for url: URL) -> AsyncThrowingStream<HuaweiRecord, Error> {
        AsyncThrowingStream { continuation in
            Task.detached(priority: .utility) {
                do {
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }

                    var depth = 0
                    var inString = false
                    var escape = false
                    var buffer = Data()
                    var sawArrayStart = false
                    let decoder = JSONDecoder()

                    var keepGoing = true
                    while keepGoing {
                        let chunk = handle.readData(ofLength: 64 * 1024)
                        guard !chunk.isEmpty else { break }
                        for byte in chunk {
                            if !sawArrayStart {
                                if byte == 0x5B { sawArrayStart = true }
                                continue
                            }
                            if escape { escape = false; buffer.append(byte); continue }
                            if inString {
                                if byte == 0x5C { escape = true }
                                else if byte == 0x22 { inString = false }
                                buffer.append(byte); continue
                            }
                            switch byte {
                            case 0x22: inString = true; buffer.append(byte)
                            case 0x7B:
                                depth += 1; buffer.append(byte)
                            case 0x7D:
                                depth -= 1; buffer.append(byte)
                                if depth == 0 {
                                    let record = try decoder.decode(HuaweiRecord.self, from: buffer)
                                    continuation.yield(record)
                                    buffer.removeAll(keepingCapacity: true)
                                }
                            case 0x2C where depth == 0: break
                            case 0x5D where depth == 0: keepGoing = false
                            default: if depth > 0 { buffer.append(byte) }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
