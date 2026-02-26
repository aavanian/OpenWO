import SwiftUI

struct ExerciseView: View {
    @ObservedObject var viewModel: ExerciseViewModel
    let onFinish: () -> Void

    @State private var showPartialConfirmation = false
    @State private var showAbortConfirmation = false
    @State private var showFeedbackSheet = false
    @State private var expandedExerciseId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.exercises) { exercise in
                                ExerciseStepCard(
                                    exercise: exercise,
                                    isCompleted: viewModel.completedSteps.contains(exercise.id),
                                    isExpanded: exercise.id == expandedExerciseId,
                                    logEntry: viewModel.exerciseLogs[exercise.id],
                                    onComplete: {
                                        viewModel.markStepCompleted(exercise.id)
                                        Haptics.light()
                                    },
                                    onWeightChanged: { weight in
                                        viewModel.setWeight(exercise.id, weight: weight)
                                    },
                                    onFailed: { achieved in
                                        viewModel.markFailed(exercise.id, achievedValue: achieved)
                                    },
                                    onClearFailure: {
                                        viewModel.clearFailure(exercise.id)
                                    },
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            expandedExerciseId = exercise.id
                                        }
                                    }
                                )
                                .id(exercise.id)
                            }
                        }
                        .padding()
                    }
                    #if os(iOS)
                    .scrollDismissesKeyboard(.interactively)
                    #endif
                    .onChange(of: viewModel.completedSteps) { _ in
                        let nextIncomplete = viewModel.exercises.first {
                            !viewModel.completedSteps.contains($0.id)
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedExerciseId = nextIncomplete?.id
                            if let nextId = nextIncomplete?.id {
                                proxy.scrollTo(nextId, anchor: .top)
                            }
                        }
                    }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abort", role: .destructive) {
                        showAbortConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .onAppear {
                viewModel.startTimer()
                expandedExerciseId = viewModel.exercises.first {
                    !viewModel.completedSteps.contains($0.id)
                }?.id
            }
            .alert("Log as partial session?", isPresented: $showPartialConfirmation) {
                Button("Yes") {
                    showFeedbackSheet = true
                }
                Button("No", role: .cancel) {}
            } message: {
                Text("You've completed less than half the exercises.")
            }
            .alert("Abort workout?", isPresented: $showAbortConfirmation) {
                Button("Abort", role: .destructive) {
                    viewModel.abortWorkout()
                    onFinish()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This workout will not be saved.")
            }
            .sheet(isPresented: $showFeedbackSheet) {
                WorkoutFeedbackSheet(defaultFeedback: viewModel.defaultFeedback) { feedback in
                    showFeedbackSheet = false
                    viewModel.finishWorkout(feedback: feedback)
                    Haptics.success()
                    onFinish()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var finishButton: some View {
        Button {
            if viewModel.isPartialSession {
                showPartialConfirmation = true
            } else {
                showFeedbackSheet = true
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
