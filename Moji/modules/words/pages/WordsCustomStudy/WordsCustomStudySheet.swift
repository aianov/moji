import SwiftUI

struct WordsCustomStudySheet: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    private func field(_ keyPath: WritableKeyPath<WordsCustomStudyDraft, Int>) -> Binding<Int> {
        Binding(
            get: { service.customStudy[keyPath: keyPath] },
            set: { value in interactions.updateCustomStudy { $0[keyPath: keyPath] = value } }
        )
    }

    var body: some View {
        let deck = service.sheetDeck
        let draft = service.customStudy
        let counts = service.customStudyCounts
        let forgotten = counts[.forgotten(days: draft.forgottenDays)]?.total
        let ahead = counts[.reviewAhead(days: draft.aheadDays)]?.total
        let section = counts[.sectionOnly(draft.section)]
        let sections = service.catalog(deck).sections

        NavigationStack {
            Form {
                Section {
                    Stepper(value: field(\.extraNew), in: 5...200, step: 5) {
                        LabeledContent(String(localized: "More new cards"), value: "+\(draft.extraNew)")
                    }
                    Button(String(localized: "Raise today's new limit")) {
                        interactions.addExtraNew()
                    }
                    Stepper(value: field(\.extraReviews), in: 10...500, step: 10) {
                        LabeledContent(String(localized: "More reviews"), value: "+\(draft.extraReviews)")
                    }
                    Button(String(localized: "Raise today's review limit")) {
                        interactions.addExtraReviews()
                    }
                } header: {
                    Text("Today's limits")
                } footer: {
                    Text("Only for today. Tomorrow the usual limits from the deck options come back.")
                }

                Section {
                    Stepper(value: field(\.forgottenDays), in: 1...30) {
                        Text(WordsCustomStudyText.lastDays(draft.forgottenDays))
                    }
                    WordsCustomStudyStart(count: forgotten) {
                        interactions.startCustomStudy(.forgotten(days: draft.forgottenDays), deck: deck)
                    }
                } header: {
                    Text("Review forgotten cards")
                } footer: {
                    Text("Cards you pressed Again on. This extra round doesn't change when they come back.")
                }

                Section {
                    Stepper(value: field(\.aheadDays), in: 1...30) {
                        Text(WordsCustomStudyText.nextDays(draft.aheadDays))
                    }
                    WordsCustomStudyStart(count: ahead) {
                        interactions.startCustomStudy(.reviewAhead(days: draft.aheadDays), deck: deck)
                    }
                } header: {
                    Text("Review ahead")
                } footer: {
                    Text("Reviews due soon, studied now. Early answers grow the interval a little less, like in Anki.")
                }

                if deck == .frequent, !sections.isEmpty {
                    Section {
                        Picker(String(localized: "Section"), selection: field(\.section)) {
                            ForEach(sections) { section in
                                Text("Section \(section.number)").tag(section.number)
                            }
                        }
                        WordsCustomStudyStart(count: section?.total) {
                            interactions.startCustomStudy(.sectionOnly(draft.section), deck: deck)
                        }
                    } header: {
                        Text("One section only")
                    } footer: {
                        Text("Its due cards and its new cards within today's limit, nothing from other sections.")
                    }
                }
            }
            .navigationTitle("Custom study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    WordsSheetTitle(title: String(localized: "Custom study"), deck: deck)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        interactions.closeSheet()
                    }
                }
            }
        }
        .tint(theme.text.primary)
    }
}

private struct WordsCustomStudyStart: View {
    let count: Int?
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Button(action: action) {
            HStack {
                Label("Start", systemImage: "play.fill")
                Spacer(minLength: 0)
                if let count {
                    Text(WordsCustomStudyText.cards(count))
                        .foregroundStyle(theme.text.secondary)
                        .monospacedDigit()
                } else {
                    ProgressView()
                }
            }
        }
        .disabled(count == 0)
    }
}

enum WordsCustomStudyText {
    static func lastDays(_ days: Int) -> String {
        String(localized: "Forgotten in the last \(days) days")
    }

    static func nextDays(_ days: Int) -> String {
        String(localized: "Due in the next \(days) days")
    }

    static func cards(_ count: Int) -> String {
        String(localized: "\(count) cards")
    }
}
