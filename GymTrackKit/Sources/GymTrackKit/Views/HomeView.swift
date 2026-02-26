import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let database: AppDatabase

    #if os(iOS)
    private let healthKitManager: HealthKitManaging = HealthKitManager()
    #endif

    @State private var selectedSession: SessionType?
    @State private var activeWorkout: SessionType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakHeader
                    workoutButtons
                    statsCard
                }
                .padding()
            }
            .navigationTitle("GymTrack")
            .sheet(item: $selectedSession) { sessionType in
                ConfirmationSheet(
                    sessionType: sessionType,
                    onConfirm: {
                        selectedSession = nil
                        activeWorkout = sessionType
                    },
                    onCancel: {
                        selectedSession = nil
                    }
                )
                .presentationDetents([.medium])
            }
            #if os(iOS)
            .fullScreenCover(item: $activeWorkout) { sessionType in
                ExerciseView(
                    viewModel: ExerciseViewModel(
                        database: database,
                        sessionType: sessionType,
                        healthKitManager: healthKitManager
                    ),
                    onFinish: {
                        activeWorkout = nil
                        viewModel.refresh()
                    }
                )
            }
            #else
            .sheet(item: $activeWorkout) { sessionType in
                ExerciseView(
                    viewModel: ExerciseViewModel(database: database, sessionType: sessionType),
                    onFinish: {
                        activeWorkout = nil
                        viewModel.refresh()
                    }
                )
            }
            #endif
        }
    }

    private var streakHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundStyle(viewModel.gymStreak > 0 ? .orange : .gray)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.gymStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text(viewModel.gymStreak == 0
                     ? "Start your streak today!"
                     : "\(viewModel.gymStreak)-day streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statsCard: some View {
        VStack(spacing: 0) {
            DailyChallengeCard(viewModel: viewModel)
            Divider().padding(.horizontal)
            Grid(alignment: .top) {
                GridRow {
                    statCell(label: "Streak", value: "\(viewModel.challengeStreak)d")
                    statCell(label: "Past 365d", value: "\(viewModel.challengeDaysPast365)")
                    statCell(label: "YTD", value: "\(viewModel.challengeDaysYTD)")
                }
                Divider()
                GridRow {
                    statCell(label: "This week", value: "\(viewModel.sessionsThisWeek)")
                    statCell(label: "This month", value: "\(viewModel.sessionsThisMonth)")
                    lastSessionCell
                }
            }
            .padding()
        }
        .background(Color.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var lastSessionCell: some View {
        VStack(spacing: 2) {
            if let last = viewModel.lastSession, let type = last.type {
                Text(type.shortLabel)
                    .font(.subheadline.bold())
                Text(last.date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.subheadline.bold())
                Text("Last session")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var workoutButtons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(SessionType.allCases, id: \.self) { type in
                WorkoutCard(
                    sessionType: type,
                    isNext: type == viewModel.nextSessionType
                ) {
                    selectedSession = type
                }
            }
        }
    }
}

extension SessionType: Identifiable {
    public var id: String { rawValue }
}
