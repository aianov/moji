import Foundation
import Testing
@testable import Moji

private struct LearnSeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private struct LearnScenario {
    let name: String
    let progress: [String: MojiCharacterProgress]
    let state: MojiLearnPageState
}

@Suite("Learn planner")
struct MojiLearnPlannerTests {
    private let catalog = MojiAlphabetCatalog.shared
    private let planner = MojiLearnPlanner.shared
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let day: TimeInterval = 86_400

    private func progress(
        _ ids: [String],
        strength: Int,
        seenDaysAgo: Double = 0
    ) -> [String: MojiCharacterProgress] {
        var result: [String: MojiCharacterProgress] = [:]
        for id in ids {
            result[id] = MojiCharacterProgress(
                strength: strength,
                seen: strength > 0 ? strength : 1,
                correct: strength,
                lastSeenAt: now.addingTimeInterval(-seenDaysAgo * day)
            )
        }
        return result
    }

    private func state(introduced ids: [String], fresh: [String] = []) -> MojiLearnPageState {
        MojiLearnPageState(introducedIDs: ids, freshIDs: fresh, lessonsCompleted: 1, lastLessonAt: now)
    }

    private func lesson(
        _ page: MojiPage,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState,
        at date: Date? = nil,
        batchIndex: Int? = nil,
        seed: UInt64 = 1
    ) throws -> MojiLesson {
        var generator = LearnSeededGenerator(state: seed)
        return try #require(
            planner.makeLesson(
                page: page,
                progress: progress,
                state: state,
                now: date ?? now,
                batchIndex: batchIndex,
                using: &generator
            )
        )
    }

    private func varied(_ ids: [String]) -> [String: MojiCharacterProgress] {
        var result: [String: MojiCharacterProgress] = [:]
        for (index, id) in ids.enumerated() {
            result[id] = MojiCharacterProgress(
                strength: 2 + index % 4,
                seen: 6,
                correct: 4,
                lastSeenAt: now.addingTimeInterval(-Double(index % 9) * day)
            )
        }
        return result
    }

    private func scenarios(_ page: MojiPage) -> [LearnScenario] {
        let batches = planner.batches(page)
        let all = catalog.pool(page).map(\.id)
        let first = batches[0].characterIDs
        var result = [
            LearnScenario(name: "fresh", progress: [:], state: .empty),
            LearnScenario(
                name: "first batch just introduced",
                progress: progress(first, strength: 1),
                state: state(introduced: first, fresh: first)
            ),
            LearnScenario(
                name: "progress erased",
                progress: [:],
                state: state(introduced: batches.prefix(3).flatMap(\.characterIDs))
            ),
            LearnScenario(
                name: "everything marked known",
                progress: progress(all, strength: MojiCharacterProgress.masteryLevel, seenDaysAgo: 10),
                state: .empty
            ),
            LearnScenario(name: "everything learned", progress: varied(all), state: state(introduced: all))
        ]

        for count in [1, 4, 9] {
            let learned = batches.prefix(count).flatMap(\.characterIDs)
            var entries = varied(learned)
            entries[batches[count].characterIDs[0]] = MojiCharacterProgress(
                strength: 1,
                seen: 2,
                correct: 1,
                lastSeenAt: now
            )
            for id in batches[count + 5].characterIDs {
                entries[id] = MojiCharacterProgress(
                    strength: MojiCharacterProgress.masteryLevel,
                    seen: 0,
                    correct: 0,
                    lastSeenAt: now
                )
            }
            result.append(
                LearnScenario(name: "mid path after \(count) batches", progress: entries, state: state(introduced: learned))
            )
        }

        let partly = batches.prefix(3).flatMap(\.characterIDs) + batches[3].characterIDs.prefix(2)
        result.append(
            LearnScenario(name: "batch partly introduced", progress: varied(partly), state: state(introduced: partly))
        )
        let ahead = batches.prefix(3).flatMap(\.characterIDs) + batches[4].characterIDs.prefix(2)
        result.append(
            LearnScenario(name: "later batch partly introduced", progress: varied(ahead), state: state(introduced: ahead))
        )
        return result
    }

    private func metBefore(
        _ page: MojiPage,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState
    ) -> Set<String> {
        let introduced = Set(state.introducedIDs)
        return Set(catalog.pool(page).map(\.id).filter { id in
            guard let entry = progress[id] else { return false }
            return entry.strength > 0 || (introduced.contains(id) && entry.seen > 0)
        })
    }

    private func referencedIDs(_ step: MojiLessonStep) -> [String] {
        switch step {
        case .intro(let id):
            [id]
        case .choice(let id, _, let optionIDs), .listen(let id, let optionIDs):
            [id] + optionIDs
        case .match(let leftIDs, let rightIDs):
            leftIDs + rightIDs
        case .write(_, let ids), .word(let ids, .type), .read(let ids):
            ids
        case .word(let ids, .choose(let options)):
            ids + options.flatMap { $0 }
        }
    }

    @Test("Batches cover every character of the page once, in lesson order", arguments: MojiPage.all)
    func batchesCoverThePage(page: MojiPage) {
        let batches = planner.batches(page)
        let ids = batches.flatMap(\.characterIDs)

        #expect(ids == catalog.pool(page).map(\.id))
        #expect(batches.count >= 15)
        #expect(batches.allSatisfy { (3...7).contains($0.characterIDs.count) })
        #expect(batches.enumerated().allSatisfy { $0.offset == $0.element.index })
        #expect(batches.allSatisfy { $0.page == page })
        for batch in batches {
            if page.isKanji {
                #expect(batch.sectionID == page.rawValue)
                #expect(batch.characterIDs.allSatisfy { catalog.character($0)?.page == page })
            } else {
                #expect(batch.characterIDs.allSatisfy { catalog.character($0)?.sectionID == batch.sectionID })
            }
        }
    }

    @Test("Kana batches are the chart's rows")
    func kanaBatchesFollowTheRows() {
        let glyphs = planner.batches(.hiragana).map { batch in
            batch.characterIDs.compactMap { catalog.character($0)?.glyph }.joined()
        }
        #expect(glyphs.first == "あいうえお")
        #expect(glyphs.contains("かきくけこ"))
        #expect(glyphs.contains("やゆよ"))
        #expect(glyphs.contains("わをん"))
        #expect(glyphs.contains("きゃきゅきょぎゃぎゅぎょ"))
    }

    @Test("A new learner starts on the first batch, and every other batch is open too")
    func freshPath() {
        let path = planner.path(page: .hiragana, progress: [:], state: .empty)
        #expect(path.currentIndex == 0)
        #expect(path.batches.first?.status == .current)
        #expect(path.batches.dropFirst().allSatisfy { $0.status == .new })
    }

    @Test("A batch is done once it averages 3 with none below 2")
    func doneRule() {
        let first = planner.batches(.hiragana)[0].characterIDs
        let introduced = state(introduced: first)

        var solid = progress(first, strength: 3)
        let done = planner.path(page: .hiragana, progress: solid, state: introduced)
        #expect(done.batches[0].status == .learned)
        #expect(done.currentIndex == 1)

        solid[first[0]]?.strength = 1
        solid[first[1]]?.strength = 5
        solid[first[2]]?.strength = 5
        let held = planner.path(page: .hiragana, progress: solid, state: introduced)
        #expect(held.currentIndex == 0)
        #expect(held.batches[0].status == .current)
        #expect(held.batches[1].status == .new)
    }

    @Test("A batch introduced by the latest lesson needs one more lesson")
    func freshBatchWaitsForOneMoreLesson() {
        let first = planner.batches(.hiragana)[0].characterIDs
        let strong = progress(first, strength: 4)

        let fresh = planner.path(page: .hiragana, progress: strong, state: state(introduced: first, fresh: first))
        #expect(fresh.currentIndex == 0)
        #expect(fresh.batches[0].status == .current)
        #expect(fresh.batches[1].status == .new)

        let later = planner.path(page: .hiragana, progress: strong, state: state(introduced: first))
        #expect(later.currentIndex == 1)
    }

    @Test("Any batch can be started, and its lesson introduces that batch first", arguments: MojiPage.all)
    func anyBatchCanStart(page: MojiPage) throws {
        for batch in planner.batches(page) {
            let lesson = try lesson(page, progress: [:], state: .empty, batchIndex: batch.index, seed: UInt64(batch.index + 1))
            let context = "\(page.rawValue), batch \(batch.index)"
            let members = Set(batch.characterIDs)

            #expect(lesson.batchIndex == batch.index, "\(context)")
            #expect(lesson.newCharacterIDs == batch.characterIDs, "\(context)")
            #expect(lesson.items.prefix(batch.characterIDs.count).map(\.step) == batch.characterIDs.map { .intro(characterID: $0) }, "\(context)")
            #expect(MojiLearnPlanner.lessonLength.contains(lesson.items.count), "\(context)")
            #expect(!lesson.items.contains { $0.isHard }, "\(context)")

            let exercises = lesson.items.dropFirst(batch.characterIDs.count)
            #expect(exercises.allSatisfy { $0.step.kind != .intro }, "\(context)")
            #expect(exercises.allSatisfy { Set(referencedIDs($0.step)).isSubset(of: members) }, "\(context)")
            for id in batch.characterIDs {
                #expect(exercises.contains { $0.step.characterIDs.contains(id) }, "\(context): \(id)")
            }
        }
    }

    @Test("A batch that is already learned can be started again for practice")
    func learnedBatchCanStartAgain() throws {
        let page = MojiPage.kanji(.people)
        let batches = planner.batches(page)
        let learned = batches.prefix(3).flatMap(\.characterIDs)
        let entries = progress(learned, strength: 4, seenDaysAgo: 2)
        let introduced = state(introduced: learned)
        #expect(planner.path(page: page, progress: entries, state: introduced).batches[1].status == .learned)

        let again = try lesson(page, progress: entries, state: introduced, batchIndex: 1)
        #expect(again.batchIndex == 1)
        #expect(again.newCharacterIDs.isEmpty)
        #expect(!again.items.contains { $0.step.kind == .intro })
        #expect(Set(batches[1].characterIDs).isSubset(of: Set(again.items.flatMap(\.step.characterIDs))))

        var generator = LearnSeededGenerator(state: 2)
        #expect(planner.makeLesson(page: page, progress: entries, state: introduced, now: now, batchIndex: batches.count, using: &generator) == nil)
    }

    @Test("A picked batch practices every one of its characters, whatever its state", arguments: MojiPage.all)
    func pickedBatchIsPracticedFully(page: MojiPage) throws {
        let batches = planner.batches(page)
        for batch in batches {
            let members = batch.characterIDs
            let half = Array(members.prefix(members.count / 2))
            let earlier = batches.prefix(batch.index).suffix(2).flatMap(\.characterIDs)
            let cases = [
                LearnScenario(
                    name: "learned",
                    progress: progress(earlier + members, strength: 4, seenDaysAgo: 2),
                    state: state(introduced: earlier + members)
                ),
                LearnScenario(
                    name: "half introduced",
                    progress: progress(earlier + half, strength: 3, seenDaysAgo: 1),
                    state: state(introduced: earlier + half)
                ),
                LearnScenario(
                    name: "slipped",
                    progress: progress(earlier + members, strength: 1, seenDaysAgo: 6),
                    state: state(introduced: earlier + members)
                )
            ]
            for scenario in cases {
                let context = "\(page.rawValue), batch \(batch.index), \(scenario.name)"
                let lesson = try lesson(
                    page,
                    progress: scenario.progress,
                    state: scenario.state,
                    batchIndex: batch.index,
                    seed: UInt64(batch.index + 3)
                )
                let tested = Set(lesson.items.filter { $0.step.kind != .intro }.flatMap(\.step.characterIDs))
                #expect(lesson.batchIndex == batch.index, "\(context)")
                #expect(Set(members).isSubset(of: tested), "\(context)")
                #expect(MojiLearnPlanner.lessonLength.contains(lesson.items.count), "\(context)")
            }
        }
    }

    @Test("The default path goes top to bottom and skips batches done out of order")
    func defaultPathGoesTopToBottom() throws {
        let batches = planner.batches(.hiragana)
        let early = batches.prefix(2).flatMap(\.characterIDs)
        let ahead = batches[4].characterIDs
        var entries = progress(early + ahead, strength: 3)
        let jumped = state(introduced: early + ahead)

        let path = planner.path(page: .hiragana, progress: entries, state: jumped)
        #expect(path.currentIndex == 2)
        #expect(Array(path.batches.prefix(6).map(\.status)) == [.learned, .learned, .current, .new, .learned, .new])

        let next = try lesson(.hiragana, progress: entries, state: jumped)
        #expect(next.batchIndex == 2)
        #expect(next.newCharacterIDs == batches[2].characterIDs)

        for id in batches[2].characterIDs + batches[3].characterIDs {
            entries[id] = MojiCharacterProgress(strength: 3, seen: 3, correct: 3, lastSeenAt: now)
        }
        let caughtUp = state(introduced: batches.prefix(5).flatMap(\.characterIDs))
        #expect(planner.path(page: .hiragana, progress: entries, state: caughtUp).currentIndex == 5)
        #expect(try lesson(.hiragana, progress: entries, state: caughtUp).batchIndex == 5)
    }

    @Test("A batch started out of order keeps its second lesson until a later lesson covers it")
    func outOfOrderBatchStaysFresh() throws {
        let batches = planner.batches(.hiragana)
        let early = batches.prefix(2).flatMap(\.characterIDs)
        var entries = progress(early, strength: 3, seenDaysAgo: 1)
        let start = state(introduced: early)

        let jump = try lesson(.hiragana, progress: entries, state: start, batchIndex: 6)
        #expect(jump.batchIndex == 6)
        #expect(jump.newCharacterIDs == batches[6].characterIDs)
        let afterJump = start.completing(jump, at: now)
        #expect(afterJump.freshIDs == batches[6].characterIDs)

        for id in batches[6].characterIDs {
            entries[id] = MojiCharacterProgress(strength: 4, seen: 4, correct: 4, lastSeenAt: now)
        }
        let path = planner.path(page: .hiragana, progress: entries, state: afterJump)
        #expect(path.currentIndex == 2)
        #expect(path.batches[6].status == .review)

        let next = try lesson(.hiragana, progress: entries, state: afterJump)
        #expect(next.batchIndex == 2)
        let covered = Set(next.coveredCharacterIDs)
        let afterNext = afterJump.completing(next, at: now)
        #expect(afterNext.freshIDs == batches[6].characterIDs.filter { !covered.contains($0) } + next.newCharacterIDs)

        let consolidation = MojiLesson(
            id: UUID(),
            page: .hiragana,
            batchIndex: 6,
            newCharacterIDs: [],
            reviewCharacterIDs: [],
            items: [MojiLessonItem(step: .write(batchID: batches[6].id, characterIDs: batches[6].characterIDs))]
        )
        let consolidated = afterNext.completing(consolidation, at: now)
        #expect(Set(consolidated.freshIDs).isDisjoint(with: batches[6].characterIDs))
        #expect(planner.path(page: .hiragana, progress: entries, state: consolidated).batches[6].status == .learned)
    }

    @Test("The default path goes back to the first batch that is no longer done")
    func slippedBatchComesFirst() throws {
        let batches = planner.batches(.hiragana)
        let learned = batches.prefix(4).flatMap(\.characterIDs)
        var entries = progress(learned, strength: 3)
        let introduced = state(introduced: learned)
        #expect(planner.path(page: .hiragana, progress: entries, state: introduced).currentIndex == 4)

        entries[batches[1].characterIDs[0]]?.strength = 1
        let slipped = planner.path(page: .hiragana, progress: entries, state: introduced)
        #expect(slipped.currentIndex == 1)
        #expect(slipped.batches[2].status == .learned)

        let back = try lesson(.hiragana, progress: entries, state: introduced)
        #expect(back.batchIndex == 1)
        #expect(back.newCharacterIDs.isEmpty)
    }

    @Test("Characters marked known open their batches at once")
    func knownCharactersSkipAhead() throws {
        let batches = planner.batches(.hiragana)
        let known = batches.prefix(3).flatMap(\.characterIDs)
        let marked = progress(known, strength: MojiCharacterProgress.masteryLevel)

        let path = planner.path(page: .hiragana, progress: marked, state: .empty)
        #expect(path.batches.prefix(3).allSatisfy { $0.status == .learned })
        #expect(path.currentIndex == 3)

        let next = try lesson(.hiragana, progress: marked, state: .empty)
        #expect(next.batchIndex == 3)
        #expect(next.newCharacterIDs == batches[3].characterIDs)
        #expect(Set(next.reviewCharacterIDs).isDisjoint(with: known))
    }

    @Test("A whole page marked known turns into review lessons")
    func wholePageKnown() throws {
        let all = catalog.pool(.katakana).map(\.id)
        let marked = progress(all, strength: MojiCharacterProgress.masteryLevel, seenDaysAgo: 10)
        let path = planner.path(page: .katakana, progress: marked, state: .empty)
        #expect(path.isComplete)
        #expect(path.currentIndex == nil)

        let review = try lesson(.katakana, progress: marked, state: .empty)
        #expect(review.isReview)
        #expect(review.newCharacterIDs.isEmpty)
        #expect(!review.reviewCharacterIDs.isEmpty)
    }

    @Test("A kanji theme marked known leaves the other themes where they were")
    func themeKnownLeavesOtherThemes() throws {
        let people = catalog.pool(.kanji(.people)).map(\.id)
        let marked = progress(people, strength: MojiCharacterProgress.masteryLevel, seenDaysAgo: 10)

        #expect(planner.path(page: .kanji(.people), progress: marked, state: .empty).isComplete)
        let time = planner.path(page: .kanji(.time), progress: marked, state: .empty)
        #expect(time.currentIndex == 0)
        #expect(time.learnedCount == 0)

        let next = try lesson(.kanji(.time), progress: marked, state: .empty)
        #expect(next.page == .kanji(.time))
        #expect(next.newCharacterIDs == planner.batches(.kanji(.time))[0].characterIDs)
        #expect(Set(next.items.flatMap(\.step.characterIDs)).isDisjoint(with: people))
    }

    @Test("Erasing mastery starts the path over")
    func erasedProgressResetsThePath() {
        let first = planner.batches(.hiragana)[0].characterIDs
        let path = planner.path(page: .hiragana, progress: [:], state: state(introduced: first))
        #expect(path.currentIndex == 0)
        #expect(planner.upcomingNewIDs(path: path, progress: [:], state: state(introduced: first)) == first)
    }

    @Test("A first lesson shows every new character, then tests only those", arguments: MojiPage.all)
    func firstLesson(page: MojiPage) throws {
        let first = planner.batches(page)[0].characterIDs
        let intros = first.map { MojiLessonStep.intro(characterID: $0) }
        for seed in 1...10 {
            let lesson = try lesson(page, progress: [:], state: .empty, seed: UInt64(seed))

            #expect(lesson.page == page)
            #expect(lesson.newCharacterIDs == first)
            #expect(MojiLearnPlanner.lessonLength.contains(lesson.items.count))
            #expect(!lesson.items.contains { $0.isHard })
            #expect(lesson.items.prefix(first.count).map(\.step) == intros)

            let exercises = lesson.items.dropFirst(first.count)
            #expect(exercises.allSatisfy { $0.step.kind != .intro })
            #expect(exercises.allSatisfy { Set(referencedIDs($0.step)).isSubset(of: first) })
            for id in first {
                #expect(exercises.contains { $0.step.characterIDs.contains(id) })
            }
        }
    }

    @Test("Every introduction comes before the first exercise", arguments: MojiPage.all)
    func introductionsComeFirst(page: MojiPage) throws {
        for scenario in scenarios(page) {
            for seed in 1...10 {
                let lesson = try lesson(page, progress: scenario.progress, state: scenario.state, seed: UInt64(seed))
                let context = "\(page.rawValue), \(scenario.name), seed \(seed)"

                let exercises = lesson.items.drop { $0.step.kind == .intro }
                #expect(!exercises.contains { $0.step.kind == .intro }, "\(context)")

                let introduced = lesson.items.prefix { $0.step.kind == .intro }.flatMap(\.step.characterIDs)
                #expect(introduced == lesson.newCharacterIDs, "\(context)")
                #expect(MojiLearnPlanner.lessonLength.contains(lesson.items.count), "\(context)")
            }
        }
    }

    @Test("Exercises use only characters met before the lesson or introduced earlier in it", arguments: MojiPage.all)
    func exercisesUseOnlyMetCharacters(page: MojiPage) throws {
        for scenario in scenarios(page) {
            let before = metBefore(page, progress: scenario.progress, state: scenario.state)
            for seed in 1...10 {
                let lesson = try lesson(page, progress: scenario.progress, state: scenario.state, seed: UInt64(seed))
                var met = before
                var generator = LearnSeededGenerator(state: UInt64(seed) &* 7)

                for (index, item) in lesson.items.enumerated() {
                    let context = "\(page.rawValue), \(scenario.name), seed \(seed), item \(index): \(item.step)"
                    if case .intro(let id) = item.step {
                        #expect(lesson.newCharacterIDs.contains(id), "\(context)")
                        met.insert(id)
                        continue
                    }

                    let strangers = referencedIDs(item.step).filter { !met.contains($0) }
                    #expect(strangers.isEmpty, "\(context)")

                    switch item.step {
                    case .choice(_, _, let optionIDs), .listen(_, let optionIDs):
                        #expect(
                            (MojiLearnPlanner.minimumOptionCount...MojiLearnPlanner.optionCount).contains(optionIDs.count),
                            "\(context)"
                        )
                    default:
                        break
                    }

                    let retry = planner.retry(of: item, using: &generator)
                    #expect(retry.step.kind == item.step.kind, "\(context)")
                    #expect(Set(referencedIDs(retry.step)) == Set(referencedIDs(item.step)), "\(context)")
                }
            }
        }
    }

    @Test("With too few characters met, a question gets fewer options, never a stranger")
    func fewMetCharacters() throws {
        let three = ["h-a", "h-i", "h-u"].compactMap { catalog.character($0) }
        var generator = LearnSeededGenerator(state: 5)

        var builder = LessonBuilder(planner: planner, progress: [:], met: three)
        let item = try #require(builder.choice("h-a", direction: .glyphToAnswer, using: &generator))
        if case .choice(_, _, let optionIDs) = item.step {
            #expect(optionIDs.count == MojiLearnPlanner.minimumOptionCount)
            #expect(Set(optionIDs) == ["h-a", "h-i", "h-u"])
        } else {
            Issue.record("Expected a choice: \(item.step)")
        }
        #expect(builder.choice("h-e", direction: .glyphToAnswer, using: &generator) == nil)
        #expect(builder.listen("h-e", using: &generator) == nil)

        var tiny = LessonBuilder(planner: planner, progress: [:], met: Array(three.prefix(2)))
        #expect(tiny.firstCheck("h-a", using: &generator) == nil)
        #expect(tiny.medium("h-a", using: &generator) == nil)
        #expect(tiny.match(preferring: ["h-a", "h-i", "h-u"], using: &generator) == nil)
    }

    @Test("Lessons stay between 12 and 15 exercises", arguments: MojiPage.all)
    func lessonLength(page: MojiPage) throws {
        let batches = planner.batches(page)
        for count in 0..<4 {
            let introduced = batches.prefix(count).flatMap(\.characterIDs)
            let learned = progress(introduced, strength: 3, seenDaysAgo: 3)
            let lesson = try lesson(page, progress: learned, state: state(introduced: introduced), seed: UInt64(count + 1))
            #expect(MojiLearnPlanner.lessonLength.contains(lesson.items.count))
        }
    }

    @Test("Earlier batches come back when they are due")
    func reviewBringsBackEarlierBatches() throws {
        let batches = planner.batches(.hiragana)
        let earlier = batches.prefix(2).flatMap(\.characterIDs)
        let learned = progress(earlier, strength: 3, seenDaysAgo: 5)
        let lesson = try lesson(.hiragana, progress: learned, state: state(introduced: earlier))

        #expect(lesson.batchIndex == 2)
        #expect(!lesson.reviewCharacterIDs.isEmpty)
        #expect(Set(lesson.reviewCharacterIDs).isSubset(of: earlier))
        let tested = Set(lesson.items.flatMap(\.step.characterIDs))
        #expect(!tested.isDisjoint(with: earlier))
    }

    @Test("The weakest and longest unseen come back first")
    func reviewOrder() {
        let ids = planner.batches(.hiragana)[0].characterIDs
        var entries = progress(ids, strength: 4, seenDaysAgo: 1)
        entries[ids[3]] = MojiCharacterProgress(strength: 1, seen: 4, correct: 1, lastSeenAt: now.addingTimeInterval(-day))
        entries[ids[1]] = MojiCharacterProgress(strength: 4, seen: 6, correct: 6, lastSeenAt: now.addingTimeInterval(-20 * day))

        var generator = LearnSeededGenerator(state: 3)
        let picked = planner.pickReview(
            pool: ids,
            progress: entries,
            now: now,
            count: 2,
            fillWithAnything: false,
            using: &generator
        )
        #expect(picked == [ids[1], ids[3]] || picked == [ids[3], ids[1]])
    }

    @Test("Every choice has exactly one right answer", arguments: MojiPage.all)
    func choicesHaveOneAnswer(page: MojiPage) throws {
        let batches = planner.batches(page)
        for seed in 1...8 {
            let introduced = batches.prefix(seed % 5).flatMap(\.characterIDs)
            let learned = progress(introduced, strength: 2 + seed % 3, seenDaysAgo: Double(seed))
            let lesson = try lesson(page, progress: learned, state: state(introduced: introduced), seed: UInt64(seed))

            for item in lesson.items {
                switch item.step {
                case .choice(let id, _, let optionIDs):
                    let options = optionIDs.compactMap { catalog.character($0) }
                    #expect(options.count == MojiLearnPlanner.optionCount)
                    #expect(optionIDs.filter { $0 == id }.count == 1)
                    #expect(Set(options.map(\.optionKey)).count == options.count)
                    #expect(Set(options.map(\.glyph)).count == options.count)
                case .listen(let id, let optionIDs):
                    let options = optionIDs.compactMap { catalog.character($0) }
                    #expect(optionIDs.filter { $0 == id }.count == 1)
                    #expect(Set(options.map(LessonBuilder.soundKey)).count == options.count)
                case .match(let left, let right):
                    #expect(Set(left) == Set(right))
                    let labels = left.compactMap { catalog.character($0) }.map(LessonBuilder.matchLabel)
                    #expect(Set(labels).count == left.count)
                case .word(let ids, .choose(let options)):
                    #expect(options.filter { $0 == ids }.count == 1)
                    let sounds = options.map { option in
                        option.compactMap { catalog.character($0) }.map(LessonBuilder.soundKey).joined(separator: "|")
                    }
                    #expect(Set(sounds).count == options.count)
                case .intro, .write, .word, .read:
                    break
                }
            }
        }
    }

    @Test("Hard exercises go to characters with some strength, in the second half")
    func hardExercises() throws {
        let batches = planner.batches(.hiragana)
        let introduced = batches.prefix(3).flatMap(\.characterIDs)
        for seed in 1...10 {
            var learned = progress(introduced, strength: 3, seenDaysAgo: 4)
            for id in batches[2].characterIDs {
                learned[id]?.strength = 2
            }
            let lesson = try lesson(.hiragana, progress: learned, state: state(introduced: introduced), seed: UInt64(seed))
            for (index, item) in lesson.items.enumerated() where item.isHard {
                #expect(index >= lesson.items.count / 2)
                #expect(item.step.characterIDs.allSatisfy { (learned[$0]?.strength ?? 0) >= MojiLearnPlanner.hardMinimumStrength })
                switch item.step.kind {
                case .read: break
                default: Issue.record("A hard exercise must be recall: \(item.step)")
                }
            }
        }
    }

    @Test("A missed exercise comes back reshuffled, plain, marked as a retry")
    func retries() {
        let item = MojiLessonItem(
            step: .choice(characterID: "h-a", direction: .glyphToAnswer, optionIDs: ["h-a", "h-i", "h-u", "h-e"]),
            isHard: true
        )
        var generator = LearnSeededGenerator(state: 9)
        let retry = planner.retry(of: item, using: &generator)

        #expect(retry.isRetry)
        #expect(!retry.isHard)
        #expect(retry.step.characterIDs == ["h-a"])
        if case .choice(_, _, let options) = retry.step {
            #expect(Set(options) == ["h-a", "h-i", "h-u", "h-e"])
        } else {
            Issue.record("A retry keeps its kind")
        }
    }

    @Test("Finishing a lesson records what it introduced")
    func completingALesson() throws {
        let lesson = try lesson(.hiragana, progress: [:], state: .empty)
        let next = MojiLearnPageState.empty.completing(lesson, at: now)

        #expect(next.lessonsCompleted == 1)
        #expect(next.freshIDs == lesson.newCharacterIDs)
        #expect(Set(next.introducedIDs) == Set(lesson.coveredCharacterIDs))

        let again = next.completing(lesson, at: now)
        #expect(again.introducedIDs.count == next.introducedIDs.count)
    }

    @Test("Replaying answers follows the shared mastery rule")
    func replayingAnswers() {
        let answers = [
            MojiLessonAnswer(characterID: "h-a", isCorrect: true),
            MojiLessonAnswer(characterID: "h-a", isCorrect: true),
            MojiLessonAnswer(characterID: "h-a", isCorrect: false),
            MojiLessonAnswer(characterID: "h-i", isCorrect: true)
        ]
        let after = MojiLearnPlanner.applying(answers, to: [:], at: now)
        #expect(after["h-a"]?.strength == 0)
        #expect(after["h-a"]?.seen == 3)
        #expect(after["h-i"]?.strength == 1)
    }
}

@Suite("Learn grading")
struct MojiLearnGradingTests {
    private let catalog = MojiAlphabetCatalog.shared

    private func characters(_ ids: [String]) -> [MojiCharacter] {
        ids.compactMap { catalog.character($0) }
    }

    @Test("Typed romaji accepts Hepburn, Kunrei and the id spellings")
    func spellings() {
        #expect(MojiLearnGrading.accepts("shi", characters: characters(["h-shi"])))
        #expect(MojiLearnGrading.accepts("si", characters: characters(["h-shi"])))
        #expect(MojiLearnGrading.accepts("TSU", characters: characters(["h-tsu"])))
        #expect(MojiLearnGrading.accepts("wo", characters: characters(["h-wo"])))
        #expect(MojiLearnGrading.accepts("o", characters: characters(["h-wo"])))
        #expect(MojiLearnGrading.accepts("kya ja", characters: characters(["h-kya", "h-ja"])))
        #expect(MojiLearnGrading.accepts("nna", characters: characters(["h-n", "h-na"])))
        #expect(!MojiLearnGrading.accepts("ka", characters: characters(["h-ka", "h-sa"])))
    }

    @Test("A wrong string marks only the characters that did not line up")
    func perCharacterGrading() {
        #expect(MojiLearnGrading.gradeTyped("kaso", characters: characters(["h-ka", "h-sa"])) == [true, false])
        #expect(MojiLearnGrading.gradeTyped("kasono", characters: characters(["h-ka", "h-sa", "h-no"])) == [true, false, true])
        #expect(MojiLearnGrading.gradeTyped("kasaa", characters: characters(["h-ka", "h-sa"])) == [true, false])
        #expect(MojiLearnGrading.gradeTyped("", characters: characters(["h-ka"])) == [false])
    }
}
