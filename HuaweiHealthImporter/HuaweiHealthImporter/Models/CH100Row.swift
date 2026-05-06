import Foundation

/// One measurement row parsed from the bodyfat_export.csv produced by the CH100 scale app.
struct CH100Row {
    let time: Date
    let weight: Double?       // kg
    let bmi: Double?
    let bodyFatPct: Double?   // 0–100 %
    let muscle: Double?       // kg (lean muscle)
    let waterPct: Double?     // 0–100 %
    let bone: Double?         // kg
    let bmr: Double?          // kcal/day (no HK target)
    let visceralFat: Double?
    let protein: Double?      // 0–100 %
    let bodyAge: Double?
}
