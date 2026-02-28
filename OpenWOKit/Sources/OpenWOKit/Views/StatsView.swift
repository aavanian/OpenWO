import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: StatsViewModel
    @AppStorage("statsActiveSection") private var activeSection: StatsSection = .weightProgression

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $activeSection) {
                    Text("Weight").tag(StatsSection.weightProgression)
                    Text("Frequency").tag(StatsSection.sessionFrequency)
                    Text("Bests").tag(StatsSection.personalBests)
                    Text("Challenge").tag(StatsSection.challengeHeatmap)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                Group {
                    switch activeSection {
                    case .weightProgression:
                        WeightProgressionChart(viewModel: viewModel)
                    case .sessionFrequency:
                        SessionFrequencyChart(viewModel: viewModel)
                    case .personalBests:
                        StatsSummarySection(viewModel: viewModel)
                    case .challengeHeatmap:
                        ChallengeHeatmap(viewModel: viewModel)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Stats")
        }
    }
}
