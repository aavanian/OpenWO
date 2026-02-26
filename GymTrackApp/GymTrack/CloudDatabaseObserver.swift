import Foundation
import os

/// Watches the iCloud Documents container for database file updates using NSMetadataQuery.
///
/// When iCloud replaces the database file via atomic rename, the open GRDB file descriptor
/// points to the old inode. A full reload (dealloc old DatabaseQueue, create new one) is
/// required to see the updated data. For now, this observer logs the event; the user can
/// relaunch the app to pick up remote changes.
final class CloudDatabaseObserver {
    private let query = NSMetadataQuery()
    private let logger = Logger(subsystem: "com.avanian.gymtrack", category: "iCloudSync")

    init(ubiquityURL: URL) {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@",
                                      NSMetadataItemFSNameKey,
                                      "gymtrack.sqlite")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        query.start()
    }

    deinit {
        query.stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        query.disableUpdates()
        defer { query.enableUpdates() }

        guard query.resultCount > 0,
              let item = query.result(at: 0) as? NSMetadataItem else { return }

        let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        logger.info("iCloud database update detected — download status: \(status ?? "unknown", privacy: .public)")
    }
}
