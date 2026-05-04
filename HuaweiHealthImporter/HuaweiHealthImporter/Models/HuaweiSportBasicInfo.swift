import Foundation

/// Per-minute step/distance/calorie breakdown inside a `HuaweiSportEntry`.
///
/// **Calorie calibration note (open question §10.1):**
/// The raw `calorie` field appears to be in tenths of a kcal on this firmware
/// (e.g. `269` = 26.9 kcal for one minute of walking). Divide by 10 before writing
/// to HealthKit. A UI toggle in v1 lets the user override the divisor.
struct HuaweiSportBasicInfo: Decodable {
    let steps: Int
    let distance: Int      // meters
    let calorie: Int       // raw Huawei units — divide by 10 for kcal (see above)
    let altitude: Double
    let floor: Int
    let duration: Int      // minutes (always 1 in observed data)
    let count: Int
}
