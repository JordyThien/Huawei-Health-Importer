import Foundation

/// A single data point inside a `HuaweiRecord`.
/// The `key` string is the canonical discriminator — always prefer it over the parent record's `type` int.
struct HuaweiSamplePoint: Decodable {
    let key: String
    let startTime: Int64       // Unix ms
    let endTime: Int64         // Unix ms
    let unit: String?          // Huawei's "0" = default unit; ignored
    let value: String?         // String — may be a plain number "82.0" OR embedded JSON
}
