import Foundation

/// Decoded from the embedded JSON string in `HuaweiSamplePoint.value` when
/// `key == "WEIGHT_BODYFAT_BROAD"`.
struct HuaweiBodyComposition: Decodable {
    let bodyWeight: Double?         // kg
    let bodyFatRate: Double?        // % (divide by 100 for HK)
    let bmi: Double?                // kg/m²
    let muscleMass: Double?         // kg
    let skeletalMusclelMass: Double? // kg (Huawei's own typo preserved)
    let boneSalt: Double?           // kg
    let moistureRate: Double?       // %
    let proteinRate: Double?        // %
    let basalMetabolism: Double?    // kcal/day — no HK target, ignored
    let visceralFatLevel: Double?
    let bodyAge: Int?
    let bodyScore: Double?
    let height: Double?             // cm
    let age: Int?
    let gender: Int?
}
