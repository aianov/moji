import Foundation
import Testing
@testable import Moji

@Suite("Notes search and text")
struct MojiNoteSearchTests {
    private func note(_ id: String, _ title: String, _ body: String, folder: String? = nil, minutes: Double = 0) -> MojiNote {
        let date = Date(timeIntervalSince1970: 1_790_000_000 + minutes * 60)
        return MojiNote(id: id, title: title, body: body, folderID: folder, isPinned: false, createdAt: date, updatedAt: date)
    }

    private var library: [MojiNote] {
        [
            note("particles", "Particles", "は marks the topic\nThe subject takes が, not は", folder: "grammar", minutes: 4),
            note("verbs", "Verbs", "食べる means to eat\n飲む means to drink", folder: "words", minutes: 3),
            note("russian", "Слова", "Ещё одно слово\nи ещё одно", minutes: 2),
            note("tv", "ＮＨＫ ニュース", "Easy Japanese news", minutes: 1),
            note("long", "", String(repeating: "あ", count: 80) + " needle " + String(repeating: "い", count: 80), minutes: 0)
        ]
    }

    @Test("Search looks through titles and text of every note, in every folder")
    func searchAcrossNotes() {
        let notes = library

        let particle = MojiNoteSearch.results(in: notes, query: "が")
        #expect(particle.map(\.id) == ["particles"])
        #expect(particle.first?.snippet == "The subject takes が, not は")

        let byTitle = MojiNoteSearch.results(in: notes, query: "PARTICLES")
        #expect(byTitle.map(\.id) == ["particles"])
        #expect(byTitle.first?.snippet == nil)

        #expect(MojiNoteSearch.results(in: notes, query: "eat").map(\.id) == ["verbs"])
        #expect(MojiNoteSearch.results(in: notes, query: "еще одно").map(\.id) == ["russian"])
        #expect(MojiNoteSearch.results(in: notes, query: "ЕЩЁ").first?.snippet == "Ещё одно слово")
        #expect(MojiNoteSearch.results(in: notes, query: "nhk").map(\.id) == ["tv"])
        #expect(MojiNoteSearch.results(in: notes, query: "飲む drink").map(\.id) == ["verbs"])
        #expect(MojiNoteSearch.results(in: notes, query: "飲む topic").isEmpty)
        #expect(MojiNoteSearch.results(in: notes, query: " \n ").isEmpty)
        #expect(MojiNoteSearch.results(in: notes, query: "means").map(\.id) == ["verbs"])
        #expect(MojiNoteSearch.results(in: notes, query: "s").map(\.id) == ["particles", "verbs", "tv"])
    }

    @Test("A match deep in a long line is shown with the text around it")
    func snippetAroundMatch() throws {
        let hit = try #require(MojiNoteSearch.results(in: library, query: "needle").first)
        let snippet = try #require(hit.snippet)
        #expect(snippet.hasPrefix("…"))
        #expect(snippet.contains("needle"))
        #expect(snippet.count <= MojiNoteSearch.snippetLimit + 1)
    }

    @Test("Highlight segments cover every match and keep the original text")
    func segments() {
        let terms = MojiNoteSearch.terms("еще ОДНО")
        let segments = MojiNoteSearch.segments(of: "Ещё одно слово, ещё одно", terms: terms)
        #expect(segments.map(\.text).joined() == "Ещё одно слово, ещё одно")
        #expect(segments.filter(\.isMatch).map(\.text) == ["Ещё", "одно", "ещё", "одно"])
        #expect(segments.first == MojiNoteSearchSegment(text: "Ещё", isMatch: true))

        let japanese = MojiNoteSearch.segments(of: "日本語の本", terms: MojiNoteSearch.terms("本"))
        #expect(japanese == [
            MojiNoteSearchSegment(text: "日", isMatch: false),
            MojiNoteSearchSegment(text: "本", isMatch: true),
            MojiNoteSearchSegment(text: "語の", isMatch: false),
            MojiNoteSearchSegment(text: "本", isMatch: true)
        ])
        #expect(MojiNoteSearch.segments(of: "nothing", terms: MojiNoteSearch.terms("zzz")) == [MojiNoteSearchSegment(text: "nothing", isMatch: false)])
        #expect(MojiNoteSearch.terms("a  A b") == ["a", "b"])
    }

    @Test("A note shows its title, or its first line when it has none, then the next line")
    func headingsAndPreviews() {
        #expect(MojiNoteText.heading(title: "  て-form \n", body: "x") == "て-form")
        #expect(MojiNoteText.preview(title: "て-form", body: "\n\n  食べて  \nnext") == "食べて")
        #expect(MojiNoteText.heading(title: " ", body: "\n  First line\nSecond line") == "First line")
        #expect(MojiNoteText.preview(title: " ", body: "\n  First line\nSecond line") == "Second line")
        #expect(MojiNoteText.preview(title: "", body: "Only line") == nil)
        #expect(MojiNoteText.heading(title: "", body: " \n ") == nil)
        #expect(MojiNoteText.isBlank(title: "\u{3000}", body: "\n\t "))
        #expect(!MojiNoteText.isBlank(title: "", body: "あ"))
        #expect(MojiNoteText.folderName("  Grammar\n  notes ") == "Grammar notes")
        #expect(MojiNoteText.folderName(" \n ") == nil)
    }

    @Test("Words and characters are counted, line breaks are not characters")
    func counts() {
        #expect(MojiNoteText.counts("") == .zero)
        let english = MojiNoteText.counts("Hello world\nagain")
        #expect(english.words == 3)
        #expect(english.characters == 16)
        let japanese = MojiNoteText.counts("今日はいい天気です")
        #expect(japanese.characters == 9)
        #expect(japanese.words >= 3)
    }

    @Test("Folder order helpers match how lists move rows")
    func folderOrder() {
        let ids = ["a", "b", "c", "d"]
        #expect(MojiNoteOrder.moved(ids, from: IndexSet(integer: 0), to: 2) == ["b", "a", "c", "d"])
        #expect(MojiNoteOrder.moved(ids, from: IndexSet(integer: 3), to: 0) == ["d", "a", "b", "c"])
        #expect(MojiNoteOrder.moved(ids, from: IndexSet(integer: 0), to: 4) == ["b", "c", "d", "a"])
        #expect(MojiNoteOrder.moved(ids, from: IndexSet([1, 2]), to: 0) == ["b", "c", "a", "d"])
        #expect(MojiNoteOrder.shifted(ids, moving: "c", by: -1) == ["a", "c", "b", "d"])
        #expect(MojiNoteOrder.shifted(ids, moving: "d", by: 1) == ids)
        #expect(MojiNoteOrder.shifted(ids, moving: "x", by: 1) == ids)
    }
}
