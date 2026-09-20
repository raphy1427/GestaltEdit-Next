import Foundation

struct BackupInspection {
    let isValid: Bool
    let format: String
    let topLevelKeyCount: Int
    let cacheExtraKeyCount: Int
    let byteCount: Int
    let message: String
}

enum GestaltBackupInspector {
    static func inspect(_ backup: GestaltBackup) -> BackupInspection {
        do {
            let data = try GestaltBackupStore.data(for: backup)
            var plistFormat = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &plistFormat
            ) as? [String: Any] else {
                return invalid(byteCount: data.count, message: "The backup is not a dictionary property list.")
            }

            guard let cacheExtra = dictionary["CacheExtra"] as? [String: Any] else {
                return invalid(byteCount: data.count, message: "The backup is missing the CacheExtra dictionary.")
            }

            return BackupInspection(
                isValid: true,
                format: formatName(plistFormat),
                topLevelKeyCount: dictionary.count,
                cacheExtraKeyCount: cacheExtra.count,
                byteCount: data.count,
                message: "Backup structure looks valid."
            )
        } catch {
            return invalid(byteCount: Int(backup.byteCount), message: error.localizedDescription)
        }
    }

    private static func invalid(byteCount: Int, message: String) -> BackupInspection {
        BackupInspection(
            isValid: false,
            format: "Unknown",
            topLevelKeyCount: 0,
            cacheExtraKeyCount: 0,
            byteCount: byteCount,
            message: message
        )
    }

    private static func formatName(_ format: PropertyListSerialization.PropertyListFormat) -> String {
        switch format {
        case .binary: return "Binary"
        case .xml: return "XML"
        case .openStep: return "OpenStep"
        @unknown default: return "Unknown"
        }
    }
}
