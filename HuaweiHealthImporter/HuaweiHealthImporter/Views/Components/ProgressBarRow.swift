import SwiftUI

/// A labelled linear progress bar.
struct ProgressBarRow: View {
    let label: String
    let value: Double   // 0.0–1.0
    let subtitle: String?

    init(label: String, value: Double, subtitle: String? = nil) {
        self.label    = label
        self.value    = value
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("\(Int(value * 100))%").font(.caption).foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(value, 0), 1))
                .tint(.accentColor)
            if let sub = subtitle {
                Text(sub).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
