import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var vm: ImportViewModel
    @State private var showPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Hero
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text("Huawei Health Importer")
                        .font(.largeTitle.bold())
                    Text("Import your Huawei Health export into Apple Health — fully offline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // Folder picker
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Export folder", systemImage: "folder")
                            .font(.headline)

                        if let url = vm.pickedFolder {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(url.lastPathComponent)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        } else {
                            Text("No folder selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Button("Choose Huawei Export Folder…") {
                            showPicker = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Calorie divisor control
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Calorie calibration", systemImage: "flame")
                            .font(.headline)
                        Text("Huawei stores calories in tenths of a kcal on most firmwares. Adjust if your totals look wrong.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Divisor: \(vm.calorieDivisor, specifier: "%.0f")")
                            Spacer()
                            Stepper("", value: $vm.calorieDivisor, in: 1...100, step: 1)
                                .labelsHidden()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // CTA
                Button {
                    vm.startImport()
                } label: {
                    Label("Start Import", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(vm.pickedFolder == nil)

                // Privacy note
                VStack(spacing: 4) {
                    Text("All processing is done on-device. No data leaves your phone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Link("About Huawei Privacy Center",
                         destination: URL(string: "https://consumer.huawei.com/en/privacy/")!)
                        .font(.caption)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showPicker) {
            DocumentPicker { url in
                vm.pickFolder(url)
                showPicker = false
            }
        }
    }
}
