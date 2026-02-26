import SwiftUI

struct ExerciseStepCard: View {
    let exercise: Exercise
    let isCompleted: Bool
    let isExpanded: Bool
    let logEntry: ExerciseLogEntry?
    let onComplete: () -> Void
    let onWeightChanged: (Double?) -> Void
    let onFailed: (Int?) -> Void
    let onClearFailure: () -> Void
    let onTap: () -> Void

    @State private var weightText: String = ""
    @State private var showFailedInput: Bool = false
    @State private var achievedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .strikethrough(isCompleted)
                Spacer()
                if let entry = logEntry, entry.failed {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.orange)
                }
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isExpanded {
                if !exercise.instruction.isEmpty {
                    Text(exercise.instruction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    exerciseControls

                    Spacer()

                    if !isCompleted && exercise.sets == nil {
                        Button("Done") {
                            onComplete()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if exercise.hasWeight || !isCompleted {
                    exerciseLogControls
                }
            }
        }
        .padding()
        .background(Color.secondaryGroupedBackground)
        .opacity(isCompleted ? 0.6 : 1.0)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            if let weight = logEntry?.weight {
                weightText = formatWeight(weight)
            }
            showFailedInput = logEntry?.failed ?? false
            if let achieved = logEntry?.achievedValue {
                if exercise.timerDisplaysMinutes {
                    let minutes = Double(achieved) / 60.0
                    achievedText = formatWeight(minutes)
                } else {
                    achievedText = "\(achieved)"
                }
            }
        }
    }

    @ViewBuilder
    private var exerciseControls: some View {
        if let sets = exercise.sets {
            if exercise.isTimed {
                HStack {
                    TimerView(label: exercise.reps, stopped: isCompleted)
                    Spacer()
                    SetTracker(totalSets: sets, onAllCompleted: onComplete)
                }
            } else {
                HStack {
                    Text(exercise.reps)
                        .font(.subheadline)
                    Spacer()
                    SetTracker(totalSets: sets, onAllCompleted: onComplete)
                }
            }
        } else if exercise.isTimed {
            TimerView(label: exercise.reps, stopped: isCompleted)
        } else {
            Text(exercise.reps)
                .font(.subheadline)
        }
    }

    @ViewBuilder
    private var exerciseLogControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            if exercise.hasWeight {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("kg", text: $weightText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        #endif
                        .frame(width: 70)
                        .onChange(of: weightText) { newValue in
                            onWeightChanged(Double(newValue))
                        }
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !isCompleted {
                HStack(spacing: 6) {
                    Button {
                        showFailedInput.toggle()
                        if showFailedInput {
                            onFailed(nil)
                        } else {
                            achievedText = ""
                            onClearFailure()
                        }
                    } label: {
                        Label(
                            showFailedInput ? "Failed" : "Mark failed",
                            systemImage: showFailedInput ? "xmark.circle.fill" : "xmark.circle"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(showFailedInput ? .orange : .secondary)

                    if showFailedInput {
                        TextField(achievedPlaceholder, text: $achievedText)
                            #if os(iOS)
                            .keyboardType(exercise.timerDisplaysMinutes ? .decimalPad : .numberPad)
                            .textFieldStyle(.roundedBorder)
                            #endif
                            .frame(width: 60)
                            .controlSize(.small)
                            .onChange(of: achievedText) { newValue in
                                onFailed(achievedValueInSeconds(newValue))
                            }
                        Text(achievedUnitLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var achievedPlaceholder: String {
        if exercise.timerDisplaysMinutes { return "min" }
        if exercise.isTimed { return "sec" }
        return "reps"
    }

    private var achievedUnitLabel: String {
        if exercise.timerDisplaysMinutes { return "min reached" }
        if exercise.isTimed { return "sec reached" }
        return "reps reached"
    }

    /// Convert the text input to seconds for storage.
    /// Minute-display exercises accept decimal minutes (e.g., "7.5" → 450 sec).
    private func achievedValueInSeconds(_ text: String) -> Int? {
        if exercise.timerDisplaysMinutes {
            guard let minutes = Double(text) else { return nil }
            return Int((minutes * 60).rounded())
        }
        return Int(text)
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weight)
            : String(format: "%.1f", weight)
    }
}
