import SwiftUI

struct WorkoutFeedbackSheet: View {
    let defaultFeedback: WorkoutFeedback
    let onSave: (WorkoutFeedback) -> Void

    @State private var selected: WorkoutFeedback = .ok

    var body: some View {
        VStack(spacing: 24) {
            Text("How was this workout?")
                .font(.title3.bold())

            HStack(spacing: 16) {
                ForEach(WorkoutFeedback.allCases, id: \.self) { feedback in
                    Button {
                        selected = feedback
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: feedback.icon)
                                .font(.title2)
                            Text(feedback.displayLabel)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selected == feedback
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selected == feedback ? Color.accentColor : Color.secondary.opacity(0.3),
                                    lineWidth: selected == feedback ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                onSave(selected)
            } label: {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            selected = defaultFeedback
        }
    }
}
