import Foundation

/// Top-level record from the "Health detail data" JSON arrays.
struct HuaweiRecord: Decodable {
    let type: Int
    let startTime: Int64           // Unix ms
    let endTime: Int64             // Unix ms
    let timeZone: String?          // e.g. "+0200"
    let deviceCode: Int64?
    let recordId: String?
    let samplePoints: [HuaweiSamplePoint]
}
