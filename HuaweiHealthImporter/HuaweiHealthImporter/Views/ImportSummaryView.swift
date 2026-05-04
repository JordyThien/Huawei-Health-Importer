import SwiftUI

struct ImportSummaryView: View {
    @EnvironmentObject var vm: ImportViewModel
    @State private var showShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Import Complete")
                        .font(.title.bold())
                    if let s = vm.summary {
                        Text(String(format: "Finished in %.1f seconds", s.elapsedSeconds))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 20)

                // Per-type stats
                if let s = vm.summary, !s.statsByType.isEmpty {
                    GroupBox("Results by Type") {
                        VStack(spacing: 0) {
                            ForEach(Array(s.statsByType.values).sorted(by: { $0.typeName < $1.typeName }), id: \.typeName) { stats in
                                StatRow(
                                    typeName: stats.typeName,
                                    written: stats.written,
                                    skipped: stats.skippedDuplicate,
                                    failed: stats.failed
                                )
                                Divider()
                            }
                        }
                    }
                }

                // Total counters
                GroupBox("Totals") {
                    HStack(spacing: 0) {
                        totalCell(vm.progress.written,          "Written",  Color.green)
                        totalCell(vm.progress.skippedDuplicate, "Skipped",  Color(.secondaryLabel))
                        totalCell(vm.progress.failed,           "Failed",   Color.red)
                    }
                }

                // Errors (if any)
                if let s = vm.summary, !s.errors.isEmpty {
                    GroupBox("Errors") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(s.errors.prefix(20), id: \.self) { err in
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            if s.errors.count > 20 {
                                Text("…and \(s.errors.count - 20) more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Actions
                HStack(spacing: 12) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Export Log", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        vm.reset()
                    } label: {
                        Label("Done", systemImage: "house")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 20)
            }
            .padding()
        }
        .navigationTitle("Summary")
        .sheet(isPresented: $showShareSheet) {
            let log = vm.exportLog()
            ActivityView(activityItems: [log])
        }
    }

    private func totalCell(_ value: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title2.bold().monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - UIActivityViewController wrapper

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
