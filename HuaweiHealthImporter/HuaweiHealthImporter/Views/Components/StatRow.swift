import SwiftUI

/// A single row showing per-type import counts.
/// Example: "Heart Rate · 24,217 written · 0 skipped · 0 failed"
struct StatRow: View {
    let typeName: String
    let written: Int
    let skipped: Int
    let failed: Int

    private static let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private func formatted(_ n: Int) -> String {
        Self.fmt.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(typeName)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                statLabel(formatted(written), icon: "arrow.up.circle.fill", color: .green)
                statLabel(formatted(skipped), icon: "arrow.triangle.2.circlepath", color: Color(.secondaryLabel))
                if failed > 0 {
                    statLabel(formatted(failed), icon: "xmark.circle.fill", color: .red)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func statLabel(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .foregroundStyle(color)
    }
}
