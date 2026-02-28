import SwiftUI

struct StatsSummarySection: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let bests = viewModel.personalBests {
                    if let lift = bests.heaviestLift {
                        BestCard(
                            title: "Heaviest Lift",
                            value: String(format: "%.1f kg", lift.weight),
                            subtitle: lift.exercise,
                            systemImage: "dumbbell.fill"
                        )
                    }

                    BestCard(
                        title: "Longest Gym Streak",
                        value: "\(bests.longestSessionStreak) days",
                        subtitle: "Consecutive workout days",
                        systemImage: "flame.fill"
                    )

                    BestCard(
                        title: "Longest Challenge Streak",
                        value: "\(bests.longestChallengeStreak) days",
                        subtitle: "Consecutive challenge days",
                        systemImage: "star.fill"
                    )

                    BestCard(
                        title: "Best Week",
                        value: "\(bests.mostSessionsInWeek) sessions",
                        subtitle: "Most sessions in a week",
                        systemImage: "calendar"
                    )
                } else {
                    ContentUnavailableView(
                        "No data yet",
                        systemImage: "trophy",
                        description: Text("Complete workouts to unlock personal bests.")
                    )
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct BestCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .background(Color.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
