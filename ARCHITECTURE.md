# HuaweiHealthImporter — Architecture & Implementation Plan

**Target:** native iOS app, Swift / SwiftUI, iOS 16+, no third-party deps.
**Goal:** import a Huawei Health export folder into Apple HealthKit, fully offline.

This doc replaces the assumptions in `huawei-to-apple-health-prompt.md` where they conflict with the actual export. Corrections are flagged inline as **[CORRECTION]**.

---

## 0. Reality check (read first)

Profile of the real export at `HUAWEI_HEALTH_20260504043043/`:

| Folder                              | Size  | Format                          | Maps to HealthKit?                  |
| ----------------------------------- | ----- | ------------------------------- | ----------------------------------- |
| `Health detail data & description/` | 52 MB | 28× single-line JSON arrays     | Yes — primary source                |
| `Sport per minute merged data …/`   | 24 MB | JSON arrays, **different schema** (`sportBasicInfos[]`) | Yes — steps / distance / calories  |
| `Motion path detail data …/`        | 2.7 MB| JSON, but `attribute` is a custom GPS string | Yes — `HKWorkoutRoute`              |
| `Sample sequence data …/`           | 36 KB | XLSX descriptor only, no JSON   | No                                  |
| `SportsHealth …/`                   | 628 KB| XLS only                        | No (skip v1)                        |
| `User route / run plan …/`          | <40 KB| Plans, not measurements         | No                                  |

**[CORRECTION] Type-int mapping in the prompt is wrong.** Empirical mapping from this user's real data:

| `type` | `key` (canonical)                | Meaning                |
| -----: | -------------------------------- | ---------------------- |
| 7      | `DATA_POINT_DYNAMIC_HEARTRATE`   | heart rate sample      |
| 7      | `DATA_POINT_REST_HEARTRATE`      | resting heart rate     |
| 8      | `WEIGHT_BODYFAT_BROAD`           | weight + body comp     |
| 9      | `PROFESSIONAL_SLEEP_SHALLOW`     | sleep — core           |
| 9      | `PROFESSIONAL_SLEEP_DEEP`        | sleep — deep           |
| 9      | `PROFESSIONAL_SLEEP_DREAM`       | sleep — REM            |
| 9      | `PROFESSIONAL_SLEEP_WAKE`        | sleep — awake          |
| 9      | `PROFESSIONAL_SLEEP_NOON`        | nap                    |
| 11     | `STRESS_DATA`                    | (no HK type — skip)    |
| 12     | `EXERCISE_INTENSITY`             | (no HK type — skip)    |
| 16 / 400021 | `BLOOD_OXYGEN_SATURATION`   | SpO₂                   |
| 10006* | `WEIGHT_BODYFAT_BROAD`           | (older firmware)       |

*Reference: `huawei-health-to-health-connect/main.py` already uses `type:10006` for weight from a different firmware export. **`type` ints are firmware-dependent. Map by `key` string. Use `type` as a coarse pre-filter only.**

**[CORRECTION] "140k-line files" is misleading.** Files are *minified*, single-line JSON arrays. `du -h` shows max ~3 MB per file in this export. `JSONDecoder` on a memory-mapped `Data` handles each file fine. The prompt's `InputStream` streaming parser is over-engineered for the real data size. We keep an optional record-splitter upgrade path for the rare case of a single >50 MB file.

**[CORRECTION] HealthKit details:**

- `basalBodyTemperature` is a fertility-tracking metric, **not** BMR. Drop it from the body-comp mapping. Huawei's `basalMetabolism` (kcal/day) has no good HK target — skip.
- Use iOS 16's sleep values (`asleepCore`, `asleepDeep`, `asleepREM`, `asleepUnspecified`, `awake`), not the legacy `.asleep`.
- `HKHealthStore.save(_:)` already has an `async throws` overload on iOS 15+. No `withCheckedThrowingContinuation` wrapper needed.
- Workouts (sport-per-minute, GPS routes) require `HKWorkoutBuilder` + `HKWorkoutRouteBuilder`, not bulk quantity-sample writes. Phase v1 ships **without** workouts to keep scope tight; phase v2 adds them. Architecture leaves seams in place.

---

## 1. Folder & file structure

```
HuaweiHealthImporter/                    # Xcode project root
├── HuaweiHealthImporter.xcodeproj
├── HuaweiHealthImporter/
│   ├── HuaweiHealthImporterApp.swift          # @main entry, App scene
│   ├── Info.plist                             # NSHealth*UsageDescription keys
│   ├── HuaweiHealthImporter.entitlements      # com.apple.developer.healthkit
│   │
│   ├── Models/
│   │   ├── HuaweiRecord.swift                 # Top-level record (Health detail data)
│   │   ├── HuaweiSamplePoint.swift            # Sample point inside a record
│   │   ├── HuaweiBodyComposition.swift        # Decodes WEIGHT_BODYFAT_BROAD value JSON
│   │   ├── HuaweiSleepStage.swift             # Sleep stage enum (SHALLOW/DEEP/DREAM/WAKE/NOON)
│   │   ├── HuaweiSportRecord.swift            # Top-level for Sport per minute merged data
│   │   ├── HuaweiSportBasicInfo.swift         # Per-minute steps/distance/calorie
│   │   ├── ImportSummary.swift                # Aggregated counters
│   │   └── ImportError.swift                  # Typed errors
│   │
│   ├── Mappers/
│   │   ├── HKMapping.swift                    # `key` → HealthKit type registry (the source of truth)
│   │   ├── BodyCompositionMapper.swift        # WEIGHT_BODYFAT_BROAD → up to 4 HKQuantitySamples
│   │   ├── HeartRateMapper.swift              # DATA_POINT_*_HEARTRATE → HKQuantitySample
│   │   ├── SleepMapper.swift                  # PROFESSIONAL_SLEEP_* → HKCategorySample
│   │   ├── BloodOxygenMapper.swift            # BLOOD_OXYGEN_SATURATION → HKQuantitySample
│   │   ├── StepsCaloriesMapper.swift          # sportBasicInfos[] → step/calorie/distance HKQuantitySamples
│   │   └── TimeZoneParser.swift               # "+0200" → TimeZone, Date(ms:) helpers
│   │
│   ├── Services/
│   │   ├── HKAuthService.swift                # Permission request, status query
│   │   ├── HKWriteService.swift               # Batched save + per-type dedup query
│   │   ├── ParserService.swift                # JSONDecoder + optional record-splitter for huge files
│   │   ├── FolderEnumerator.swift             # Walks an imported folder tree, filters .json
│   │   └── ImportPipeline.swift               # Orchestrates parse → map → dedup → write
│   │
│   ├── ViewModels/
│   │   ├── ImportViewModel.swift              # @MainActor ObservableObject driving UI state
│   │   └── ImportProgress.swift               # Codable progress snapshot (parsed/written/skipped/failed)
│   │
│   └── Views/
│       ├── RootView.swift                     # NavigationStack wrapper
│       ├── WelcomeView.swift                  # Folder picker + "Start Import" CTA
│       ├── PermissionGateView.swift           # Requests HK auth; explains denied state
│       ├── ImportProgressView.swift           # Live progress: file, counts, log tail
│       ├── ImportSummaryView.swift            # Final report: written/skipped/failed by type
│       ├── DocumentPicker.swift               # UIViewControllerRepresentable for folder picker
│       └── Components/
│           ├── StatRow.swift                  # "Heart Rate · 24,217 written · 0 skipped"
│           └── ProgressBarRow.swift           # Linear progress with eta
│
└── HuaweiHealthImporterTests/
    ├── FixturesTests.swift                    # Loads tiny pinned fixtures from Resources/
    ├── BodyCompositionMapperTests.swift
    ├── HeartRateMapperTests.swift
    ├── SleepMapperTests.swift
    ├── StepsCaloriesMapperTests.swift
    ├── TimeZoneParserTests.swift
    └── Resources/
        ├── weight_sample.json
        ├── heartrate_sample.json
        ├── sleep_sample.json
        └── sport_per_minute_sample.json
```

---

## 2. Codable models (full Swift)

### 2.1 `HuaweiRecord` + `HuaweiSamplePoint`

```swift
// Models/HuaweiRecord.swift
struct HuaweiRecord: Decodable {
    let type: Int
    let startTime: Int64           // Unix ms
    let endTime: Int64             // Unix ms
    let timeZone: String?          // e.g. "+0200"
    let deviceCode: Int64?
    let recordId: String?
    let samplePoints: [HuaweiSamplePoint]
}

// Models/HuaweiSamplePoint.swift
struct HuaweiSamplePoint: Decodable {
    let key: String                // canonical mapping key (CORRECTION: prefer this over `type`)
    let startTime: Int64
    let endTime: Int64
    let unit: String?              // Huawei's "0" usually means "default unit for this key"; ignore
    let value: String?             // String — may be a number "82.0" OR an embedded JSON object
}
```

### 2.2 Embedded body-composition JSON (the `value` of `WEIGHT_BODYFAT_BROAD`)

```swift
// Models/HuaweiBodyComposition.swift
struct HuaweiBodyComposition: Decodable {
    let bodyWeight: Double?            // kg
    let bodyFatRate: Double?           // %
    let bmi: Double?                   // kg/m²
    let muscleMass: Double?            // kg
    let skeletalMusclelMass: Double?   // kg (sic — Huawei's typo)
    let boneSalt: Double?              // kg
    let moistureRate: Double?          // %
    let proteinRate: Double?           // %
    let basalMetabolism: Double?       // kcal/day — no HK target, ignored
    let visceralFatLevel: Double?
    let bodyAge: Int?
    let bodyScore: Double?
    let height: Double?                // cm
    let age: Int?
    let gender: Int?
}
```

### 2.3 Sleep stage enum

```swift
// Models/HuaweiSleepStage.swift
enum HuaweiSleepStage: String {
    case shallow = "PROFESSIONAL_SLEEP_SHALLOW"
    case deep    = "PROFESSIONAL_SLEEP_DEEP"
    case rem     = "PROFESSIONAL_SLEEP_DREAM"
    case wake    = "PROFESSIONAL_SLEEP_WAKE"
    case noon    = "PROFESSIONAL_SLEEP_NOON"
}
```

### 2.4 Sport-per-minute schema (different shape — note the nesting)

```swift
// Models/HuaweiSportRecord.swift
struct HuaweiSportRecord: Decodable {
    let recordDay: Int                       // YYYYMMDD
    let sportDataUserData: [HuaweiSportEntry]
}

struct HuaweiSportEntry: Decodable {
    let startTime: Int64                     // ms
    let endTime: Int64                       // ms
    let timeZone: String?
    let deviceCode: Int64?
    let sportType: Int                       // 5 = walking, etc. (used as workout activity hint later)
    let sportBasicInfos: [HuaweiSportBasicInfo]
}

// Models/HuaweiSportBasicInfo.swift
struct HuaweiSportBasicInfo: Decodable {
    let steps: Int
    let distance: Int                        // meters
    let calorie: Int                         // *0.1 kcal? — verify in mapper, see §4
    let altitude: Double
    let floor: Int
    let duration: Int                        // minutes (always 1 in observed data)
    let count: Int
}
```

> **Calibration note:** Huawei's `calorie` field is reported in tenths of a kcal in some firmwares (values like `449` for one minute of walking imply 44.9 kcal — too high; needs validation against a known source). The `StepsCaloriesMapper` divides by 10 *and* clamps; we expose a calibration toggle in the import UI for v1.

---

## 3. Mapping registry

```swift
// Mappers/HKMapping.swift
enum HKMapping {
    enum Target {
        case quantity(HKQuantityTypeIdentifier, HKUnit)
        case category(HKCategoryTypeIdentifier, value: Int)
        case bodyComposition          // expands into multiple samples in BodyCompositionMapper
        case skip(reason: String)
    }

    /// Canonical mapping by `key`. Always preferred over `type`.
    static func target(forKey key: String) -> Target {
        switch key {
        case "DATA_POINT_DYNAMIC_HEARTRATE",
             "DATA_POINT_REST_HEARTRATE":
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

        case "STRESS_DATA":
            return .skip(reason: "No HealthKit equivalent for stress")
        case "EXERCISE_INTENSITY":
            return .skip(reason: "Aggregated activity intensity has no direct HK type")

        default:
            return .skip(reason: "Unmapped key: \(key)")
        }
    }
}
```

Body composition expands into:

| Huawei field    | HK type                | Unit               | Notes                                           |
| --------------- | ---------------------- | ------------------ | ----------------------------------------------- |
| `bodyWeight`    | `bodyMass`             | `gramUnit(.kilo)`  |                                                 |
| `bodyFatRate`   | `bodyFatPercentage`    | `percent()`        | Huawei value in %, divide by 100 for HK         |
| `bmi`           | `bodyMassIndex`        | `count()`          |                                                 |
| derived `(1-bfr)*weight` | `leanBodyMass`| `gramUnit(.kilo)`  | Computed when both weight + bfr present          |
| `height`        | `height`               | `meterUnit(.centi)`| Optional — only write once per import (latest)  |

---

## 4. HealthKit permissions

Request **share** (write) authorization for exactly these types:

```swift
let writeShares: Set<HKSampleType> = [
    HKQuantityType(.heartRate),
    HKQuantityType(.oxygenSaturation),
    HKQuantityType(.bodyMass),
    HKQuantityType(.bodyFatPercentage),
    HKQuantityType(.bodyMassIndex),
    HKQuantityType(.leanBodyMass),
    HKQuantityType(.height),
    HKQuantityType(.stepCount),
    HKQuantityType(.distanceWalkingRunning),
    HKQuantityType(.activeEnergyBurned),
    HKCategoryType(.sleepAnalysis),
]

// Read permission needed only for dedup queries:
let readShares: Set<HKObjectType> = writeShares
```

Info.plist keys:
- `NSHealthUpdateUsageDescription` — "Imports your historical Huawei Health data into Apple Health."
- `NSHealthShareUsageDescription` — "Used only to detect and skip records that are already in Apple Health (deduplication)."

---

## 5. Parsing strategy

### 5.1 Default path (recommended)

Per file:

```swift
let url: URL = …
let data = try Data(contentsOf: url, options: .mappedIfSafe)   // OS-paged, not heap-copied
let records = try JSONDecoder().decode([HuaweiRecord].self, from: data)
```

`mappedIfSafe` lets the OS demand-page the file; only the parsed Swift objects sit in heap. For the observed export (max 3 MB / file) this peaks at ~30 MB heap during parse — well inside iPhone's allowance.

### 5.2 Fallback for >50 MB single files (optional, ship behind a flag)

If a file exceeds a threshold (default 50 MB), use a brace-counting record splitter:

```swift
// Pseudocode — see ParserService.swift for full impl
func streamRecords(in url: URL) -> AsyncThrowingStream<HuaweiRecord, Error> {
    AsyncThrowingStream { continuation in
        Task.detached(priority: .utility) {
            do {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }

                var depth = 0
                var inString = false
                var escape = false
                var buffer = Data()
                var sawArrayStart = false

                while autoreleasepool(invoking: {
                    let chunk = handle.readData(ofLength: 64 * 1024)
                    guard !chunk.isEmpty else { return false }
                    for byte in chunk {
                        if !sawArrayStart {
                            if byte == 0x5B /* [ */ { sawArrayStart = true }
                            continue
                        }
                        if escape { escape = false; buffer.append(byte); continue }
                        if inString {
                            if byte == 0x5C /* \ */ { escape = true }
                            else if byte == 0x22 /* " */ { inString = false }
                            buffer.append(byte); continue
                        }
                        switch byte {
                        case 0x22 /* " */: inString = true; buffer.append(byte)
                        case 0x7B /* { */:
                            depth += 1; buffer.append(byte)
                        case 0x7D /* } */:
                            depth -= 1; buffer.append(byte)
                            if depth == 0 {
                                let record = try JSONDecoder().decode(HuaweiRecord.self, from: buffer)
                                continuation.yield(record)
                                buffer.removeAll(keepingCapacity: true)
                            }
                        case 0x2C /* , */ where depth == 0: ()       // separator between records
                        case 0x5D /* ] */ where depth == 0: ()       // array end
                        default: if depth > 0 { buffer.append(byte) }
                        }
                    }
                    return true
                }) {}
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}
```

This is **not used by default** — it ships dormant. The architecture leaves the seam (`ParserService.recordStream(for:)`) so we can swap in the streamer per-file based on size.

### 5.3 Sport-per-minute parser

Different schema → its own `JSONDecoder().decode([HuaweiSportRecord].self, …)` call. Aggregate per-minute sport entries into per-day or per-record `HKQuantitySample`s — emit one `stepCount`, one `distanceWalkingRunning`, one `activeEnergyBurned` per `HuaweiSportEntry`.

---

## 6. Batched write + dedup strategy

### 6.1 The flow

```
For each HKObjectType T present in the import:
    1. Compute [minStart, maxEnd] across all to-write samples for T.
    2. Run ONE HKSampleQuery for T over that window.
    3. Build Set<UInt64> of existing keys: hash("T|startMs|endMs").
    4. Stream candidate samples through a filter using that Set.
    5. Buffer up to 500 samples → call `try await store.save(_:)` → flush.
    6. Update progress on @MainActor every 100 records.
```

This is **one round-trip per type** instead of one per batch. For the example user, that's ~10 queries vs. ~250+ in the prompt's design.

### 6.2 Why not `HKSampleQuery` per batch

Each `HKSampleQuery` blocks on HealthKit IPC. With 50,000 heart-rate samples in 500-batches, the prompt's design is 100+ IPC round-trips just for dedup. Front-loading collapses that to one.

### 6.3 Save API

```swift
// HKHealthStore.save(_:) is `async throws` on iOS 15+ — use it directly.
try await healthStore.save(samples)
```

---

## 7. SwiftUI view hierarchy

```
RootView (NavigationStack)
└── switch viewModel.phase
    ├── .welcome   → WelcomeView
    │     • "Choose Huawei export folder" button → DocumentPicker (folder mode)
    │     • Tip text linking to Huawei Privacy Center
    │     • CTA "Start Import" (disabled until folder picked + permissions granted)
    │
    ├── .permissionGate → PermissionGateView
    │     • Explains read/write usage
    │     • [Continue] → calls HKAuthService.requestAuthorization()
    │     • Handles denied case with deep-link to Settings
    │
    ├── .importing → ImportProgressView
    │     • Progress bar (files complete / total)
    │     • Current file name
    │     • Stat rows by type (parsed / written / skipped-dup / failed)
    │     • Recent log tail (last 50 lines)
    │     • [Cancel] cancels Task
    │
    └── .summary → ImportSummaryView
          • By-type breakdown (StatRow[])
          • Total runtime
          • [Done] resets viewModel for another run
          • [Export log] saves text log to Files via UIActivityViewController
```

State on `ImportViewModel: ObservableObject, @MainActor`:

```swift
@Published var phase: Phase = .welcome
@Published var pickedFolder: URL?
@Published var progress: ImportProgress = .empty
@Published var summary: ImportSummary?
@Published var lastError: ImportError?
```

User actions:
- `pickFolder(URL)` — store, advance to `.permissionGate` if not yet authorized
- `startImport()` — kicks off `Task { await pipeline.run(...) }`
- `cancelImport()` — `task.cancel()`
- `reset()` — back to `.welcome`

---

## 8. Implementation order (for Sonnet)

Build files in this order. After each file, the project must compile. Confirm with ⌘B / `xcodebuild -scheme HuaweiHealthImporter build` before moving on.

1. **Project scaffold** — `xcodebuild` or Xcode UI: SwiftUI app, iOS 16, name `HuaweiHealthImporter`. Add HealthKit capability. Add Info.plist usage strings.
2. **`Models/HuaweiSamplePoint.swift`** — Codable struct for sample point.
3. **`Models/HuaweiRecord.swift`** — Codable struct for top-level record.
4. **`Models/HuaweiBodyComposition.swift`** — embedded JSON struct.
5. **`Models/HuaweiSleepStage.swift`** — string-raw enum.
6. **`Models/HuaweiSportRecord.swift`** + **`Models/HuaweiSportBasicInfo.swift`** — sport schema.
7. **`Models/ImportError.swift`** — typed error enum.
8. **`Models/ImportSummary.swift`** + `ViewModels/ImportProgress.swift` — counter structs.
9. **`Mappers/TimeZoneParser.swift`** — `parseOffset("+0200") -> TimeZone`, `date(fromUnixMs:) -> Date`. Unit test.
10. **`Mappers/HKMapping.swift`** — registry from §3. Unit test the switch.
11. **`Mappers/HeartRateMapper.swift`** — record → `HKQuantitySample`. Unit test.
12. **`Mappers/BodyCompositionMapper.swift`** — record → up to 5 samples. Unit test against fixture.
13. **`Mappers/SleepMapper.swift`** — record → `HKCategorySample`. Unit test.
14. **`Mappers/BloodOxygenMapper.swift`** — record → `HKQuantitySample`. Unit test.
15. **`Mappers/StepsCaloriesMapper.swift`** — sport entry → 3 samples (steps/distance/calories). Unit test with calibration toggle.
16. **`Services/ParserService.swift`** — `decode(_:as:)` per-file path; stub `recordStream(for:)` for §5.2.
17. **`Services/FolderEnumerator.swift`** — recursive walk of picked folder; classifies files by parent folder name.
18. **`Services/HKAuthService.swift`** — request authorization, status query.
19. **`Services/HKWriteService.swift`** — dedup + batched save per §6.
20. **`Services/ImportPipeline.swift`** — orchestrator: parse → map → dedup → write → progress.
21. **`ViewModels/ImportViewModel.swift`** — state machine, `Task` lifecycle.
22. **`Views/DocumentPicker.swift`** — UIViewControllerRepresentable wrapping `UIDocumentPickerViewController` in folder mode.
23. **`Views/Components/StatRow.swift`** + `ProgressBarRow.swift`.
24. **`Views/WelcomeView.swift`**.
25. **`Views/PermissionGateView.swift`**.
26. **`Views/ImportProgressView.swift`**.
27. **`Views/ImportSummaryView.swift`**.
28. **`Views/RootView.swift`** — switch on phase.
29. **`HuaweiHealthImporterApp.swift`** — App scene with `RootView`.
30. **Smoke test on device** — pick the real `HUAWEI_HEALTH_…` folder, run end-to-end, check Apple Health.

Test fixtures (created in step 9 onwards): tiny pinned JSONs derived from the real export — one record each — checked into `HuaweiHealthImporterTests/Resources/`.

---

## 9. Out of scope for v1 (explicitly deferred)

- Workouts (`HKWorkoutBuilder`) and GPS routes (`HKWorkoutRouteBuilder`) — needs the `Motion path detail` GPS string parser. Architecture leaves the seam open; v2 adds `WorkoutMapper` + `GPSStringParser`.
- Stress, exercise intensity, sample sequence, and run plans — no good HK targets.
- iCloud / Files import: v1 supports local folder pick only. The `UIDocumentPickerViewController` already covers iCloud Drive transparently.
- Background imports: v1 is foreground-only. Needs `BGProcessingTask` for v2.
- Calorie calibration: v1 ships a manual divisor (default ÷10) toggleable in the welcome screen; v2 derives the divisor from a known reference day.

---

## 10. Open questions to confirm before coding

1. **Calorie unit.** `calorie:449` for one minute of walking is implausible if treated as kcal. Best guess: 0.1 kcal increments → 44.9 kcal/min still high. Validate against a day where the user remembers their step count. Ship behind a UI toggle.
2. **Multi-user exports.** Reference Python script handles `subUser` / `extendAttribute` — body comp `value` JSON has `gender`/`age`/`height`. Single-user assumption is fine for v1; document the limitation.
3. **Source attribution.** Set `HKMetadataKeyExternalUUID` to Huawei's `recordId` and `metadata["HuaweiDeviceCode"]` to `deviceCode` so users can later filter/delete only the imported data.
