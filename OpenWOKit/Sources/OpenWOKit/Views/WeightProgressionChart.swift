import SwiftUI
import Charts

struct WeightProgressionChart: View {
    @ObservedObject var viewModel: StatsViewModel

    private struct DataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let weight: Double
    }

    private var dataPoints: [DataPoint] {
        viewModel.weightHistory.compactMap { entry in
            guard let date = DateHelpers.date(from: entry.date) else { return nil }
            return DataPoint(date: date, weight: entry.weight)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.availableExercises.isEmpty {
                    ContentUnavailableView(
                        "No exercises with weights",
                        systemImage: "dumbbell",
                        description: Text("Complete a workout with weights to see progression.")
                    )
                    .frame(height: 250)
                } else {
                    exercisePicker

                    if dataPoints.isEmpty {
                        ContentUnavailableView(
                            "No weight data",
                            systemImage: "scalemass",
                            description: Text("Log weights to see progression.")
                        )
                        .frame(height: 250)
                    } else {
                        Chart(dataPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Weight (kg)", point.weight)
                            )
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Weight (kg)", point.weight)
                            )
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { _ in
                                AxisGridLine()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        }
                        .frame(height: 250)
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var exercisePicker: some View {
        Picker("Exercise", selection: Binding(
            get: { viewModel.selectedExerciseId },
            set: { id in
                viewModel.selectedExerciseId = id
                viewModel.loadWeightHistory()
            }
        )) {
            ForEach(viewModel.availableExercises) { exercise in
                Text(exercise.name).tag(exercise.id)
            }
        }
        .pickerStyle(.menu)
    }
}
