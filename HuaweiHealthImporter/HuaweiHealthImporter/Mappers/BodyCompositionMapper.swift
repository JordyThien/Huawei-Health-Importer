import Foundation
import HealthKit

/// Maps a `WEIGHT_BODYFAT_BROAD` sample point (which carries an embedded JSON value)
/// to up to 5 `HKQuantitySample` objects: bodyMass, bodyFatPercentage, bodyMassIndex,
/// leanBodyMass, and (optionally) height.
enum BodyCompositionMapper {

    private static let decoder = JSONDecoder()

    /// Decodes the embedded JSON `value` string and returns all mappable HK samples.
    /// Returns an empty array if the value cannot be decoded.
    static func samples(from point: HuaweiSamplePoint,
                        recordId: String?,
                        deviceCode: Int64?) -> [HKQuantitySample] {
        guard let rawValue = point.value,
              !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let comp = try? decoder.decode(HuaweiBodyComposition.self, from: data) else {
            return []
        }

        let start = TimeZoneParser.date(fromUnixMs: point.startTime)
        let end   = TimeZoneParser.date(fromUnixMs: point.endTime)
        let safeEnd = end >= start ? end : start

        var meta: [String: Any] = [:]
        if let rid = recordId { meta[HKMetadataKeyExternalUUID] = rid }
        if let dc = deviceCode { meta["HuaweiDeviceCode"] = dc }
        let metadata: [String: Any]? = meta.isEmpty ? nil : meta

        var results: [HKQuantitySample] = []

        if let kg = comp.bodyWeight, kg > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.bodyMass),
                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                start: start, end: safeEnd, metadata: metadata))
        }

        if let bfr = comp.bodyFatRate, bfr >= 0 {
            // Huawei stores as %, HK wants fraction 0–1
            results.append(HKQuantitySample(
                type: HKQuantityType(.bodyFatPercentage),
                quantity: HKQuantity(unit: .percent(), doubleValue: bfr / 100.0),
                start: start, end: safeEnd, metadata: metadata))
        }

        if let bmi = comp.bmi, bmi > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.bodyMassIndex),
                quantity: HKQuantity(unit: .count(), doubleValue: bmi),
                start: start, end: safeEnd, metadata: metadata))
        }

        // Derived lean body mass: weight * (1 - bodyFatRate/100)
        if let kg = comp.bodyWeight, kg > 0,
           let bfr = comp.bodyFatRate, bfr >= 0 {
            let lean = kg * (1.0 - bfr / 100.0)
            if lean > 0 {
                results.append(HKQuantitySample(
                    type: HKQuantityType(.leanBodyMass),
                    quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: lean),
                    start: start, end: safeEnd, metadata: metadata))
            }
        }

        // Height (cm → HK wants meters)
        if let cm = comp.height, cm > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.height),
                quantity: HKQuantity(unit: .meterUnit(with: .centi), doubleValue: cm),
                start: start, end: safeEnd, metadata: metadata))
        }

        return results
    }
}
