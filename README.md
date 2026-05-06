# Huawei Health Importer

> Import Huawei Health data — plus the local-only history from the **Huawei Body Fat Scale (CH100)** companion app, which never leaves your phone — into Apple Health.

[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](#license)
[![Status](https://img.shields.io/badge/status-personal--use-lightgrey.svg)](#disclaimer)

---

## What this is

A SwiftUI iOS app (iOS 16+) that reads a Huawei Health export folder and/or a CSV dump from the Huawei Body Fat Scale's unencrypted on-device database, deduplicates against existing HealthKit data, and writes the result to Apple Health. Everything happens on-device; the app makes zero network calls.

Bundled with the app is a writeup of how the unencrypted database (`HW100.db`) was reverse-engineered. If you only came for the keys and the journey, jump to [The reverse-engineering story](#the-reverse-engineering-story).

## Why this exists

I'd been weighing in on a Huawei Body Fat Scale (model **CH100**, hardware **AH100**) for roughly six years. When I tried to migrate to Apple Health, the data turned out to live in two completely separate places:

1. **Huawei's official data-export portal** at [`privacy.consumer.huawei.com/tool`](https://privacy.consumer.huawei.com/tool) — the self-service GDPR-style flow you sign into with your Huawei ID — returned everything Huawei's cloud had against my account. For me that was around six weeks of weight from late 2020 plus various other bits; the bulk of my weight history was nowhere in it. (I don't currently have the Huawei Health app installed and didn't need to install it to request the export — the portal is web-only.) Heart rate, sleep, activity from a paired wearable would all flow through this same export, because…
2. **The scale doesn't sync to Huawei's cloud at all.** The CH100 ships with its own dedicated companion app — **"Huawei Body Fat Scale"** (`com.huawei.ch100`) — that stores every measurement in a local SQLite database (`HW100.db`) and **never uploads anywhere**. No cloud, no Huawei Health integration, no built-in export. Six years of measurements were sitting unencrypted-in-spirit but encrypted-in-fact on the phone, with no documented way to get them out.

So the fix needed two halves: an importer for what Huawei Health *does* hand you via its export, and a reverse-engineering recipe for the local database the scale's companion app keeps to itself.

## Data flow

```
                                ┌────────────────────────────────┐
Huawei Health app ─────────────►│ HUAWEI_HEALTH_<timestamp>/     │  HR, sleep, steps, GPS,
"Me → Privacy → Export data"    │   Health detail data/          │  + any weight tracked
                                │   Sport per minute merged/     │  inside Huawei Health
                                │   Motion path detail/          │  itself (often little
                                └────────────────┬───────────────┘  to none)
                                                 │
"Huawei Body Fat Scale" app                      │
(com.huawei.ch100, local-only,  ┌──────────┐     │
no cloud, no Huawei Health  ──► │ HW100.db │ ────┤
integration, no export UI)      │ encrypted│     │
                                └──────────┘     │
                                                 │
                                      ┌──────────▼──────────┐
                                      │ AES key recovery    │   XOR-with-0x11 obfuscation
                                      │ from Android APK    │   + AES/CBC/PKCS5 wrapper
                                      └──────────┬──────────┘
                                                 │ passphrase: bT8f#*4v9
                                      ┌──────────▼──────────┐
                                      │ sqlcipher v4 dump   │   787 rows · 2020-11-15 → 2026-04-28
                                      │   → bodyfat.csv     │
                                      └──────────┬──────────┘
                                                 │
                                      ┌──────────▼──────────┐
                                      │ HuaweiHealthImporter│   parse → map → dedup → save
                                      │      (this app)     │
                                      └──────────┬──────────┘
                                                 │
                                          Apple HealthKit
```

---

## The reverse-engineering story

This is the part that took the longest and made the rest of the project possible. Skip to [Using it](#using-it) if you just want to import.

### 1. Two apps, two data silos

Huawei ships **two separate iOS apps** that both touch body data:

- **Huawei Health** (`com.huawei.health`) — the main fitness app for wearables, with cloud sync to your Huawei ID. The cloud-side data is also reachable through the web portal at [`privacy.consumer.huawei.com/tool`](https://privacy.consumer.huawei.com/tool); you can request a full export there without ever installing the app.
- **Huawei Body Fat Scale** (`com.huawei.ch100`) — a dedicated companion app for the CH100 / AH100 scale. **Local-only**, no cloud sync, no Huawei Health hand-off, no export UI of any kind. It writes every weigh-in to a SQLite file (`HW100.db`) inside its own sandbox and stops there.

The Huawei privacy-portal export covers what Huawei's cloud knows about. For me that included six weeks of weight from late 2020 plus other miscellany — but the bulk six years of body-composition history lived only in the scale's companion app, in a database that has never left my phone. Getting at it meant pulling the app sandbox out of an unencrypted iOS backup with iMazing and dealing with `HW100.db` on its own terms.

### 2. First look at HW100.db

```
size:    151,552 bytes (148 KB)
entropy: 7.9988 / 8.0
unique bytes: 256/256 present
SQLite header: missing
```

Maximum entropy plus the absence of a `SQLite format 3` header is the canonical fingerprint of an encrypted database. The size aligns to standard SQLite page sizes (148 × 1024, 74 × 2048, 37 × 4096), which strongly suggested the underlying engine *was* SQLite — just wrapped.

Three candidate wrappers: SQLCipher, SEE (SQLite Encryption Extension), and a homegrown scheme. I started where the universe usually points — SQLCipher.

### 3. Things that did not work

The companion file `com.huawei.ch100.plist` had a field `KeyMember_id: 1`. Tempting, but it turned out to be a local user-row index, not a cryptographic key.

I tried SQLCipher v1, v2, v3 and v4 with every reasonable passphrase candidate I could derive from the device:

- plist values (`1`, the user's display name, etc.)
- the device UDID and various derivatives
- literal strings: `"huawei"`, `"hidata"`, `"HW100"`, `"ch100"`, `"CH100"`
- the AES constants from openScale's reverse-engineered BLE protocol

Nothing opened it. The bundle ID `com.huawei.ch100` is shared with an Android app, though — and Android apps are far easier to read than iOS ones.

### 4. The pivot to the Android APK

Pulled `Huawei Body Fat Scale_CH100_V1.1.11.120_APKPure.apk` from APKPure and decompiled it with **jadx**. Two things stood out immediately:

```java
import net.sqlcipher.database.SQLiteDatabase;   // ← confirms SQLCipher (not SEE)
...
helper.getReadableDatabase(PP.p());              // ← key comes from PP.p()
```

`PP.p()` does **not** return a static string. It returns the result of an AES decryption, with all three inputs (key, IV, ciphertext) themselves obfuscated by being split across multiple classes and XORed with a constant.

### 5. Tracing the key derivation

`helper.getReadableDatabase(PP.p())` led to `EeUtil.qq(dir, dbc, ir)`, which is a textbook AES wrapper:

```java
// reconstructed
Cipher c = Cipher.getInstance("AES/CBC/PKCS5Padding");
c.init(Cipher.DECRYPT_MODE,
       new SecretKeySpec(deobfuscate(dbc), "AES"),
       new IvParameterSpec(deobfuscate(ir)));
return new String(c.doFinal(Base64.decode(deobfuscate(dir))));
```

`deobfuscate(...)` XORs each byte of the input array with **`0x11` (decimal 17)**. The three inputs are each assembled by concatenating byte-array constants pulled from three unrelated DAO/field classes — presumably so a casual `strings` pass on the APK turns up nothing useful.

After unwinding the concatenation:

| Role | Source fields | XOR-decoded value |
| --- | --- | --- |
| **IV** (`ir`) | `AppField.d` + `ProviderUserDao.d` + `ProviderFatDao.d` | `asdvjer#522d4fef` |
| **Key** (`dbc`) | `Conn.e` + `FieldNames.e` + `ProviderFatDao.e` | `oxr0gEubYT32mS9p` |
| **Ciphertext** (`dir`, base64) | `ProviderControversyDao.c` + `FieldNames.D` + `ProviderFatDao.c` | `7RQ/wb3Wce8mi2EYb5Tc3Q==` |

### 6. Recovering the SQLCipher passphrase

```python
from base64 import b64decode
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad

XOR = 0x11
def deob(s: str) -> bytes:
    return bytes(b ^ XOR for b in s.encode())

iv  = deob("asdvjer#522d4fef")
key = deob("oxr0gEubYT32mS9p")
ct  = b64decode("7RQ/wb3Wce8mi2EYb5Tc3Q==")

passphrase = unpad(AES.new(key, AES.MODE_CBC, iv).decrypt(ct), 16).decode()
print(passphrase)   # → bT8f#*4v9
```

The recovered SQLCipher passphrase is **`bT8f#*4v9`**.

### 7. Opening the database

SQLCipher v4 defaults — no `cipher_compatibility` pragma, no custom KDF iterations, no page-size override:

```bash
sqlcipher HW100.db
sqlite> PRAGMA key = 'bT8f#*4v9';
sqlite> .tables
Alarm           DeviceInfo      Member          TempBodyFat
BodyFat         sqlite_sequence
sqlite> SELECT count(*), min(time), max(time) FROM BodyFat;
787|2020-11-15 …|2026-04-28 …
```

**787 rows. 2020-11-15 to 2026-04-28.** The full six years. Every measurement the official export silently dropped.

### 8. What we learned

- The XOR-then-concat-then-AES pattern is consistent with the SBA Research Easterhegg 2019 talk on Android obfuscation — it slows down a casual `strings` audit but adds zero real cryptographic strength once you have the bytecode.
- The passphrase is presumably static across versions and across all CH100 scales (it's baked into the app, not derived from any per-device value). It worked on a database from 2020-2026; it may stop working on a future major version.
- The Huawei Body Fat Scale app having no cloud sync and no export is a product decision, not a bug — but the data is on the user's own phone, owned by the user, and a static app-bundled key is, at best, a speed bump.

---

## What you can extract

| Source | Field / table | HealthKit target | Status |
| --- | --- | --- | --- |
| Huawei JSON · `Health detail data/` | `DATA_POINT_DYNAMIC_HEARTRATE`, `DATA_POINT_REST_HEARTRATE` | `heartRate` | Imported |
| Huawei JSON · `Health detail data/` | `BLOOD_OXYGEN_SATURATION` | `oxygenSaturation` | Imported |
| Huawei JSON · `Health detail data/` | `WEIGHT_BODYFAT_BROAD` | `bodyMass`, `bodyFatPercentage`, `bodyMassIndex`, `leanBodyMass` | Imported |
| Huawei JSON · `Health detail data/` | `PROFESSIONAL_SLEEP_*` | `sleepAnalysis` (asleepCore / Deep / REM / Unspecified / awake) | Imported |
| Huawei JSON · `Sport per minute merged/` | `sportBasicInfos[]` | `stepCount`, `distanceWalkingRunning`, `activeEnergyBurned` | Imported |
| Huawei JSON · `Health detail data/` | `STRESS_DATA`, `EXERCISE_INTENSITY` | — | Skipped (no HK type) |
| Huawei JSON · `Motion path detail/` | GPS attribute string | `HKWorkoutRoute` | **Not in v1** |
| CH100 DB · `BodyFat.weight` | | `bodyMass` | Imported |
| CH100 DB · `BodyFat.bmi` | | `bodyMassIndex` | Imported |
| CH100 DB · `BodyFat.adiposerate` | | `bodyFatPercentage` | Imported |
| CH100 DB · `BodyFat.weight × (1 − bf%/100)` | derived | `leanBodyMass` | Imported |
| CH100 DB · `bone`, `moisture`, `visceralfat`, `bmr`, `protein`, `bodyAge`, `score`, `resistance` | | — | Dropped (no HK type) |

Mapping is keyed on the canonical `key` string, not Huawei's `type` integer — `type` values vary by firmware. See [`ARCHITECTURE.md`](./ARCHITECTURE.md) §3 for the full registry.

---

## Using it

There are two paths. They're independent — you can run either or both. If you run both, the importer deduplicates against existing HealthKit samples so re-runs and overlapping sources are safe.

### Path A — Huawei privacy-portal export (heart rate, sleep, activity)

1. Sign in to [**`privacy.consumer.huawei.com/tool`**](https://privacy.consumer.huawei.com/tool) with your Huawei ID and request a data export. (You can also trigger this from inside the Huawei Health iOS app under *Me → Settings → Privacy Center*, but the web portal works without the app installed.) Wait for the archive — Huawei delivers it via the same portal once it's ready.
2. Unzip the archive. You'll get a folder named `HUAWEI_HEALTH_<timestamp>/`.
3. Copy the folder to your iPhone (AirDrop, iCloud Drive, Files — anywhere accessible to the document picker).
4. In the importer app: **Pick Huawei export folder** → select the `HUAWEI_HEALTH_<timestamp>` folder → **Start Import**.

This covers wearable data Huawei's cloud has synced (heart rate, sleep, steps, distance, calories, GPS routes when v2 lands). It will **not** include scale measurements — those live only in the CH100 companion app and require Path B.

### Path B — Full body-composition history via HW100.db

This is for the CH100 / AH100 Body Fat Scale specifically. The scale's companion app (`com.huawei.ch100`) is local-only and provides no export, so the data has to be lifted out of its sandbox and decrypted manually.

**1. Pull the app sandbox out of an iOS backup.**

Make an unencrypted local backup of the iPhone (iMazing, iTunes, Finder — anything that does a full sandbox backup). Open the backup in [iMazing](https://imazing.com), navigate to the `com.huawei.ch100` ("Huawei Body Fat Scale") app data, and extract `HW100.db`.

**2. Decrypt and dump to CSV.**

Install [SQLCipher](https://www.zetetic.net/sqlcipher/) (`brew install sqlcipher` on macOS) and run:

```bash
echo "PRAGMA key = 'bT8f#*4v9';
.mode csv
.headers on
SELECT
  time,
  weight,
  bmi,
  adiposerate AS body_fat_pct,
  muscle,
  moisture   AS water_pct,
  bone,
  bmr,
  visceralfat AS visceral_fat,
  protein,
  bodyAge    AS body_age,
  score,
  resistance
FROM BodyFat
ORDER BY time;" | sqlcipher HW100.db > bodyfat_export.csv
```

You should get a CSV with one header row and (in my case) 787 measurement rows.

**3. Run the importer.**

In the app, in addition to (or instead of) picking a JSON folder, **Pick CH100 CSV** and select `bodyfat_export.csv`. **Start Import.** The importer will write `bodyMass`, `bodyMassIndex`, `bodyFatPercentage` and a derived `leanBodyMass` to HealthKit. The fields without HK equivalents are skipped — see the table above.

---

## Building & running the app

The app is not on the App Store and isn't going there — it's a personal-use tool. To run it on your own device:

```bash
# Prerequisites: Xcode 15+, xcodegen (brew install xcodegen)
cd HuaweiHealthImporter
xcodegen generate
open HuaweiHealthImporter.xcodeproj
```

In Xcode:

1. Select the `HuaweiHealthImporter` target → **Signing & Capabilities** → set **Team** to your personal Apple ID.
2. Change the bundle identifier to something unique (e.g. `com.<yourname>.huaweihealthimporter`).
3. Plug in your iPhone, select it as the run destination, and **⌘R**.
4. On first launch, grant the requested HealthKit permissions. Read access is requested only for deduplication — see `Info.plist` strings.

Personal-team sideloads expire after seven days; rebuild from Xcode when that happens. There is no provisioning profile to renew, no certificate to manage.

---

## Project layout

```
HuaweiHealthImporter/
├── project.yml                   # xcodegen project definition
└── HuaweiHealthImporter/
    ├── Models/        # Codable structs: HuaweiRecord, samplePoint, BodyComposition, CH100Row…
    ├── Mappers/       # Per-key → HealthKit sample(s); HKMapping registry; CH100BodyCompositionMapper
    ├── Services/      # ParserService, CH100CSVParser, HKAuthService, HKWriteService, ImportPipeline
    ├── ViewModels/    # ImportViewModel (@MainActor state machine)
    └── Views/         # SwiftUI: Welcome, PermissionGate, ImportProgress, ImportSummary, pickers
HuaweiHealthImporterTests/        # Mapper + parser unit tests with pinned fixtures
```

For the data flow, dedup strategy, mapping registry, and rationale behind decoder choices, see [`ARCHITECTURE.md`](./ARCHITECTURE.md). It is the source of truth for *why* — this README intentionally doesn't duplicate it.

---

## Limitations / not implemented

- **Workouts and GPS routes** (`Motion path detail/`) — needs `HKWorkoutBuilder` + `HKWorkoutRouteBuilder` and a parser for Huawei's custom GPS attribute string. Architecture leaves the seam in `Services/` for v2.
- **Heart rate variability, activity rings, VO₂max** — not present in the export.
- **Stress, exercise intensity** — no native HealthKit type; intentionally skipped.
- **CH100 fields with no HK equivalent** — bone mass, water %, visceral fat level, BMR, protein %, body age, score, resistance — are dropped during CSV import. Track separately if you need them.
- **Background imports** — v1 is foreground-only. Closing the app cancels the run; resuming is safe because of dedup.
- **Multi-user CH100 households** — the CSV path assumes a single user. The DB has a `Member` table; v1 ignores it.
- **Calorie calibration** — Huawei's per-minute `calorie` field is reported in tenths of a kcal in observed firmwares. The mapper divides by 10 and exposes a UI toggle; validate against a known day before trusting bulk imports.

---

## Disclaimer

- This is a personal-use tool for recovering **your own** health data from **your own** devices and **your own** iOS backup. Don't point it at anyone else's data.
- Reverse engineering was performed on a publicly distributed Android APK and on data from devices I own. No services were attacked; no accounts were compromised.
- The recovered SQLCipher passphrase (`bT8f#*4v9`) is embedded in the shipping Android version of the **Huawei Body Fat Scale** app and presumably static across CH100 builds, but Huawei could change it in any update. If decryption stops working on a new database, the obfuscation pattern (`AES/CBC/PKCS5Padding`, key/IV/ciphertext XORed with `0x11`, split across DAO/field classes) is likely still in place — re-run jadx and re-extract.
- Not affiliated with Huawei or Apple. Trademarks belong to their respective owners.
- HealthKit imports cannot be cleanly bulk-deleted by source if you change your mind. The importer tags every sample with `HKMetadataKeyExternalUUID` and a `HuaweiDeviceCode` metadata key so a future cleanup script can find them, but Apple Health's UI deletes one type at a time.

---

## Credits & references

- [**openScale**](https://github.com/oliexdev/openScale) (GPL) — Android body-composition app whose reverse-engineered BLE protocol confirmed the AES constant flavour Huawei uses elsewhere.
- **SBA Research, Easterhegg 2019** — talk on Android string-obfuscation patterns; the XOR-split-concat trick used here is textbook.
- [**jadx**](https://github.com/skylot/jadx) — the only reason any of this was tractable in an evening.
- [**SQLCipher**](https://www.zetetic.net/sqlcipher/) — full-database AES encryption layered on SQLite.
- [**pycryptodome**](https://www.pycryptodome.org/) — used for the AES/CBC/PKCS5 unwrap in the Python recovery snippet.
- [**iMazing**](https://imazing.com) — for extracting the app sandbox out of an iOS backup without restoring it.
- [`huawei-health-to-health-connect`](https://github.com/) (various forks) — earlier prior art that confirmed the `type:10006` weight mapping for older firmwares.

---

## License

MIT.

```
Copyright (c) 2026 Jordy Thien

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
```
