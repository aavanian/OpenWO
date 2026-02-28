import SwiftUI

struct ChallengeHeatmap: View {
    @ObservedObject var viewModel: StatsViewModel
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private let rows: [GridItem] = Array(repeating: GridItem(.fixed(14), spacing: 2), count: 7)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Year", selection: $selectedYear) {
                    ForEach(yearRange, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)

                legend

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, alignment: .top, spacing: 2) {
                        ForEach(gridCells, id: \.index) { cell in
                            cell.color
                                .frame(width: 14, height: 14)
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.loadChallengeHeatmap(year: selectedYear)
        }
        .onChange(of: selectedYear) { _, year in
            viewModel.loadChallengeHeatmap(year: year)
        }
    }

    private var yearRange: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 2)...current)
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach([0, 1, 2, 3], id: \.self) { sets in
                cellColor(for: sets)
                    .frame(width: 14, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private struct GridCell {
        let index: Int
        let color: Color
    }

    private var gridCells: [GridCell] {
        let cal = Calendar.current
        var comps = DateComponents(year: selectedYear, month: 1, day: 1)
        guard let jan1 = cal.date(from: comps) else { return [] }

        // Offset to the Monday of the week containing Jan 1 (weekday: 1=Sun, 2=Mon, …, 7=Sat)
        let weekday = cal.component(.weekday, from: jan1)
        let daysBack = weekday == 1 ? 6 : weekday - 2
        let startDate = cal.date(byAdding: .day, value: -daysBack, to: jan1)!

        // End at the Sunday of the week containing Dec 31
        comps = DateComponents(year: selectedYear, month: 12, day: 31)
        let dec31 = cal.date(from: comps)!
        let endWeekday = cal.component(.weekday, from: dec31)
        let daysForward = endWeekday == 1 ? 0 : 7 - (endWeekday - 1)
        let endDate = cal.date(byAdding: .day, value: daysForward, to: dec31)!

        var cells: [GridCell] = []
        var current = startDate
        var index = 0

        while current <= endDate {
            let inYear = cal.component(.year, from: current) == selectedYear
            let dateStr = DateHelpers.dateString(from: current)
            let sets = inYear ? (viewModel.challengeGrid[dateStr] ?? 0) : -1
            cells.append(GridCell(index: index, color: sets < 0 ? .clear : cellColor(for: sets)))
            index += 1
            current = cal.date(byAdding: .day, value: 1, to: current)!
        }

        return cells
    }

    private func cellColor(for sets: Int) -> Color {
        switch sets {
        case 0: return Color.gray.opacity(0.15)
        case 1: return Color.green.opacity(0.35)
        case 2: return Color.green.opacity(0.65)
        default: return .green
        }
    }
}
