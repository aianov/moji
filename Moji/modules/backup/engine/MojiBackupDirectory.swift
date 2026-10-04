import Foundation

enum MojiBackupDirectory {
    static func collect(_ directory: URL) throws -> [MojiBackupFile] {
        let manager = FileManager.default
        var isFolder: ObjCBool = false
        guard manager.fileExists(atPath: directory.path, isDirectory: &isFolder), isFolder.boolValue else {
            return []
        }

        var files: [MojiBackupFile] = []
        for path in try manager.subpathsOfDirectory(atPath: directory.path).sorted() {
            guard MojiBackupCodec.isSafeName(path) else { continue }
            let url = directory.appendingPathComponent(path, isDirectory: false)
            var isNested: ObjCBool = false
            guard manager.fileExists(atPath: url.path, isDirectory: &isNested), !isNested.boolValue else { continue }
            files.append(MojiBackupFile(name: path, contents: try Data(contentsOf: url)))
        }
        return files
    }

    static func replace(_ directory: URL, with files: [MojiBackupFile]) throws {
        let manager = FileManager.default
        let parent = directory.deletingLastPathComponent()
        let staging = parent.appendingPathComponent("\(directory.lastPathComponent).incoming", isDirectory: true)
        let retired = parent.appendingPathComponent("\(directory.lastPathComponent).replaced", isDirectory: true)
        let hadDirectory = manager.fileExists(atPath: directory.path)

        try? manager.removeItem(at: staging)
        if hadDirectory {
            try? manager.removeItem(at: retired)
        }

        do {
            try manager.createDirectory(at: staging, withIntermediateDirectories: true)
            for file in files {
                let target = staging.appendingPathComponent(file.name, isDirectory: false)
                try manager.createDirectory(
                    at: target.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try file.contents.write(
                    to: target,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
            }
            if hadDirectory {
                try manager.moveItem(at: directory, to: retired)
            }
            do {
                try manager.moveItem(at: staging, to: directory)
            } catch {
                if hadDirectory {
                    try? manager.moveItem(at: retired, to: directory)
                }
                throw error
            }
        } catch {
            try? manager.removeItem(at: staging)
            throw MojiBackupError.writeFailed
        }

        if hadDirectory {
            try? manager.removeItem(at: retired)
        }
    }
}
