import Foundation
import HealthKit

/// Canonical mapping from Huawei `key` strings to HealthKit targets.
/// Always map by `key`; use `type` int only as a coarse pre-filter.
enum HKMapping {

    enum Target {
        case quantity(HKQuantityTypeIdentifier, HKUnit)
        case category(HKCategoryTypeIdentifier, value: Int)
        /// Expands into up to 5 `HKQuantitySample`s in `BodyCompositionMapper`.
        case bodyComposition
        case skip(reason: String)
    }

    static func target(forKey key: String) -> Target {
        switch key {
        case "DATA_POINT_DYNAMIC_HEARTRATE",
             "DATA_POINT_REST_HEARTRATE",
             "DYNAMIC_HEART_RATE",
             "RESTING_HEART_RATE":
            return .quantity(.heartRate, HKUnit.count().unitDivided(by: .minute()))

        case "BLOOD_OXYGEN_SATURATION":
            return .quantity(.oxygenSaturation, HKUnit.percent())

        case "WEIGHT_BODYFAT_BROAD":
            return .bodyComposition

        case "PROFESSIONAL_SLEEP_SHALLOW":
            return .category(.sleepAnalysis, value: HKCategoryValueSleepAnalysis.asleepCore.rawValue)
        case "PROFESSIONAL_SLEEP_DEEP":
            return .category(.sleepAnalysis, value: HKCategoryValueSleepAnalysis.asleepDeep.rawValue)
        case "PROFESSIONAL_SLEEP_DREAM":
            return .category(.sleepAnalysis, value: HKCategoryValueSleepAnalysis.asleepREM.rawValue)
        case "PROFESSIONAL_SLEEP_NOON":
            return .category(.sleepAnalysis, value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue)
        case "PROFESSIONAL_SLEEP_WAKE":
            return .category(.sleepAnalysis, value: HKCategoryValueSleepAnalysis.awake.rawValue)

        case "STRESS_DATA", "STRESS":
            return .skip(reason: "No HealthKit equivalent for stress")
        case "EXERCISE_INTENSITY":
            return .skip(reason: "Aggregated activity intensity has no direct HK type")

        default:
            return .skip(reason: "Unmapped key: \(key)")
        }
    }

    // MARK: - HK types needed for auth

    /// All quantity types the app may write.
    static let writeQuantityTypes: [HKQuantityTypeIdentifier] = [
        .heartRate,
        .oxygenSaturation,
        .bodyMass,
        .bodyFatPercentage,
        .bodyMassIndex,
        .leanBodyMass,
        .height,
        .stepCount,
        .distanceWalkingRunning,
        .activeEnergyBurned,
    ]

    /// All category types the app may write.
    static let writeCategoryTypes: [HKCategoryTypeIdentifier] = [
        .sleepAnalysis,
    ]

    static var allWriteTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []
        for id in writeQuantityTypes { types.insert(HKQuantityType(id)) }
        for id in writeCategoryTypes { types.insert(HKCategoryType(id)) }
        return types
    }

    static var allReadTypes: Set<HKObjectType> {
        Set(allWriteTypes)
    }
}
