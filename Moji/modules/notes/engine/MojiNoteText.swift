import Foundation

enum MojiNoteText {
    static let folderNameLimit = 40
    static let lineLimit = 200

    static func isBlank(_ text: String) -> Bool {
        text.allSatisfy(\.isWhitespace)
    }

    static func isBlank(title: String, body: String) -> Bool {
        isBlank(title) && isBlank(body)
    }

    static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func folderName(_ raw: String) -> String? {
        let line = singleLine(raw)
        guard !line.isEmpty else { return nil }
        return String(line.prefix(folderNameLimit)).trimmingCharacters(in: .whitespaces)
    }

    static func heading(title: String, body: String) -> String? {
        let line = singleLine(title)
        if !line.isEmpty {
            return String(line.prefix(lineLimit))
        }
        return lines(of: body, limit: 1).first
    }

    static func preview(title: String, body: String) -> String? {
        let titleIsBlank = singleLine(title).isEmpty
        let found = lines(of: body, limit: titleIsBlank ? 2 : 1)
        return titleIsBlank ? found.dropFirst().first : found.first
    }

    static func lines(of text: String, limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        var found: [String] = []
        text.enumerateLines { line, stop in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                found.append(String(trimmed.prefix(lineLimit)))
            }
            if found.count >= limit {
                stop = true
            }
        }
        return found
    }

    static func counts(_ text: String) -> MojiNoteCounts {
        var words = 0
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.byWords, .substringNotRequired]
        ) { _, _, _, _ in
            words += 1
        }
        let characters = text.reduce(into: 0) { count, character in
            if !character.isNewline {
                count += 1
            }
        }
        return MojiNoteCounts(words: words, characters: characters)
    }
}

enum MojiNoteOrder {
    static func sorted(_ notes: some Sequence<MojiNote>) -> [MojiNote] {
        notes.sorted(by: precedes)
    }

    static func precedes(_ lhs: MojiNote, _ rhs: MojiNote) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id < rhs.id
    }

    static func reordered(_ folders: [MojiNoteFolder], by ids: [String]) -> [MojiNoteFolder] {
        var remaining = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [MojiNoteFolder] = []
        for id in ids {
            if let folder = remaining.removeValue(forKey: id) {
                result.append(folder)
            }
        }
        for folder in folders {
            if remaining.removeValue(forKey: folder.id) != nil {
                result.append(folder)
            }
        }
        return result
    }

    static func moved<Element>(_ items: [Element], from source: IndexSet, to destination: Int) -> [Element] {
        let moving = source.filter { items.indices.contains($0) }.map { items[$0] }
        var result: [Element] = []
        var inserted = false
        for (index, item) in items.enumerated() {
            if index == destination {
                result.append(contentsOf: moving)
                inserted = true
            }
            if !source.contains(index) {
                result.append(item)
            }
        }
        if !inserted {
            result.append(contentsOf: moving)
        }
        return result
    }

    static func shifted(_ ids: [String], moving id: String, by offset: Int) -> [String] {
        guard let index = ids.firstIndex(of: id) else { return ids }
        let target = min(ids.count - 1, max(0, index + offset))
        guard target != index else { return ids }
        var result = ids
        result.remove(at: index)
        result.insert(id, at: target)
        return result
    }
}
