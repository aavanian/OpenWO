import SwiftUI

struct ExerciseStepCard: View {
    let exercise: Exercise
    let isCompleted: Bool
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .strikethrough(isCompleted)
                Spacer()
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if !exercise.instruction.isEmpty {
                Text(exercise.instruction)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                exerciseControls

                Spacer()

                if !isCompleted && exercise.sets == nil && !exercise.isTimed {
                    Button("Done") {
                        onComplete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.secondaryGroupedBackground)
        .opacity(isCompleted ? 0.6 : 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var exerciseControls: some View {
        if let sets = exercise.sets {
            if exercise.isTimed {
                // Timed exercise with sets (e.g. Plank: 2 sets × 30-45 sec)
                VStack(alignment: .leading, spacing: 6) {
                    TimerView(label: exercise.reps)
                    SetTracker(totalSets: sets, onAllCompleted: onComplete)
                }
            } else {
                SetTracker(totalSets: sets, onAllCompleted: onComplete)
            }
        } else if exercise.isTimed {
            // Pure timed exercise (e.g. Cardio warm-up: 10 min)
            VStack(alignment: .leading, spacing: 6) {
                TimerView(label: exercise.reps)
                Button("Done") {
                    onComplete()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } else {
            Text(exercise.reps)
                .font(.subheadline)
        }
    }
}
