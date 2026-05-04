import SwiftUI

struct PermissionGateView: View {
    @EnvironmentObject var vm: ImportViewModel
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("Apple Health Access")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 12) {
                permRow("arrow.up.heart.fill",
                        "Write access",
                        "Saves your Huawei health data (heart rate, sleep, weight, steps, etc.) into Apple Health.")
                permRow("arrow.down.heart.fill",
                        "Read access",
                        "Used only to detect records already in Apple Health so we can skip duplicates.")
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            if isRequesting {
                ProgressView("Requesting access…")
            } else {
                Button {
                    isRequesting = true
                    Task {
                        await vm.requestAuthorization()
                        isRequesting = false
                    }
                } label: {
                    Label("Continue", systemImage: "checkmark.shield.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button("Back") { vm.reset() }
                .foregroundStyle(.secondary)

            if let err = vm.lastError {
                Text(err.description)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding()
    }

    private func permRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
