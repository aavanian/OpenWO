import SwiftUI

struct StatsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Coming in a future update")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Session frequency, streaks, and more.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .navigationTitle("Stats")
        }
    }
}
