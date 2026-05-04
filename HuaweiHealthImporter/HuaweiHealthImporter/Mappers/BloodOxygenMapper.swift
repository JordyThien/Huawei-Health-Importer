import Foundation
import HealthKit

/// Maps `BLOOD_OXYGEN_SATURATION` sample points to `HKQuantitySample` SpO₂ samples.
///
/// **Note:** Huawei's `value` for SpO₂ is an embedded JSON object: `{"avgSaturation":98.0}`
/// rather than a plain number. We decode it here.
enum BloodOxygenMapper {

    static let unit = HKUnit.percent()
    static let type = HKQuantityType(.oxygenSaturation)

    /// Intermediate struct for decoding the SpO₂ embedded JSON.
    private struct SpO2Value: Decodable {
        let avgSaturation: Double
    }

    private static let decoder = JSONDecoder()

    static func sample(from point: HuaweiSamplePoint,
                       recordId: String?,
                       deviceCode: Int64?) -> HKQuantitySample? {
        guard let rawValue = point.value, !rawValue.isEmpty else { return nil }

        // Try embedded JSON first: {"avgSaturation":98.0}
        let saturationPct: Double
        if rawValue.hasPrefix("{"),
           let data = rawValue.data(using: .utf8),
           let obj = try? decoder.decode(SpO2Value.self, from: data) {
            saturationPct = obj.avgSaturation
        } else if let plain = Double(rawValue) {
            // Fallback: plain numeric string
            saturationPct = plain
        } else {
            return nil
        }

        // HK expects fraction 0–1 for oxygenSaturation
        let fraction = saturationPct > 1.0 ? saturationPct / 100.0 : saturationPct
        guard fraction > 0, fraction <= 1.0 else { return nil }

        let start = TimeZoneParser.date(fromUnixMs: point.startTime)
        let end   = TimeZoneParser.date(fromUnixMs: point.endTime)
        let safeEnd = end >= start ? end : start

        var meta: [String: Any] = [:]
        if let rid = recordId { meta[HKMetadataKeyExternalUUID] = rid }
        if let dc = deviceCode { meta["HuaweiDeviceCode"] = dc }

        return HKQuantitySample(type: type,
                                quantity: HKQuantity(unit: unit, doubleValue: fraction),
                                start: start,
                                end: safeEnd,
                                metadata: meta.isEmpty ? nil : meta)
    }
}
