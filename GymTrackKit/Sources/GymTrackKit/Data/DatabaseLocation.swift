import Foundation

public enum DatabaseLocation {
    static let fileName = "gymtrack.sqlite"

    /// Resolves the database URL, preferring iCloud container when available.
    /// - Parameters:
    ///   - ubiquityURL: The iCloud ubiquity container URL (nil when iCloud is unavailable)
    ///   - documentsDirectory: The app's Documents directory (visible in Files.app)
    public static func resolve(ubiquityURL: URL?, documentsDirectory: URL) -> URL {
        if let ubiquityURL {
            let docsDir = ubiquityURL.appendingPathComponent("Documents", isDirectory: true)
            try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
            return docsDir.appendingPathComponent(fileName)
        }
        try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)
        return documentsDirectory.appendingPathComponent(fileName)
    }

    /// The legacy database path in Application Support used before iCloud migration.
    public static func legacyURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("GymTrack", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
