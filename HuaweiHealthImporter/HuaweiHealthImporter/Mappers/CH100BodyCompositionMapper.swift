import Foundation
import HealthKit

/// Maps a `CH100Row` (from the decrypted CH100 scale database CSV) to HK quantity samples.
///
/// Produces the same four HK types as `BodyCompositionMapper`: bodyMass, bodyMassIndex,
/// bodyFatPercentage, and leanBodyMass (derived). Bone, water %, visceral fat, protein,
/// body age, and BMR have no HealthKit quantity types and are silently dropped.
enum CH100BodyCompositionMapper {

    private static let source = "CH100 Scale"

    static func samples(from row: CH100Row) -> [HKQuantitySample] {
        let metadata: [String: Any] = [HKMetadataKeyExternalUUID: "ch100-\(Int(row.time.timeIntervalSince1970))"]
        var results: [HKQuantitySample] = []

        if let kg = row.weight, kg > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.bodyMass),
                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                start: row.time, end: row.time, metadata: metadata))
        }

        if let bmi = row.bmi, bmi > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.bodyMassIndex),
                quantity: HKQuantity(unit: .count(), doubleValue: bmi),
                start: row.time, end: row.time, metadata: metadata))
        }

        if let bfr = row.bodyFatPct, bfr >= 0 {
            // CH100 stores as %, HK wants fraction 0–1
            results.append(HKQuantitySample(
                type: HKQuantityType(.bodyFatPercentage),
                quantity: HKQuantity(unit: .percent(), doubleValue: bfr / 100.0),
                start: row.time, end: row.time, metadata: metadata))
        }

        if let kg = row.weight, kg > 0,
           let bfr = row.bodyFatPct, bfr >= 0 {
            let lean = kg * (1.0 - bfr / 100.0)
            if lean > 0 {
                results.append(HKQuantitySample(
                    type: HKQuantityType(.leanBodyMass),
                    quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: lean),
                    start: row.time, end: row.time, metadata: metadata))
            }
        }

        return results
    }
}
