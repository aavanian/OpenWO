import SwiftUI

struct DailyChallengeCard: View {
    @ObservedObject var viewModel: HomeViewModel

    @State private var showCorrectionMenu = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Challenge")
                .font(.headline)

            Text("30 squats + 30 push-ups (3 sets of 10)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Sets counter
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.challengeSetsToday ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if index < viewModel.challengeSetsToday {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }

                Spacer()

                Text("\(viewModel.challengeSetsToday) / 3")
                    .font(.title3.bold())
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.challengeSetsToday < 3 {
                    viewModel.incrementChallenge()
                    Haptics.medium()
                }
            }
            .onLongPressGesture {
                showCorrectionMenu = true
            }
            .confirmationDialog("Set completed sets", isPresented: $showCorrectionMenu) {
                ForEach(0...3, id: \.self) { count in
                    Button("\(count) sets") {
                        viewModel.setChallenge(sets: count)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            Divider()

            HStack {
                statItem(label: "Streak", value: "\(viewModel.challengeStreak)d")
                Spacer()
                statItem(label: "Past 365d", value: "\(viewModel.challengeDaysPast365)")
                Spacer()
                statItem(label: "YTD", value: "\(viewModel.challengeDaysYTD)")
            }
        }
        .padding()
        .background(Color.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
