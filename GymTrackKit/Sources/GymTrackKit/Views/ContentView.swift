import SwiftUI

public struct ContentView: View {
    @ObservedObject var homeViewModel: HomeViewModel
    let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
        self.homeViewModel = HomeViewModel(database: database)
    }

    public var body: some View {
        TabView {
            HomeView(viewModel: homeViewModel, database: database)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
        }
        .onAppear {
            homeViewModel.refresh()
        }
    }
}
