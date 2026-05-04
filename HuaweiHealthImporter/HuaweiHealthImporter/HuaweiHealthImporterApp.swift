import SwiftUI
import HealthKit

@main
struct HuaweiHealthImporterApp: App {

    @StateObject private var viewModel = ImportViewModel()

    var body: some Scene {
        WindowGroup {
            if HKHealthStore.isHealthDataAvailable() {
                RootView()
                    .environmentObject(viewModel)
            } else {
                // iPad / simulator fallback (iOS 16 compatible)
                VStack(spacing: 16) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                    Text("HealthKit Unavailable")
                        .font(.title2.bold())
                    Text("Apple Health is not available on this device. Please run on a real iPhone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
}
