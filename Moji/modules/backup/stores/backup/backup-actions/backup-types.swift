import Foundation

enum BackupActivity: Equatable {
    case exporting
    case reading
    case importing
    case undoing
}

enum BackupFailure: Equatable {
    case export
    case importing(MojiBackupError)
    case undo(MojiBackupError)

    var title: String {
        switch self {
        case .export: String(localized: "Can't export")
        case .importing: String(localized: "Can't import")
        case .undo: String(localized: "Can't undo the import")
        }
    }

    var message: String {
        switch self {
        case .export:
            return String(localized: "Couldn't save the file. Try again.")
        case .importing(.notBackup):
            return String(localized: "This file isn't a Moji backup. Nothing was changed.")
        case .importing(.damaged):
            return String(localized: "This backup is damaged or incomplete. Nothing was changed.")
        case .importing(.newerVersion):
            return String(localized: "This backup was made by a newer version of Moji. Update the app and try again.")
        case .importing(.unreadable):
            return String(localized: "Couldn't open the file. Nothing was changed.")
        case .importing:
            return String(localized: "Couldn't write the data. Nothing was changed.")
        case .undo(.noSafetyCopy), .undo(.damaged):
            return String(localized: "The data from before the import is gone, so there is nothing to bring back.")
        case .undo:
            return String(localized: "Couldn't bring back the earlier data. Nothing was changed.")
        }
    }
}
