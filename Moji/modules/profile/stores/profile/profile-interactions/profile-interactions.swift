import Foundation
import Observation

@MainActor
@Observable
final class ProfileInteractionsStore {
    static let shared = ProfileInteractionsStore()

    private var service: ProfileServicesStore { .shared }
    private var practiceActions: PracticeActionsStore { .shared }

    private init() {}

    func shiftYear(by delta: Int) {
        let years = service.years
        guard let index = years.firstIndex(of: service.selectedYear) else {
            service.selectedYear = years.last ?? service.selectedYear
            return
        }
        let next = index + delta
        guard years.indices.contains(next) else { return }
        service.selectedYear = years[next]
        service.selectedDayKey = nil
        MojiHaptics.selection()
    }

    func selectDay(_ day: ContributionDay) {
        guard !day.isFuture else { return }
        service.selectedDayKey = service.selectedDayKey == day.key ? nil : day.key
        MojiHaptics.selection()
    }

    func openSettings() {
        service.isSettingsPresented = true
    }

    func closeSettings() {
        service.isSettingsPresented = false
    }

    func setAppearance(_ preference: ThemeAppearancePreference) {
        ThemeStore.shared.setPreference(preference)
        MojiHaptics.selection()
    }

    func setSpeaksCharacters(_ value: Bool) {
        MojiPreferencesStore.shared.setSpeaksCharacters(value)
    }

    func requestReset() {
        MojiHaptics.selection()
        service.isResetConfirmPresented = true
    }

    func confirmReset() {
        service.isResetConfirmPresented = false
        practiceActions.resetProgressAction()
        LearnActionsStore.shared.resetAllAction()
        WordsActionsStore.shared.resetAllAction()
        MojiHaptics.impact()
    }

    func cancelReset() {
        service.isResetConfirmPresented = false
    }

    func openLearn() {
        MojiHaptics.selection()
        MainTabRouter.shared.select(.learn)
    }
}
