import Foundation

struct MojiNoteSearchHit: Equatable, Identifiable, Sendable {
    let note: MojiNote
    let snippet: String?

    var id: String { note.id }
}

struct MojiNoteSearchSegment: Equatable, Sendable {
    let text: String
    let isMatch: Bool
}

enum MojiNoteSearch {
    static let options: String.CompareOptions = [.caseInsensitive, .widthInsensitive]
    static let snippetLead = 24
    static let snippetLimit = 160

    static func terms(_ query: String) -> [String] {
        var seen: Set<String> = []
        return query
            .split(whereSeparator: \.isWhitespace)
            .map { fold(String($0)) }
            .filter { seen.insert($0.lowercased()).inserted }
    }

    static func results(in notes: [MojiNote], query: String) -> [MojiNoteSearchHit] {
        let terms = terms(query)
        guard !terms.isEmpty else { return [] }

        var titleHits: [MojiNoteSearchHit] = []
        var bodyHits: [MojiNoteSearchHit] = []
        for note in notes {
            let title = fold(note.title)
            let body = fold(note.body)
            var inTitle = 0
            var matchesAll = true
            for term in terms {
                if title.range(of: term, options: options) != nil {
                    inTitle += 1
                } else if body.range(of: term, options: options) == nil {
                    matchesAll = false
                    break
                }
            }
            guard matchesAll else { continue }
            let hit = MojiNoteSearchHit(
                note: note,
                snippet: inTitle == terms.count ? nil : snippet(in: note.body, terms: terms)
            )
            if inTitle > 0 {
                titleHits.append(hit)
            } else {
                bodyHits.append(hit)
            }
        }
        return titleHits + bodyHits
    }

    static func snippet(in body: String, terms: [String]) -> String? {
        var result: String?
        body.enumerateLines { line, stop in
            let folded = fold(line)
            let first = terms
                .compactMap { folded.range(of: $0, options: options) }
                .min { $0.lowerBound < $1.lowerBound }
            guard let first else { return }
            let offset = folded.distance(from: folded.startIndex, to: first.lowerBound)
            let start = max(0, offset - snippetLead)
            let text = String(line.dropFirst(start).prefix(snippetLimit)).trimmingCharacters(in: .whitespaces)
            result = start > 0 ? "…" + text : text
            stop = true
        }
        return result
    }

    static func segments(of text: String, terms: [String]) -> [MojiNoteSearchSegment] {
        guard !text.isEmpty else { return [] }
        let folded = fold(text)
        var marks: [Range<Int>] = []
        for term in terms where !term.isEmpty {
            var start = folded.startIndex
            while start < folded.endIndex,
                  let found = folded.range(of: term, options: options, range: start..<folded.endIndex),
                  !found.isEmpty {
                marks.append(found.lowerBound.utf16Offset(in: folded)..<found.upperBound.utf16Offset(in: folded))
                start = found.upperBound
            }
        }
        guard !marks.isEmpty else {
            return [MojiNoteSearchSegment(text: text, isMatch: false)]
        }

        var merged: [Range<Int>] = []
        for mark in marks.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, mark.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, mark.upperBound)
            } else {
                merged.append(mark)
            }
        }

        var segments: [MojiNoteSearchSegment] = []
        var cursor = 0
        for mark in merged {
            if mark.lowerBound > cursor {
                segments.append(MojiNoteSearchSegment(text: slice(text, cursor..<mark.lowerBound), isMatch: false))
            }
            segments.append(MojiNoteSearchSegment(text: slice(text, mark), isMatch: true))
            cursor = mark.upperBound
        }
        let length = text.utf16.count
        if cursor < length {
            segments.append(MojiNoteSearchSegment(text: slice(text, cursor..<length), isMatch: false))
        }
        return segments
    }

    static func fold(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { $0.value == 0x0451 || $0.value == 0x0401 }) else {
            return text
        }
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0451: scalars.append("\u{0435}")
            case 0x0401: scalars.append("\u{0415}")
            default: scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    private static func slice(_ text: String, _ range: Range<Int>) -> String {
        let lower = String.Index(utf16Offset: range.lowerBound, in: text)
        let upper = String.Index(utf16Offset: range.upperBound, in: text)
        return String(text[lower..<upper])
    }
}
