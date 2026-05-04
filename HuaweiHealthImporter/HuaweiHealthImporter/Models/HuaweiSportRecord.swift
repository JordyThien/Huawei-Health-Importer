import Foundation

/// Top-level record from the "Sport per minute merged data" JSON arrays.
/// Has a different shape from the Health detail data schema.
struct HuaweiSportRecord: Decodable {
    let recordDay: Int                          // YYYYMMDD
    let sportDataUserData: [HuaweiSportEntry]
}

/// One sport session entry inside a `HuaweiSportRecord`.
struct HuaweiSportEntry: Decodable {
    let startTime: Int64                        // ms
    let endTime: Int64                          // ms
    let timeZone: String?
    let deviceCode: Int64?
    let sportType: Int                          // 5 = walking/general; used as workout activity hint in v2
    let sportBasicInfos: [HuaweiSportBasicInfo]
}
