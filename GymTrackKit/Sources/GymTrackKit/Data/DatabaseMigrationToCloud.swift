import Foundation

public enum DatabaseMigrationToCloud {
    /// Moves the database from legacy Application Support to the target URL
    /// if the legacy file exists and the target does not.
    ///
    /// Uses NSFileCoordinator for the write (required for ubiquity container).
    /// Cleans up WAL/SHM companion files.
    ///
    /// - Returns: `true` if migration succeeded or was not needed, `false` on failure.
    public static func migrateIfNeeded(to targetURL: URL) -> Bool {
        let legacyURL = DatabaseLocation.legacyURL()
        let fm = FileManager.default

        guard fm.fileExists(atPath: legacyURL.path) else {
            return true
        }
        guard !fm.fileExists(atPath: targetURL.path) else {
            return true
        }

        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var moveSucceeded = false

        coordinator.coordinate(
            writingItemAt: targetURL,
            options: .forReplacing,
            error: &coordinatorError
        ) { coordinatedURL in
            do {
                try fm.moveItem(at: legacyURL, to: coordinatedURL)
                moveSucceeded = true

                // Clean up WAL/SHM companion files from legacy location
                // These are named e.g. gymtrack.sqlite-wal, gymtrack.sqlite-shm
                for suffix in ["-wal", "-shm"] {
                    let companion = URL(fileURLWithPath: legacyURL.path + suffix)
                    try? fm.removeItem(at: companion)
                }
            } catch {
                print("[DatabaseMigrationToCloud] Move failed: \(error)")
            }
        }

        if let coordinatorError {
            print("[DatabaseMigrationToCloud] Coordinator error: \(coordinatorError)")
            return false
        }

        return moveSucceeded
    }
}
