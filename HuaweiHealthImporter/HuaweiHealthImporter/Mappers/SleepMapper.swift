import Foundation
import HealthKit

/// Maps Huawei `PROFESSIONAL_SLEEP_*` sample points to `HKCategorySample` sleep analysis samples.
enum SleepMapper {

    static let type = HKCategoryType(.sleepAnalysis)

    static func sample(from point: HuaweiSamplePoint,
                       recordId: String?,
                       deviceCode: Int64?) -> HKCategorySample? {
        guard let stage = HuaweiSleepStage(rawValue: point.key) else { return nil }

        let hkValue: HKCategoryValueSleepAnalysis
        switch stage {
        case .shallow: hkValue = .asleepCore
        case .deep:    hkValue = .asleepDeep
        case .rem:     hkValue = .asleepREM
        case .noon:    hkValue = .asleepUnspecified
        case .wake:    hkValue = .awake
        }

        let start = TimeZoneParser.date(fromUnixMs: point.startTime)
        let end   = TimeZoneParser.date(fromUnixMs: point.endTime)
        let safeEnd = end >= start ? end : start

        var meta: [String: Any] = [:]
        if let rid = recordId { meta[HKMetadataKeyExternalUUID] = rid }
        if let dc = deviceCode { meta["HuaweiDeviceCode"] = dc }

        return HKCategorySample(type: type,
                                value: hkValue.rawValue,
                                start: start,
                                end: safeEnd,
                                metadata: meta.isEmpty ? nil : meta)
    }
}
