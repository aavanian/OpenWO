import SwiftUI

struct ExerciseView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    let onFinish: () -> Void

    @State private var showPartialConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.exercises) { exercise in
                            ExerciseStepCard(
                                exercise: exercise,
                                isCompleted: viewModel.completedSteps.contains(exercise.id),
                                onComplete: {
                                    viewModel.markStepCompleted(exercise.id)
                                    Haptics.light()
                                }
                            )
                        }
                    }
                    .padding()
                }

                finishButton
            }
            .navigationTitle(viewModel.sessionType.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text(viewModel.sessionType.displayName)
                            .font(.headline)
                        Text(formatElapsedTime(viewModel.elapsedSeconds))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                viewModel.startTimer()
            }
            .alert("Log as partial session?", isPresented: $showPartialConfirmation) {
                Button("Yes") {
                    viewModel.finishWorkout()
                    Haptics.success()
                    onFinish()
                }
                Button("No", role: .cancel) {}
            } message: {
                Text("You've completed less than half the exercises.")
            }
        }
    }

    private var finishButton: some View {
        Button {
            if viewModel.isPartialSession {
                showPartialConfirmation = true
            } else {
                viewModel.finishWorkout()
                Haptics.success()
                onFinish()
            }
        } label: {
            Text("Finish workout")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }

    private func formatElapsedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
