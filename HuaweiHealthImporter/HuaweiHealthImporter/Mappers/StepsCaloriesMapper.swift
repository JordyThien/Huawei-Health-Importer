import Foundation
import HealthKit

/// Maps `HuaweiSportEntry` (from sport-per-minute data) to step count, distance,
/// and active energy `HKQuantitySample` objects.
///
/// One `HuaweiSportEntry` typically contains one `HuaweiSportBasicInfo` covering
/// a one-minute window. We emit one sample per entry for each of the three types.
///
/// **Calorie calibration (§10.1 open question):**
/// Raw `calorie` values like 269 for 1 minute of walking are implausibly high as kcal.
/// Default divisor is 10 (so 269 → 26.9 kcal). Users can adjust via `calorieDivisor`.
enum StepsCaloriesMapper {

    /// Divisor applied to Huawei's raw `calorie` int to produce kcal.
    /// Default: 10 (firmware stores tenths of a kcal).
    static var calorieDivisor: Double = 10.0

    static func samples(from entry: HuaweiSportEntry) -> [HKQuantitySample] {
        guard let info = entry.sportBasicInfos.first else { return [] }

        let start = TimeZoneParser.date(fromUnixMs: entry.startTime)
        let end   = TimeZoneParser.date(fromUnixMs: entry.endTime)
        let safeEnd = end >= start ? end : start

        var results: [HKQuantitySample] = []

        // Step count
        if info.steps > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.stepCount),
                quantity: HKQuantity(unit: .count(), doubleValue: Double(info.steps)),
                start: start,
                end: safeEnd))
        }

        // Distance (meters → HK wants meters for distanceWalkingRunning)
        if info.distance > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.distanceWalkingRunning),
                quantity: HKQuantity(unit: .meter(), doubleValue: Double(info.distance)),
                start: start,
                end: safeEnd))
        }

        // Active energy burned (apply calibration divisor)
        let kcal = Double(info.calorie) / calorieDivisor
        if kcal > 0 {
            results.append(HKQuantitySample(
                type: HKQuantityType(.activeEnergyBurned),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: start,
                end: safeEnd))
        }

        return results
    }
}
