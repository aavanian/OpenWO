import SwiftUI
import GymTrackKit

@main
struct GymTrackApp: App {
    let database: AppDatabase

    init() {
        do {
            let url = Self.resolveAndMigrate()
            var config = GRDB.Configuration()
            config.prepareDatabase { db in
                try db.execute(sql: "PRAGMA journal_mode = DELETE")
            }
            let dbQueue = try Self.openWithCoordination(path: url.path, configuration: config)
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

    private static func resolveAndMigrate() -> URL {
        let fm = FileManager.default
        let ubiquityURL = fm.url(
            forUbiquityContainerIdentifier: "iCloud.com.avanian.gymtrack"
        )
        let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let targetURL = DatabaseLocation.resolve(
            ubiquityURL: ubiquityURL,
            documentsDirectory: documentsDir
        )

        if DatabaseMigrationToCloud.migrateIfNeeded(to: targetURL) {
            return targetURL
        }

        // Migration failed — fall back to legacy path if it still exists
        let legacyURL = DatabaseLocation.legacyURL()
        if fm.fileExists(atPath: legacyURL.path) {
            return legacyURL
        }

        // Fresh install — use target
        return targetURL
    }

    /// Opens a DatabaseQueue using NSFileCoordinator to prevent iCloud from
    /// replacing the file mid-open.
    private static func openWithCoordination(
        path: String,
        configuration: GRDB.Configuration
    ) throws -> GRDB.DatabaseQueue {
        let url = URL(fileURLWithPath: path)
        var coordinatorError: NSError?
        var result: Result<GRDB.DatabaseQueue, Error>?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(
            readingItemAt: url,
            options: [],
            error: &coordinatorError
        ) { coordinatedURL in
            do {
                let dbQueue = try GRDB.DatabaseQueue(
                    path: coordinatedURL.path,
                    configuration: configuration
                )
                result = .success(dbQueue)
            } catch {
                result = .failure(error)
            }
        }

        if let coordinatorError {
            throw coordinatorError
        }

        switch result {
        case .success(let dbQueue):
            return dbQueue
        case .failure(let error):
            throw error
        case .none:
            throw DatabaseError(message: "File coordination completed without result")
        }
    }
}
