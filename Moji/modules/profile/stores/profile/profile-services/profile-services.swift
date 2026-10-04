import Foundation
import Observation

private struct ContributionGraphCache {
    let year: Int
    let todayKey: String
    let dayCounts: [String: Int]
    let model: ContributionGraphModel
}

@MainActor
@Observable
final class ProfileServicesStore {
    static let shared = ProfileServicesStore()

    var selectedYear: Int
    var selectedDayKey: String?
    var isSettingsPresented = false
    var isResetConfirmPresented = false

    @ObservationIgnored private var graphCache: ContributionGraphCache?

    private init() {
        selectedYear = Calendar.current.component(.year, from: Date())
    }

    var snapshot: MojiPracticeRepositorySnapshot {
        MojiPracticePresentation.shared.snapshot
    }

    var activity: MojiActivitySummary {
        snapshot.activity
    }

    var years: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array(min(activity.firstYear, current)...current)
    }

    var overallAccuracy: Double? {
        guard snapshot.totalAnswers > 0 else { return nil }
        return Double(snapshot.totalCorrect) / Double(snapshot.totalAnswers)
    }

    func stats(for page: MojiPage) -> MojiPageStats {
        snapshot.pageStats[page] ?? .empty(total: MojiAlphabetCatalog.shared.pool(page).count)
    }

    func stats(for script: MojiScript) -> MojiPageStats {
        let all = MojiAlphabetCatalog.shared.pages(script).map { stats(for: $0) }
        return MojiPageStats(
            total: all.reduce(0) { $0 + $1.total },
            practiced: all.reduce(0) { $0 + $1.practiced },
            mastered: all.reduce(0) { $0 + $1.mastered }
        )
    }

    var kanjiThemes: [MojiKanjiTheme] {
        MojiAlphabetCatalog.shared.pages(.kanji).compactMap(\.theme)
    }

    func graph() -> ContributionGraphModel {
        let year = selectedYear
        let todayKey = activity.todayKey
        let dayCounts = activity.dayCounts

        if let cache = graphCache,
           cache.year == year,
           cache.todayKey == todayKey,
           cache.dayCounts == dayCounts {
            return cache.model
        }

        let model = ContributionGraphBuilder.build(
            year: year,
            dayCounts: dayCounts,
            now: Date(),
            calendar: Calendar.current
        )
        graphCache = ContributionGraphCache(
            year: year,
            todayKey: todayKey,
            dayCounts: dayCounts,
            model: model
        )
        return model
    }

    func week() -> [ProfileWeekDay] {
        ProfileWeekBuilder.build(
            dayCounts: activity.dayCounts,
            now: Date(),
            calendar: Calendar.current
        )
    }

    func selectedDay(in graph: ContributionGraphModel) -> ContributionDay? {
        guard let selectedDayKey else { return nil }
        return graph.day(forKey: selectedDayKey)
    }
}
