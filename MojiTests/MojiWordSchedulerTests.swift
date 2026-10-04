import Foundation
import Testing
@testable import Moji

@Suite("Words scheduler (Anki SM-2)")
struct MojiWordSchedulerTests {
    private let id = MojiWordCardID(wordID: "w1358280")
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func context(
        _ options: MojiWordOptions = .standard,
        today: Int = 1_000,
        hoursLeftToday: Double = 12
    ) -> MojiWordSchedulingContext {
        MojiWordSchedulingContext(
            options: options,
            today: today,
            now: now,
            nextDayStartsAt: now.addingTimeInterval(hoursLeftToday * 3_600)
        )
    }

    private func review(interval: Int, ease: Int = 2_500, dueDay: Int = 1_000, lapses: Int = 0, reps: Int = 5) -> MojiWordCard {
        var card = MojiWordCard()
        card.phase = .review
        card.interval = interval
        card.easeFactor = ease
        card.dueDay = dueDay
        card.lapses = lapses
        card.reps = reps
        return card
    }

    private func answer(_ card: MojiWordCard, _ button: MojiWordButton, _ context: MojiWordSchedulingContext? = nil) -> MojiWordOutcome {
        MojiWordScheduler.answer(card, id: id, button: button, context: context ?? self.context())
    }

    @Test("The defaults are Anki's")
    func defaults() {
        let options = MojiWordOptions.standard
        #expect(options.newPerDay == 20)
        #expect(options.reviewsPerDay == 200)
        #expect(options.learningSteps == [1, 10])
        #expect(options.relearningSteps == [10])
        #expect(options.graduatingInterval == 1)
        #expect(options.easyInterval == 4)
        #expect(options.startingEase == 2.5)
        #expect(options.easyBonus == 1.3)
        #expect(options.hardInterval == 1.2)
        #expect(options.newInterval == 0)
        #expect(options.minimumInterval == 1)
        #expect(options.maximumInterval == 36_500)
        #expect(options.leechThreshold == 8)
        #expect(options.dayStartsAtHour == 4)
        #expect(MojiWordScheduler.minimumEaseFactor == 1_300)
        #expect(MojiWordScheduler.againEaseDelta == -200)
        #expect(MojiWordScheduler.hardEaseDelta == -150)
        #expect(MojiWordScheduler.easyEaseDelta == 150)
        #expect(MojiWordScheduler.matureInterval == 21)
    }

    @Test("A new card: Again 1 min, Hard 5.5 min, Good 10 min, Easy about 4 days")
    func newCard() {
        let fresh = MojiWordCard.fresh

        let again = answer(fresh, .again)
        #expect(again.delay == .seconds(60))
        #expect(again.card.phase == .learning)
        #expect(again.card.remainingSteps == 2)

        let hard = answer(fresh, .hard)
        #expect(hard.delay == .seconds(330))
        #expect(hard.card.phase == .learning)
        #expect(hard.card.remainingSteps == 2)

        let good = answer(fresh, .good)
        #expect(good.delay == .seconds(600))
        #expect(good.card.phase == .learning)
        #expect(good.card.remainingSteps == 1)
        #expect(good.card.reps == 1)
        #expect(good.card.introducedDay == 1_000)
        #expect(good.card.dueAt == now.addingTimeInterval(600))

        let easy = answer(fresh, .easy)
        guard case .days(let days) = easy.delay else {
            Issue.record("Easy on a new card graduates")
            return
        }
        #expect((3...5).contains(days))
        #expect(easy.card.phase == .review)
        #expect(easy.card.interval == days)
        #expect(easy.card.easeFactor == 2_500)
        #expect(easy.card.dueDay == 1_000 + days)
    }

    @Test("A learning card on its last step: Again restarts, Hard repeats, Good graduates to 1 day")
    func lastLearningStep() {
        let step = answer(.fresh, .good).card

        let again = answer(step, .again)
        #expect(again.delay == .seconds(60))
        #expect(again.card.remainingSteps == 2)

        let hard = answer(step, .hard)
        #expect(hard.delay == .seconds(600))
        #expect(hard.card.remainingSteps == 1)

        let good = answer(step, .good)
        #expect(good.delay == .days(1))
        #expect(good.card.phase == .review)
        #expect(good.card.interval == 1)
        #expect(good.card.easeFactor == 2_500)
        #expect(good.card.remainingSteps == 0)

        let easy = answer(step, .easy)
        guard case .days(let days) = easy.delay else {
            Issue.record("Easy graduates")
            return
        }
        #expect((3...5).contains(days))
    }

    @Test("Hard on the first step is the middle of the first two steps, or 1.5 times a single step")
    func hardOnFirstStep() {
        #expect(MojiWordSteps(minutes: [1, 10]).hardDelay(remaining: 2) == 330)
        #expect(MojiWordSteps(minutes: [10]).hardDelay(remaining: 1) == 900)
        #expect(MojiWordSteps(minutes: [1, 10, 60]).hardDelay(remaining: 2) == 600)
        #expect(MojiWordSteps(minutes: [2_880]).hardDelay(remaining: 1) == 2_880 * 60 + 86_400)
        #expect(MojiWordSteps(minutes: []).hardDelay(remaining: 0) == nil)
    }

    @Test("Without learning steps a new card graduates at once")
    func noLearningSteps() {
        var options = MojiWordOptions.standard
        options.learningSteps = []
        let good = answer(.fresh, .good, context(options))
        #expect(good.delay == .days(1))
        #expect(good.card.phase == .review)
        let again = answer(.fresh, .again, context(options))
        #expect(again.card.phase == .review)
    }

    @Test("A review on time: Hard ×1.2, Good ×ease, Easy ×ease×1.3, with ease changes")
    func reviewOnTime() {
        let card = review(interval: 10)
        let hard = answer(card, .hard)
        let good = answer(card, .good)
        let easy = answer(card, .easy)

        #expect(MojiWordScheduler.fuzzBounds(12, minimum: 11, maximum: 36_500).contains(hard.card.interval))
        #expect(hard.card.easeFactor == 2_350)
        #expect(MojiWordScheduler.fuzzBounds(25, minimum: hard.card.interval + 1, maximum: 36_500).contains(good.card.interval))
        #expect(good.card.easeFactor == 2_500)
        #expect(MojiWordScheduler.fuzzBounds(32.5, minimum: good.card.interval + 1, maximum: 36_500).contains(easy.card.interval))
        #expect(easy.card.easeFactor == 2_650)
        #expect(hard.card.interval < good.card.interval)
        #expect(good.card.interval < easy.card.interval)
        #expect(good.card.dueDay == 1_000 + good.card.interval)
        #expect(good.card.reps == card.reps + 1)
        #expect(good.card.lapses == 0)
    }

    @Test("A late review counts half the delay for Good and all of it for Easy")
    func lateReview() {
        let card = review(interval: 10, dueDay: 996)
        let good = answer(card, .good)
        let easy = answer(card, .easy)
        #expect(MojiWordScheduler.fuzzBounds(30, minimum: 13, maximum: 36_500).contains(good.card.interval))
        #expect(MojiWordScheduler.fuzzBounds(45.5, minimum: good.card.interval + 1, maximum: 36_500).contains(easy.card.interval))
    }

    @Test("An early review uses Anki's early-review intervals without fuzz")
    func earlyReview() {
        let card = review(interval: 10, dueDay: 1_005)
        #expect(answer(card, .hard).card.interval == 6)
        #expect(answer(card, .good).card.interval == 13)
        #expect(answer(card, .easy).card.interval == 14)
    }

    @Test("A lapse: ease −20%, one more lapse, relearning in 10 min, new interval 1 day")
    func lapse() {
        let card = review(interval: 40, ease: 2_500, lapses: 2)
        let again = answer(card, .again)
        #expect(again.delay == .seconds(600))
        #expect(again.card.phase == .relearning)
        #expect(again.card.remainingSteps == 1)
        #expect(again.card.lapses == 3)
        #expect(again.card.easeFactor == 2_300)
        #expect(again.card.interval == 1)
        #expect(!again.becameLeech)

        var options = MojiWordOptions.standard
        options.newInterval = 0.5
        options.minimumInterval = 3
        #expect(answer(card, .again, context(options)).card.interval == 20)
        options.newInterval = 0
        #expect(answer(card, .again, context(options)).card.interval == 3)
    }

    @Test("Relearning: Again 10 min, Hard 15 min, Good back to review, Easy one day more")
    func relearning() {
        let lapsed = answer(review(interval: 40), .again).card
        #expect(answer(lapsed, .again).delay == .seconds(600))
        let hard = answer(lapsed, .hard)
        #expect(hard.delay == .seconds(900))
        #expect(hard.card.phase == .relearning)
        let good = answer(lapsed, .good)
        #expect(good.delay == .days(1))
        #expect(good.card.phase == .review)
        #expect(good.card.easeFactor == 2_300)
        #expect(good.card.lapses == 1)
        let easy = answer(lapsed, .easy)
        #expect(easy.delay == .days(2))
        #expect(easy.card.phase == .review)
    }

    @Test("Ease never drops below 130%")
    func easeFloor() {
        let card = review(interval: 10, ease: 1_300)
        #expect(answer(card, .again).card.easeFactor == 1_300)
        #expect(answer(card, .hard).card.easeFactor == 1_300)
        #expect(answer(review(interval: 10, ease: 1_400), .hard).card.easeFactor == 1_300)
    }

    @Test("The maximum interval caps every button")
    func maximumInterval() {
        var options = MojiWordOptions.standard
        options.maximumInterval = 30
        let card = review(interval: 25)
        let context = context(options)
        for button in [MojiWordButton.hard, .good, .easy] {
            #expect(answer(card, button, context).card.interval <= 30, "\(button)")
        }
        #expect(answer(.fresh, .easy, context).card.interval <= 30)
    }

    @Test("Fuzz follows Anki's ranges", arguments: [
        (1.0, 1, 1), (2.0, 2, 2), (2.5, 2, 4), (4.0, 3, 5), (10.0, 8, 12), (30.0, 27, 33), (100.0, 93, 107)
    ])
    func fuzzRanges(interval: Double, lower: Int, upper: Int) {
        let bounds = MojiWordScheduler.fuzzBounds(interval, minimum: 1, maximum: 36_500)
        #expect(bounds == lower...upper)
        #expect(MojiWordScheduler.withFuzz(interval, minimum: 1, maximum: 36_500, factor: 0) == lower)
        #expect(MojiWordScheduler.withFuzz(interval, minimum: 1, maximum: 36_500, factor: 0.999_99) == upper)
    }

    @Test("Fuzz is the same for the button preview and the real answer, and it changes with each review")
    func fuzzIsStable() {
        let card = review(interval: 30)
        let preview = MojiWordScheduler.preview(card, id: id, context: context())
        let good = answer(card, .good)
        #expect(preview[.good] == .days(good.card.interval))

        var seen: Set<Int> = []
        for reps in 0..<40 {
            var variant = card
            variant.reps = reps
            let interval = answer(variant, .good).card.interval
            #expect(MojiWordScheduler.fuzzBounds(75, minimum: 37, maximum: 36_500).contains(interval))
            seen.insert(interval)
        }
        #expect(seen.count > 3)
        let factor = MojiWordFuzz.factor(for: id, reps: 3)
        #expect(factor >= 0 && factor < 1)
        #expect(factor == MojiWordFuzz.factor(for: id, reps: 3))
    }

    @Test("Learning steps get up to 25% more time, at most 5 minutes")
    func learningFuzz() {
        #expect(MojiWordScheduler.learningFuzzSeconds(60, fraction: 0) == 0)
        #expect(MojiWordScheduler.learningFuzzSeconds(60, fraction: 0.999_99) == 14)
        #expect(MojiWordScheduler.learningFuzzSeconds(600, fraction: 0.999_99) == 149)
        #expect(MojiWordScheduler.learningFuzzSeconds(3_600, fraction: 0.999_99) == 299)
        let fuzzed = MojiWordScheduler.answer(.fresh, id: id, button: .good, context: context(), learningFuzz: 0.5)
        #expect(fuzzed.delay == .seconds(600))
        #expect(fuzzed.card.dueAt == now.addingTimeInterval(675))
    }

    @Test("A learning step that crosses the day rollover becomes a day")
    func rolloverTurnsIntoDays() {
        let late = context(hoursLeftToday: 0.05)
        #expect(answer(.fresh, .good, late).delay == .days(1))
        let card = answer(.fresh, .good, late).card
        #expect(card.dueAt == nil)
        #expect(card.dueDay == 1_001)
        #expect(card.phase == .learning)
        #expect(answer(.fresh, .again, late).delay == .seconds(60))
    }

    @Test("Leeches: at the threshold, then every half threshold", arguments: [
        (7, 8, false), (8, 8, true), (9, 8, false), (12, 8, true), (16, 8, true), (13, 8, false),
        (5, 5, true), (8, 5, true), (11, 5, true), (6, 5, false), (3, 0, false), (1, 1, true), (2, 1, true)
    ])
    func leechThreshold(lapses: Int, threshold: Int, expected: Bool) {
        #expect(MojiWordScheduler.leechThresholdMet(lapses: lapses, threshold: threshold) == expected)
    }

    @Test("The eighth lapse tags a leech; the suspend action also suspends it")
    func leechActions() {
        let card = review(interval: 3, lapses: 7)
        let tagged = answer(card, .again)
        #expect(tagged.becameLeech)
        #expect(tagged.card.isLeech)
        #expect(!tagged.card.isSuspended)

        var options = MojiWordOptions.standard
        options.leechAction = .suspend
        let suspended = answer(card, .again, context(options))
        #expect(suspended.card.isLeech)
        #expect(suspended.card.isSuspended)
        #expect(suspended.card.phase == .relearning)
    }

    @Test("Intervals read like Anki on the buttons")
    func spans() {
        #expect(MojiWordSpan(.seconds(60)) == .minutes(1, isUpperBound: true))
        #expect(MojiWordSpan(.seconds(330)) == .minutes(6, isUpperBound: true))
        #expect(MojiWordSpan(.seconds(600)) == .minutes(10, isUpperBound: true))
        #expect(MojiWordSpan(.seconds(1_500)) == .minutes(25, isUpperBound: false))
        #expect(MojiWordSpan(.seconds(5_400)) == .hours(1.5, isUpperBound: false))
        #expect(MojiWordSpan(.days(1)) == .days(1))
        #expect(MojiWordSpan(.days(4)) == .days(4))
        #expect(MojiWordSpan(.days(45)) == .months(1.5))
        #expect(MojiWordSpan(.days(730)) == .years(2))
    }

    @Test("Mark as known makes a mature review due in 21 to 60 days; forget makes it new again")
    func manualChanges() {
        let known = MojiWordScheduler.knownCard(.fresh, id: id, context: context())
        #expect(known.phase == .review)
        #expect(known.isMature)
        #expect(MojiWordScheduler.knownIntervalRange.contains(known.interval))
        #expect(known.dueDay == 1_000 + known.interval)
        #expect(known.easeFactor == 2_500)

        var flagged = known
        flagged.flag = .green
        let forgotten = MojiWordScheduler.forgotten(flagged)
        #expect(forgotten.phase == .new)
        #expect(forgotten.flag == .green)
        #expect(forgotten.reps == 0)

        let moved = MojiWordScheduler.rescheduled(known, inDays: 3, context: context())
        #expect(moved.dueDay == 1_003)
        #expect(moved.interval == known.interval)
        let fromNew = MojiWordScheduler.rescheduled(.fresh, inDays: 5, context: context())
        #expect(fromNew.phase == .review)
        #expect(fromNew.interval == 5)
        #expect(fromNew.dueDay == 1_005)
    }

    @Test("Learning steps typed as text, in either language")
    func stepsText() {
        #expect(MojiWordStepsText.parse("1m 10m") == [1, 10])
        #expect(MojiWordStepsText.parse("1 10") == [1, 10])
        #expect(MojiWordStepsText.parse("30s, 5m; 1h 2d") == [0.5, 5, 60, 2_880])
        #expect(MojiWordStepsText.parse("1,5м 1ч") == [1.5, 60])
        #expect(MojiWordStepsText.parse("") == [])
        #expect(MojiWordStepsText.parse("ten minutes") == nil)
        #expect(MojiWordStepsText.parse("-1m") == nil)
        #expect(MojiWordStepsText.format([1, 10, 60, 1_440, 0.5]) == "1m 10m 1h 1d 30s")
        #expect(MojiWordStepsText.parse(MojiWordStepsText.format(MojiWordDefaults.learningSteps)) == MojiWordDefaults.learningSteps)
    }

    @Test("The study day starts at the chosen hour")
    func studyDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .current
        let late = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 3, minute: 30)) ?? Date()
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 4, minute: 30)) ?? Date()
        let before = MojiWordDay.index(of: late, startsAtHour: 4, calendar: calendar)
        let after = MojiWordDay.index(of: morning, startsAtHour: 4, calendar: calendar)
        #expect(after == before + 1)
        #expect(MojiWordDay.index(of: late, startsAtHour: 0, calendar: calendar) == after)
        let start = MojiWordDay.start(of: after, startsAtHour: 4, calendar: calendar)
        #expect(calendar.component(.hour, from: start) == 4)
        #expect(start <= morning && morning.timeIntervalSince(start) < 86_400)
    }
}
