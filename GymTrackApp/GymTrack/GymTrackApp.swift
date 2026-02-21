import SwiftUI
import GymTrackKit

@main
struct GymTrackApp: App {
    let database: AppDatabase

    init() {
        do {
            let url = Self.databaseURL()
            let dbQueue = try GRDB.DatabaseQueue(path: url.path)
            database = try AppDatabase(dbQueue)
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(database: database)
        }
    }

    private static func databaseURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("GymTrack", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("gymtrack.sqlite")
    }
}
