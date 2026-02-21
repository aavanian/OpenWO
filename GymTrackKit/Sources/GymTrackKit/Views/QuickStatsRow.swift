import SwiftUI

struct QuickStatsRow: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        HStack {
            statItem(label: "This week", value: "\(viewModel.sessionsThisWeek)")
            Spacer()
            statItem(label: "This month", value: "\(viewModel.sessionsThisMonth)")
            Spacer()
            lastSessionItem
        }
        .padding()
        .background(Color.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var lastSessionItem: some View {
        VStack(spacing: 2) {
            if let last = viewModel.lastSession, let type = last.type {
                Text(type.shortLabel)
                    .font(.title3.bold())
                Text(last.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.title3.bold())
                Text("Last session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
