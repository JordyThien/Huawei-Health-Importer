import SwiftUI

/// Root navigation container. Switches between phases based on `ImportViewModel.phase`.
struct RootView: View {
    @EnvironmentObject var vm: ImportViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch vm.phase {
                case .welcome:
                    WelcomeView()
                        .navigationTitle("Huawei Importer")

                case .permissionGate:
                    PermissionGateView()
                        .navigationTitle("Permissions")

                case .importing:
                    ImportProgressView()

                case .summary:
                    ImportSummaryView()
                }
            }
            .animation(.easeInOut, value: vm.phase)
        }
    }
}
