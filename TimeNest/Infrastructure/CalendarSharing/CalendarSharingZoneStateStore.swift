import CloudKit
import CryptoKit
import Foundation

enum CalendarSharingDatabaseScope: String, Codable {
    case ownedPrivate
    case receivedShared
}

struct CalendarSharingPersistedZoneState {
    let records: SharedZoneRecordCollection
    let changeToken: CKServerChangeToken?
}

/// Persists a zone's materialized CKRecord collection together with its server change token.
/// Keeping both values atomic prevents applying an incremental response to an empty cache.
struct CalendarSharingZoneStateStore {
    private struct Archive: Codable {
        let records: [Data]
        let changeToken: Data?
    }

    let directoryURL: URL

    init(directoryURL: URL = Self.defaultDirectoryURL()) {
        self.directoryURL = directoryURL
    }

    func load(
        scope: CalendarSharingDatabaseScope,
        zoneID: CKRecordZone.ID
    ) -> CalendarSharingPersistedZoneState? {
        let url = fileURL(scope: scope, zoneID: zoneID)
        guard let data = try? Data(contentsOf: url),
              let archive = try? JSONDecoder().decode(Archive.self, from: data) else {
            return nil
        }
        let records = archive.records.compactMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: $0)
        }
        guard records.count == archive.records.count else { return nil }

        let token: CKServerChangeToken?
        if let tokenData = archive.changeToken {
            token = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: CKServerChangeToken.self,
                from: tokenData
            )
        } else {
            token = nil
        }
        var collection = SharedZoneRecordCollection()
        collection.apply(records)
        return CalendarSharingPersistedZoneState(
            records: collection,
            changeToken: token
        )
    }

    func save(
        _ state: CalendarSharingPersistedZoneState,
        scope: CalendarSharingDatabaseScope,
        zoneID: CKRecordZone.ID
    ) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let recordData = try state.records.allRecords.map {
            try NSKeyedArchiver.archivedData(
                withRootObject: $0,
                requiringSecureCoding: true
            )
        }
        let tokenData = try state.changeToken.map {
            try NSKeyedArchiver.archivedData(
                withRootObject: $0,
                requiringSecureCoding: true
            )
        }
        let data = try JSONEncoder().encode(
            Archive(records: recordData, changeToken: tokenData)
        )
        try data.write(to: fileURL(scope: scope, zoneID: zoneID), options: .atomic)
    }

    func remove(
        scope: CalendarSharingDatabaseScope,
        zoneID: CKRecordZone.ID
    ) {
        try? FileManager.default.removeItem(at: fileURL(scope: scope, zoneID: zoneID))
    }

    static func defaultDirectoryURL(fileManager: FileManager = .default) -> URL {
        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("TimeNestCalendarSharing", isDirectory: true)
            .appendingPathComponent("ZoneState", isDirectory: true)
    }

    private func fileURL(
        scope: CalendarSharingDatabaseScope,
        zoneID: CKRecordZone.ID
    ) -> URL {
        let rawKey = "\(scope.rawValue)|\(zoneID.ownerName)|\(zoneID.zoneName)"
        let digest = SHA256.hash(data: Data(rawKey.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directoryURL.appendingPathComponent("\(digest).json", isDirectory: false)
    }
}
