import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    let database: AppDatabase

    @State private var selectedSession: SessionType?
    @State private var activeWorkout: SessionType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakHeader
                    workoutButtons
                    DailyChallengeCard(viewModel: viewModel)
                    QuickStatsRow(viewModel: viewModel)
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
                    viewModel: ExerciseViewModel(database: database, sessionType: sessionType),
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
