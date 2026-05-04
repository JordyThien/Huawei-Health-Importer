import Foundation

/// Maps Huawei sleep `key` strings to semantic stages.
enum HuaweiSleepStage: String {
    case shallow = "PROFESSIONAL_SLEEP_SHALLOW"  // core sleep
    case deep    = "PROFESSIONAL_SLEEP_DEEP"
    case rem     = "PROFESSIONAL_SLEEP_DREAM"
    case wake    = "PROFESSIONAL_SLEEP_WAKE"
    case noon    = "PROFESSIONAL_SLEEP_NOON"     // nap → asleepUnspecified
}
