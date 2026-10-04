import SwiftUI

struct MainTabs: View {
    private var router: MainTabRouter { .shared }

    var body: some View {
        let selection = Binding(
            get: { router.currentTab },
            set: { router.select($0) }
        )

        TabView(selection: selection) {
            Tab("Learn", systemImage: "graduationcap", value: MainTab.learn) {
                LearnPage()
            }
            Tab("Practice", systemImage: "dumbbell", value: MainTab.practice) {
                AlphabetPage()
            }
            Tab("Words", systemImage: "rectangle.stack", value: MainTab.words) {
                WordsPage()
            }
            Tab("Notes", systemImage: "note.text", value: MainTab.notes) {
                NotesPage()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: MainTab.profile) {
                ProfilePage()
            }
        }
    }
}
