import SwiftUI

struct ImportProgressView: View {
    @EnvironmentObject var vm: ImportViewModel
    @State private var showCancelConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            // Top progress bar
            VStack(alignment: .leading, spacing: 8) {
                ProgressBarRow(
                    label: "Files",
                    value: vm.progress.fileProgress,
                    subtitle: "\(vm.progress.filesCompleted) of \(vm.progress.filesTotal) — \(vm.progress.currentFileName)"
                )
                .padding()
            }
            .background(.regularMaterial)

            // Counters
            HStack(spacing: 0) {
                counter(vm.progress.parsed,           "Parsed",   Color.primary,                   "doc.text.magnifyingglass")
                counter(vm.progress.written,          "Written",  Color.green,                     "arrow.up.circle")
                counter(vm.progress.skippedDuplicate, "Skipped",  Color(.secondaryLabel),          "arrow.triangle.2.circlepath")
                counter(vm.progress.failed,           "Failed",   Color.red,                       "xmark.circle")
            }
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))

            Divider()

            // Log tail
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(vm.progress.logTail.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .id(idx)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: vm.progress.logTail.count) { _ in
                    if let last = vm.progress.logTail.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Cancel
            Button(role: .destructive) {
                showCancelConfirm = true
            } label: {
                Label("Cancel Import", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding()
            .confirmationDialog("Cancel the import?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                Button("Cancel Import", role: .destructive) { vm.cancelImport() }
                Button("Keep Running", role: .cancel) {}
            }
        }
        .navigationTitle("Importing…")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func counter(_ value: Int, _ label: String, _ color: Color, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text("\(value)").font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
