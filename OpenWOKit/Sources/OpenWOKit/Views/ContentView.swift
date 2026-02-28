import SwiftUI

public struct ContentView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    @ObservedObject var statsViewModel: StatsViewModel
    @State private var selectedTab: Int = 0
    let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
        self.homeViewModel = HomeViewModel(database: database)
        self.statsViewModel = StatsViewModel(database: database)
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel, database: database)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            StatsView(viewModel: statsViewModel)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(1)
        }
        .onAppear {
            homeViewModel.refresh()
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == 1 { statsViewModel.refresh() }
        }
    }
}
