import Foundation

struct MojiLearnPlanner: Sendable {
    static let shared = MojiLearnPlanner(catalog: .shared)

    static let batchTarget = 5
    static let solidAverage = 3
    static let solidFloor = 2
    static let lessonLength = 12...15
    static let optionCount = 4
    static let minimumOptionCount = 3
    static let matchSize = 5
    static let maxAppearances = 4
    static let hardMinimumStrength = 2
    static let maxRetriesPerItem = 2
    static let maxRetriesPerLesson = 6

    let catalog: MojiAlphabetCatalog
    private let batchesByPage: [MojiPage: [MojiLearnBatch]]

    init(catalog: MojiAlphabetCatalog) {
        self.catalog = catalog
        var batches: [MojiPage: [MojiLearnBatch]] = [:]
        for page in catalog.pages {
            batches[page] = Self.makeBatches(page: page, catalog: catalog)
        }
        batchesByPage = batches
    }

    func batches(_ page: MojiPage) -> [MojiLearnBatch] {
        batchesByPage[page] ?? []
    }

    func batch(_ id: String, on page: MojiPage) -> MojiLearnBatch? {
        batches(page).first { $0.id == id }
    }

    static func makeBatches(page: MojiPage, catalog: MojiAlphabetCatalog) -> [MojiLearnBatch] {
        if page.isKanji {
            let groups = evenChunks(catalog.pool(page).map(\.id), target: batchTarget)
            return groups.enumerated().map { index, ids in
                MojiLearnBatch(
                    id: "\(page.rawValue)#\(index)",
                    index: index,
                    page: page,
                    sectionID: page.rawValue,
                    characterIDs: ids
                )
            }
        }
        var result: [MojiLearnBatch] = []
        for section in catalog.sections(page) {
            for (ordinal, ids) in packRows(rows(of: section)).enumerated() where !ids.isEmpty {
                result.append(
                    MojiLearnBatch(
                        id: "\(section.id)#\(ordinal)",
                        index: result.count,
                        page: page,
                        sectionID: section.id,
                        characterIDs: ids
                    )
                )
            }
        }
        return result
    }

    static func rows(of section: MojiCharacterSection) -> [[String]] {
        let columns = max(1, section.columns)
        var rows: [[String]] = []
        var start = 0
        while start < section.slots.count {
            let end = min(start + columns, section.slots.count)
            let ids = section.slots[start..<end].compactMap { slot -> String? in
                guard case .character(let character) = slot else { return nil }
                return character.id
            }
            if !ids.isEmpty {
                rows.append(ids)
            }
            start = end
        }
        return rows
    }

    static func packRows(_ rows: [[String]]) -> [[String]] {
        var batches: [[String]] = []
        var current: [String] = []
        for row in rows {
            if current.isEmpty {
                current = row
            } else if current.count < batchTarget, current.count + row.count <= batchTarget + 1 {
                current += row
            } else {
                batches.append(current)
                current = row
            }
        }
        if !current.isEmpty {
            if current.count < 3, let last = batches.last, last.count + current.count <= batchTarget + 2 {
                batches[batches.count - 1] += current
            } else {
                batches.append(current)
            }
        }
        return batches
    }

    static func evenChunks(_ ids: [String], target: Int) -> [[String]] {
        guard !ids.isEmpty else { return [] }
        let count = max(1, Int((Double(ids.count) / Double(target)).rounded()))
        let base = ids.count / count
        let extra = ids.count % count
        var chunks: [[String]] = []
        var start = 0
        for index in 0..<count {
            let size = base + (index < extra ? 1 : 0)
            chunks.append(Array(ids[start..<(start + size)]))
            start += size
        }
        return chunks
    }

    static func isSolid(_ strengths: [Int]) -> Bool {
        guard let floor = strengths.min() else { return true }
        let total = strengths.reduce(0, +)
        return floor >= solidFloor && total >= solidAverage * strengths.count
    }

    static func effectiveIntroduced(
        _ introducedIDs: Set<String>,
        progress: [String: MojiCharacterProgress]
    ) -> Set<String> {
        introducedIDs.filter { id in
            guard let entry = progress[id] else { return false }
            return entry.seen > 0 || entry.strength > 0
        }
    }

    func path(
        page: MojiPage,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState
    ) -> MojiLearnPath {
        let batches = batches(page)
        let introduced = Self.effectiveIntroduced(Set(state.introducedIDs), progress: progress)
        let fresh = introduced.intersection(state.freshIDs)

        var done: [Bool] = []
        var started: [Bool] = []
        var masteries: [Double] = []
        for batch in batches {
            let strengths = batch.characterIDs.map { Self.strength(of: $0, in: progress) }
            let isFresh = batch.characterIDs.contains { fresh.contains($0) }
            done.append(!isFresh && Self.isSolid(strengths))
            started.append(batch.characterIDs.contains { introduced.contains($0) })
            let fill = batch.characterIDs.reduce(0.0) { sum, id in
                sum + MojiCharacterProgress.mastery(
                    strength: Self.strength(of: id, in: progress),
                    isWritten: progress[id]?.isWritten ?? false
                )
            }
            masteries.append(batch.characterIDs.isEmpty ? 1 : fill / Double(batch.characterIDs.count))
        }

        let currentIndex = batches.indices.first { !done[$0] }

        let states = batches.enumerated().map { index, batch in
            let status: MojiLearnBatchStatus
            if done[index] {
                status = .learned
            } else if index == currentIndex {
                status = .current
            } else if started[index] {
                status = .review
            } else {
                status = .new
            }
            return MojiLearnBatchState(batch: batch, status: status, mastery: masteries[index])
        }
        return MojiLearnPath(page: page, batches: states, currentIndex: currentIndex)
    }

    func upcomingNewIDs(
        path: MojiLearnPath,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState
    ) -> [String] {
        guard let current = path.current else { return [] }
        return newIDs(in: current.batch, progress: progress, state: state)
    }

    func newIDs(
        in batch: MojiLearnBatch,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState
    ) -> [String] {
        let introduced = Self.effectiveIntroduced(Set(state.introducedIDs), progress: progress)
        return batch.characterIDs.filter { id in
            !introduced.contains(id) && Self.strength(of: id, in: progress) < Self.solidAverage
        }
    }

    func metIDs(
        page: MojiPage,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState
    ) -> Set<String> {
        let introduced = Self.effectiveIntroduced(Set(state.introducedIDs), progress: progress)
        return Set(catalog.pool(page).map(\.id).filter { id in
            introduced.contains(id) || Self.strength(of: id, in: progress) > 0
        })
    }

    static func strength(of id: String, in progress: [String: MojiCharacterProgress]) -> Int {
        progress[id]?.strength ?? 0
    }

    static func halfLifeDays(strength: Int) -> Double {
        pow(2, Double(min(max(strength, 0), MojiCharacterProgress.masteryLevel)) - 2)
    }

    static func recall(_ entry: MojiCharacterProgress?, now: Date) -> Double {
        guard let entry, let lastSeen = entry.lastSeenAt else { return 0 }
        let days = max(0, now.timeIntervalSince(lastSeen)) / 86_400
        return pow(2, -days / halfLifeDays(strength: entry.strength))
    }

    static func isDue(_ entry: MojiCharacterProgress?, now: Date) -> Bool {
        guard let entry, entry.strength > 0 else { return true }
        return recall(entry, now: now) <= 0.5
    }

    func reviewPool(
        path: MojiLearnPath,
        focusIndex: Int?,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState
    ) -> [String] {
        let introduced = Self.effectiveIntroduced(Set(state.introducedIDs), progress: progress)
        return path.batches
            .filter { entry in
                entry.batch.index != focusIndex
                    && (entry.status == .learned || entry.batch.characterIDs.contains(where: introduced.contains))
            }
            .flatMap(\.batch.characterIDs)
    }

    func pickReview<R: RandomNumberGenerator>(
        pool: [String],
        progress: [String: MojiCharacterProgress],
        now: Date,
        count: Int,
        fillWithAnything: Bool,
        using generator: inout R
    ) -> [String] {
        guard count > 0, !pool.isEmpty else { return [] }

        let ranked = pool.map { id in
            ReviewRank(
                id: id,
                isDue: Self.isDue(progress[id], now: now),
                recall: Self.recall(progress[id], now: now),
                strength: Self.strength(of: id, in: progress),
                tiebreak: generator.next()
            )
        }
        .sorted { lhs, rhs in
            if lhs.recall != rhs.recall { return lhs.recall < rhs.recall }
            if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
            return lhs.tiebreak < rhs.tiebreak
        }

        var picked = ranked.filter(\.isDue).prefix(count).map(\.id)
        if picked.count < count {
            let filler = ranked.filter { entry in
                !entry.isDue && (fillWithAnything || entry.strength < MojiCharacterProgress.masteryLevel)
            }
            picked += filler.prefix(count - picked.count).map(\.id)
        }
        return picked
    }

    private struct ReviewRank {
        let id: String
        let isDue: Bool
        let recall: Double
        let strength: Int
        let tiebreak: UInt64
    }

    static func targetLength(newCount: Int) -> Int {
        min(lessonLength.upperBound, lessonLength.lowerBound + min(3, (newCount + 1) / 2))
    }

    func makeLesson<R: RandomNumberGenerator>(
        page: MojiPage,
        progress: [String: MojiCharacterProgress],
        state: MojiLearnPageState,
        now: Date,
        batchIndex: Int? = nil,
        id: UUID = UUID(),
        using generator: inout R
    ) -> MojiLesson? {
        let path = path(page: page, progress: progress, state: state)
        guard !path.batches.isEmpty else { return nil }

        let focus: MojiLearnBatch?
        if let batchIndex {
            guard path.batches.indices.contains(batchIndex) else { return nil }
            focus = path.batches[batchIndex].batch
        } else {
            focus = path.current?.batch
        }
        let newIDs = focus.map { self.newIDs(in: $0, progress: progress, state: state) } ?? []
        let newSet = Set(newIDs)
        let metBefore = metIDs(page: page, progress: progress, state: state)
        let oldFocusIDs = (focus?.characterIDs ?? [])
            .filter { !newSet.contains($0) }
            .sorted { Self.strength(of: $0, in: progress) < Self.strength(of: $1, in: progress) }
        let reviewable = reviewPool(path: path, focusIndex: focus?.index, progress: progress, state: state)
            .filter { metBefore.contains($0) }

        let reviewCount: Int
        if focus == nil {
            reviewCount = 8
        } else if newIDs.count >= 4 {
            reviewCount = 2
        } else if !newIDs.isEmpty {
            reviewCount = 3
        } else {
            reviewCount = 5
        }
        var reviewIDs = pickReview(
            pool: reviewable,
            progress: progress,
            now: now,
            count: reviewCount,
            fillWithAnything: focus == nil,
            using: &generator
        )

        let met = catalog.pool(page).filter { metBefore.contains($0.id) || newSet.contains($0.id) }

        var builder = LessonBuilder(
            planner: self,
            progress: progress,
            met: met
        )

        let intros = newIDs.map { MojiLessonItem(step: .intro(characterID: $0)) }
        var checks: [MojiLessonItem] = []
        for id in newIDs {
            if let check = builder.firstCheck(id, using: &generator) {
                checks.append(check)
            }
        }
        checks.shuffle(using: &generator)
        let opening = intros + Self.separatingRepeats(checks, after: intros.last)

        let entries = Self.entries(
            newIDs: newIDs,
            oldFocusIDs: oldFocusIDs,
            reviewIDs: reviewIDs,
            hasFocus: focus != nil
        )
        let budget = max(0, Self.targetLength(newCount: newIDs.count) - opening.count)
        var optional: [MojiLessonItem] = []
        for entry in entries where optional.count < budget {
            if let item = builder.item(
                for: entry,
                newIDs: newIDs,
                oldFocusIDs: oldFocusIDs,
                reviewIDs: reviewIDs,
                using: &generator
            ) {
                optional.append(item)
            }
        }

        let drillable = (oldFocusIDs + newIDs + reviewIDs).sorted {
            Self.strength(of: $0, in: progress) < Self.strength(of: $1, in: progress)
        }
        var filling = true
        while optional.count < budget, filling {
            filling = false
            for id in drillable where optional.count < budget {
                guard builder.canAppear(id), let item = builder.medium(id, using: &generator) else { continue }
                optional.append(item)
                filling = true
            }
        }

        if optional.count < budget {
            let extra = pickReview(
                pool: reviewable.filter { !reviewIDs.contains($0) },
                progress: progress,
                now: now,
                count: budget - optional.count,
                fillWithAnything: true,
                using: &generator
            )
            for id in extra where optional.count < budget {
                guard let item = builder.byStrength(id, using: &generator) else { continue }
                optional.append(item)
                reviewIDs.append(id)
            }
        }

        let hardItems = makeHard(
            in: &optional,
            builder: &builder,
            candidates: (oldFocusIDs + reviewIDs).filter {
                Self.strength(of: $0, in: progress) >= Self.hardMinimumStrength
            },
            limit: newIDs.isEmpty ? 2 : 1,
            using: &generator
        )

        var middle = optional.filter { item in
            switch item.step.kind {
            case .choice, .listen: true
            default: false
            }
        }
        middle.shuffle(using: &generator)
        middle = Self.separatingRepeats(middle, after: opening.last)

        let match = optional.filter { $0.step.kind == .match }
        var closing = optional.filter { item in
            switch item.step.kind {
            case .word, .read: true
            default: false
            }
        }
        closing.shuffle(using: &generator)
        var hardTail = hardItems
        hardTail.shuffle(using: &generator)

        let items = opening + middle + match + closing + hardTail
        guard !items.isEmpty else { return nil }

        return MojiLesson(
            id: id,
            page: page,
            batchIndex: focus?.index,
            newCharacterIDs: newIDs,
            reviewCharacterIDs: reviewIDs,
            items: items
        )
    }

    static func applying(
        _ answers: [MojiLessonAnswer],
        to progress: [String: MojiCharacterProgress],
        at date: Date
    ) -> [String: MojiCharacterProgress] {
        var result = progress
        for answer in answers {
            result[answer.characterID] = (result[answer.characterID] ?? .fresh)
                .recording(correct: answer.isCorrect, at: date, steps: answer.steps)
        }
        return result
    }

    func retry<R: RandomNumberGenerator>(of item: MojiLessonItem, using generator: inout R) -> MojiLessonItem {
        let step: MojiLessonStep
        switch item.step {
        case .choice(let id, let direction, let optionIDs):
            step = .choice(characterID: id, direction: direction, optionIDs: optionIDs.shuffled(using: &generator))
        case .listen(let id, let optionIDs):
            step = .listen(characterID: id, optionIDs: optionIDs.shuffled(using: &generator))
        case .match(let leftIDs, let rightIDs):
            step = .match(
                leftIDs: leftIDs.shuffled(using: &generator),
                rightIDs: rightIDs.shuffled(using: &generator)
            )
        case .word(let ids, .choose(let options)):
            step = .word(characterIDs: ids, mode: .choose(options: options.shuffled(using: &generator)))
        case .intro, .word, .read:
            step = item.step
        }
        return MojiLessonItem(step: step, isHard: false, isRetry: true)
    }

    enum Entry: Equatable {
        case match
        case word
        case newCharacter(Int)
        case focus(Int)
        case review(Int)
    }

    static func entries(
        newIDs: [String],
        oldFocusIDs: [String],
        reviewIDs: [String],
        hasFocus: Bool
    ) -> [Entry] {
        var result: [Entry] = []
        if !hasFocus {
            for index in reviewIDs.indices {
                result.append(.review(index))
                switch index {
                case 1: result.append(.match)
                case 3: result.append(.word)
                default: break
                }
            }
            if reviewIDs.count < 2 { result += [.match, .word] }
            return result
        }

        result.append(.match)
        result += oldFocusIDs.indices.map { .focus($0) }
        if !newIDs.isEmpty {
            for index in 0..<max(newIDs.count, reviewIDs.count) {
                if index < reviewIDs.count { result.append(.review(index)) }
                if index < newIDs.count { result.append(.newCharacter(index)) }
                if index == 0 { result.append(.word) }
            }
        } else {
            for index in reviewIDs.indices {
                result.append(.review(index))
                if index == 0 { result.append(.word) }
            }
            if reviewIDs.isEmpty { result.append(.word) }
        }
        return result
    }

    private func makeHard<R: RandomNumberGenerator>(
        in optional: inout [MojiLessonItem],
        builder: inout LessonBuilder,
        candidates: [String],
        limit: Int,
        using generator: inout R
    ) -> [MojiLessonItem] {
        var hard: [MojiLessonItem] = []
        var used: Set<String> = []
        for id in candidates where hard.count < limit && !used.contains(id) {
            guard let index = optional.firstIndex(where: { item in
                switch item.step {
                case .choice(let target, _, _), .listen(let target, _): target == id
                default: false
                }
            }) else { continue }
            optional.remove(at: index)
            hard.append(builder.read(id, using: &generator))
            used.insert(id)
        }
        return hard
    }

    static func separatingRepeats(_ items: [MojiLessonItem], after previous: MojiLessonItem?) -> [MojiLessonItem] {
        var result = items
        func shares(_ lhs: MojiLessonItem, _ rhs: MojiLessonItem) -> Bool {
            !Set(lhs.step.characterIDs).isDisjoint(with: rhs.step.characterIDs)
        }
        for index in result.indices {
            guard let before = index == 0 ? previous : result[index - 1],
                  shares(before, result[index]) else { continue }
            if let swap = result.indices.dropFirst(index + 1).first(where: { !shares(before, result[$0]) }) {
                result.swapAt(index, swap)
            }
        }
        return result
    }
}

struct LessonBuilder {
    let planner: MojiLearnPlanner
    let progress: [String: MojiCharacterProgress]
    let met: [MojiCharacter]
    let metIDs: Set<String>

    private(set) var appearances: [String: Int] = [:]

    init(planner: MojiLearnPlanner, progress: [String: MojiCharacterProgress], met: [MojiCharacter]) {
        self.planner = planner
        self.progress = progress
        self.met = met
        metIDs = Set(met.map(\.id))
    }

    private var catalog: MojiAlphabetCatalog { planner.catalog }

    func canAppear(_ id: String) -> Bool {
        (appearances[id] ?? 0) < MojiLearnPlanner.maxAppearances
    }

    private func strength(_ id: String) -> Int {
        MojiLearnPlanner.strength(of: id, in: progress)
    }

    private mutating func count(_ ids: [String]) {
        for id in ids {
            appearances[id, default: 0] += 1
        }
    }

    mutating func item<R: RandomNumberGenerator>(
        for entry: MojiLearnPlanner.Entry,
        newIDs: [String],
        oldFocusIDs: [String],
        reviewIDs: [String],
        using generator: inout R
    ) -> MojiLessonItem? {
        switch entry {
        case .newCharacter(let index):
            let id = newIDs[index]
            return canAppear(id) ? medium(id, using: &generator) : nil
        case .focus(let index):
            let id = oldFocusIDs[index]
            return canAppear(id) ? byStrength(id, using: &generator) : nil
        case .review(let index):
            let id = reviewIDs[index]
            return canAppear(id) ? byStrength(id, using: &generator) : nil
        case .match:
            return match(preferring: newIDs + oldFocusIDs + reviewIDs, using: &generator)
        case .word:
            return word(preferring: newIDs + oldFocusIDs + reviewIDs, using: &generator)
        }
    }

    mutating func firstCheck<R: RandomNumberGenerator>(_ id: String, using generator: inout R) -> MojiLessonItem? {
        if let item = choice(id, direction: .glyphToAnswer, using: &generator) {
            return item
        }
        return listen(id, using: &generator)
    }

    mutating func byStrength<R: RandomNumberGenerator>(_ id: String, using generator: inout R) -> MojiLessonItem? {
        if strength(id) <= 1, Bool.random(using: &generator),
           let item = choice(id, direction: .glyphToAnswer, using: &generator) {
            return item
        }
        return medium(id, using: &generator)
    }

    mutating func medium<R: RandomNumberGenerator>(_ id: String, using generator: inout R) -> MojiLessonItem? {
        guard let character = catalog.character(id), !catalog.requiresGlyphPrompt(character) else {
            return choice(id, direction: .glyphToAnswer, using: &generator)
        }
        if Bool.random(using: &generator) {
            if let item = listen(id, using: &generator) {
                return item
            }
            return choice(id, direction: .answerToGlyph, using: &generator)
        }
        if let item = choice(id, direction: .answerToGlyph, using: &generator) {
            return item
        }
        return listen(id, using: &generator)
    }

    mutating func choice<R: RandomNumberGenerator>(
        _ id: String,
        direction: MojiLessonDirection,
        using generator: inout R
    ) -> MojiLessonItem? {
        guard metIDs.contains(id),
              let answer = catalog.character(id),
              let optionIDs = options(for: answer, key: \.optionKey, using: &generator) else { return nil }
        count([id])
        let resolved = catalog.requiresGlyphPrompt(answer) ? .glyphToAnswer : direction
        return MojiLessonItem(step: .choice(characterID: id, direction: resolved, optionIDs: optionIDs))
    }

    mutating func listen<R: RandomNumberGenerator>(_ id: String, using generator: inout R) -> MojiLessonItem? {
        guard let answer = catalog.character(id), !catalog.requiresGlyphPrompt(answer) else {
            return choice(id, direction: .glyphToAnswer, using: &generator)
        }
        guard metIDs.contains(id),
              let optionIDs = options(for: answer, key: Self.soundKey, using: &generator) else { return nil }
        count([id])
        return MojiLessonItem(step: .listen(characterID: id, optionIDs: optionIDs))
    }

    mutating func match<R: RandomNumberGenerator>(preferring ids: [String], using generator: inout R) -> MojiLessonItem? {
        var chosen: [MojiCharacter] = []
        var labels: Set<String> = []
        var glyphs: Set<String> = []
        let pool = ids.filter { metIDs.contains($0) }.compactMap { catalog.character($0) } + met.shuffled(using: &generator)
        for character in pool where chosen.count < MojiLearnPlanner.matchSize {
            let label = Self.matchLabel(character)
            guard !chosen.contains(where: { $0.id == character.id }),
                  !labels.contains(label),
                  !glyphs.contains(character.glyph) else { continue }
            chosen.append(character)
            labels.insert(label)
            glyphs.insert(character.glyph)
        }
        guard chosen.count >= 3 else { return nil }
        count(chosen.map(\.id))
        return MojiLessonItem(
            step: .match(
                leftIDs: chosen.map(\.id).shuffled(using: &generator),
                rightIDs: chosen.map(\.id).shuffled(using: &generator)
            )
        )
    }

    mutating func word<R: RandomNumberGenerator>(preferring ids: [String], using generator: inout R) -> MojiLessonItem? {
        let anchors = ids.filter { metIDs.contains($0) }.compactMap { catalog.character($0) }
        guard let anchor = anchors.min(by: { strength($0.id) < strength($1.id) }) else { return nil }

        let strongest = anchors.map { strength($0.id) }.max() ?? 0
        let length = strongest >= 4 ? 3 : 2
        var characters = [anchor]
        for candidate in (anchors + met).shuffled(using: &generator) where characters.count < length {
            guard !characters.contains(where: { $0.id == candidate.id }) else { continue }
            characters.append(candidate)
        }
        guard characters.count >= 2 else { return nil }
        characters.shuffle(using: &generator)
        let ids = characters.map(\.id)

        let typable = !anchor.script.isKanji && characters.allSatisfy { strength($0.id) >= 1 }
        if typable, Int.random(in: 0..<10, using: &generator) < 7 {
            count(ids)
            return MojiLessonItem(step: .word(characterIDs: ids, mode: .type))
        }

        var options: [[String]] = [ids]
        var sounds: Set<String> = [characters.map(Self.soundKey).joined(separator: "|")]
        var spellings: Set<String> = [characters.map(\.glyph).joined()]
        var attempts = 0
        while options.count < 4, attempts < 24 {
            attempts += 1
            let position = Int.random(in: 0..<characters.count, using: &generator)
            let original = characters[position]
            let lookAlikes = catalog.lookAlikes(of: original).filter { metIDs.contains($0.id) }
            let swaps = (lookAlikes.shuffled(using: &generator) + met.shuffled(using: &generator))
                .filter { $0.id != original.id && Self.soundKey($0) != Self.soundKey(original) }
            guard let swap = swaps.first else { continue }
            var decoy = characters
            decoy[position] = swap
            guard sounds.insert(decoy.map(Self.soundKey).joined(separator: "|")).inserted,
                  spellings.insert(decoy.map(\.glyph).joined()).inserted else { continue }
            options.append(decoy.map(\.id))
        }
        guard options.count >= 3 else { return nil }
        count(ids)
        return MojiLessonItem(step: .word(characterIDs: ids, mode: .choose(options: options.shuffled(using: &generator))))
    }

    mutating func read<R: RandomNumberGenerator>(_ id: String, using generator: inout R) -> MojiLessonItem {
        guard let anchor = catalog.character(id), !anchor.script.isKanji else {
            count([id])
            return MojiLessonItem(step: .read(characterIDs: [id]), isHard: true)
        }
        var characters = [anchor]
        let strongPartners = met
            .filter { $0.id != id && strength($0.id) >= MojiLearnPlanner.hardMinimumStrength }
            .shuffled(using: &generator)
        if let partner = strongPartners.first, Bool.random(using: &generator) {
            characters.append(partner)
            characters.shuffle(using: &generator)
        }
        count([id])
        return MojiLessonItem(step: .read(characterIDs: characters.map(\.id)), isHard: true)
    }

    private func options<R: RandomNumberGenerator>(
        for answer: MojiCharacter,
        key: (MojiCharacter) -> String,
        using generator: inout R
    ) -> [String]? {
        var optionIDs = distractors(for: answer, key: key, using: &generator).map(\.id)
        guard optionIDs.count + 1 >= MojiLearnPlanner.minimumOptionCount else { return nil }
        optionIDs.append(answer.id)
        optionIDs.shuffle(using: &generator)
        return optionIDs
    }

    private func distractors<R: RandomNumberGenerator>(
        for answer: MojiCharacter,
        key: (MojiCharacter) -> String,
        using generator: inout R
    ) -> [MojiCharacter] {
        let wanted = MojiLearnPlanner.optionCount - 1
        var chosen: [MojiCharacter] = []
        var usedKeys: Set<String> = [key(answer)]
        var usedGlyphs: Set<String> = [answer.glyph]

        func take(_ candidate: MojiCharacter) {
            guard chosen.count < wanted,
                  candidate.id != answer.id,
                  candidate.script == answer.script,
                  !usedKeys.contains(key(candidate)),
                  !usedGlyphs.contains(candidate.glyph) else { return }
            chosen.append(candidate)
            usedKeys.insert(key(candidate))
            usedGlyphs.insert(candidate.glyph)
        }

        let lookAlikes = catalog.lookAlikes(of: answer).filter { metIDs.contains($0.id) }
        if let first = lookAlikes.randomElement(using: &generator) {
            take(first)
        }
        for candidate in met.shuffled(using: &generator) where chosen.count < wanted {
            take(candidate)
        }
        return chosen
    }

    static func matchLabel(_ character: MojiCharacter) -> String {
        character.shortMeaning ?? character.romaji
    }

    static func soundKey(_ character: MojiCharacter) -> String {
        if character.script.isKanji {
            return character.speech
        }
        switch character.romaji {
        case "ou": return "oo"
        case "ei": return "ee"
        default: return character.romaji
        }
    }
}
