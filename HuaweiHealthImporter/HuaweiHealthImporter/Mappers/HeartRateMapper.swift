import Foundation
import HealthKit

/// Maps `DATA_POINT_DYNAMIC_HEARTRATE` / `DATA_POINT_REST_HEARTRATE` sample points
/// to `HKQuantitySample` heart rate samples.
enum HeartRateMapper {

    static let unit = HKUnit.count().unitDivided(by: .minute())
    static let type = HKQuantityType(.heartRate)

    /// Returns a heart-rate `HKQuantitySample` for the given sample point, or `nil`
    /// if the value cannot be parsed.
    static func sample(from point: HuaweiSamplePoint,
                       recordId: String?,
                       deviceCode: Int64?) -> HKQuantitySample? {
        guard let rawValue = point.value,
              let bpm = Double(rawValue),
              bpm > 0, bpm < 300 else {
            return nil
        }

        let start = TimeZoneParser.date(fromUnixMs: point.startTime)
        let end   = TimeZoneParser.date(fromUnixMs: point.endTime)
        // Protect against malformed data where end < start
        let safeEnd = end >= start ? end : start

        var metadata: [String: Any] = [:]
        if let rid = recordId { metadata[HKMetadataKeyExternalUUID] = rid }
        if let dc = deviceCode { metadata["HuaweiDeviceCode"] = dc }

        let quantity = HKQuantity(unit: unit, doubleValue: bpm)
        return HKQuantitySample(type: type,
                                quantity: quantity,
                                start: start,
                                end: safeEnd,
                                metadata: metadata.isEmpty ? nil : metadata)
    }
}
