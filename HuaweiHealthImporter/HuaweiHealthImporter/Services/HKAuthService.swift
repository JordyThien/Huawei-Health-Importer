import Foundation
import HealthKit

/// Manages HealthKit authorization requests and status checks.
actor HKAuthService {

    private let store: HKHealthStore

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    /// Returns `true` if HealthKit is available on this device.
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read + write authorization for all types the app uses.
    /// Throws `ImportError.healthKitAuthDenied` if the request itself fails
    /// (note: user tapping "Don't Allow" does NOT throw — HK silently grants partial access).
    func requestAuthorization() async throws {
        guard Self.isAvailable else { throw ImportError.healthKitAuthDenied }
        try await store.requestAuthorization(
            toShare: HKMapping.allWriteTypes,
            read: HKMapping.allReadTypes
        )
    }

    /// Returns `true` if the app has `.sharingAuthorized` for at least one write type.
    /// Used to decide whether to show the permission gate.
    func hasAnyWriteAccess() -> Bool {
        for id in HKMapping.writeQuantityTypes {
            let t = HKQuantityType(id)
            if store.authorizationStatus(for: t) == .sharingAuthorized { return true }
        }
        for id in HKMapping.writeCategoryTypes {
            let t = HKCategoryType(id)
            if store.authorizationStatus(for: t) == .sharingAuthorized { return true }
        }
        return false
    }
}
