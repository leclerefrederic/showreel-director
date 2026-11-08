import ShowreelKit
import SwiftUI

extension CheckLevel {
    var color: Color {
        switch self {
        case .ok: return .green
        case .tight: return .orange
        case .fail: return .red
        case .pending: return .gray
        }
    }
    var symbol: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .tight: return "exclamationmark.circle.fill"
        case .fail: return "xmark.octagon.fill"
        case .pending: return "circle.dashed"
        }
    }
}

/// The deterministic checks of a block, green or red, with the numbers behind them. No AI.
struct ChecksPanel: View {
    let block: String
    @EnvironmentObject var project: ProjectModel

    private var results: [CheckResult] { project.checks[block] ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Checks", systemImage: Checks.worst(results).symbol).foregroundStyle(Checks.worst(results).color).font(.headline)
                Text("no AI: the same answer every time").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(results) { r in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: r.level.symbol).foregroundStyle(r.level.color).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.title).font(.callout.weight(.medium))
                        Text(r.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
