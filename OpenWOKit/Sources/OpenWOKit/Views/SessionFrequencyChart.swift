import SwiftUI
import Charts

struct SessionFrequencyChart: View {
    @ObservedObject var viewModel: StatsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Granularity", selection: Binding(
                    get: { viewModel.granularity },
                    set: { granularity in
                        viewModel.granularity = granularity
                        viewModel.loadSessionFrequency()
                    }
                )) {
                    Text("Weekly").tag(Granularity.weekly)
                    Text("Monthly").tag(Granularity.monthly)
                }
                .pickerStyle(.segmented)

                if viewModel.sessionCounts.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("Complete workouts to see frequency.")
                    )
                    .frame(height: 250)
                } else {
                    Chart(viewModel.sessionCounts) { bucket in
                        BarMark(
                            x: .value("Period", bucket.label),
                            y: .value("Sessions", bucket.count)
                        )
                        .foregroundStyle(barColor(for: bucket.dominantType))
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.caption2)
                        }
                    }
                    .frame(height: 250)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func barColor(for type: SessionType?) -> Color {
        switch type {
        case .a: return .blue
        case .b: return .green
        case .c: return .orange
        case nil: return .gray
        }
    }
}
