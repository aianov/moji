import SwiftUI

struct WordsOptionsSheet: View {
    private static let learningPlaceholder = MojiWordStepsText.format(MojiWordDefaults.learningSteps)
    private static let relearningPlaceholder = MojiWordStepsText.format(MojiWordDefaults.relearningSteps)

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    private func binding<Value: Equatable>(_ keyPath: WritableKeyPath<MojiWordOptions, Value>) -> Binding<Value> {
        Binding(
            get: { service.options[keyPath: keyPath] },
            set: { value in interactions.updateOptions { $0[keyPath: keyPath] = value } }
        )
    }

    private func percent(_ keyPath: WritableKeyPath<MojiWordOptions, Double>) -> Binding<Int> {
        Binding(
            get: { Int((service.options[keyPath: keyPath] * 100).rounded()) },
            set: { value in interactions.updateOptions { $0[keyPath: keyPath] = Double(value) / 100 } }
        )
    }

    var body: some View {
        let options = service.options
        let isResetPresented = Binding(
            get: { service.isResetAllPresented },
            set: { if !$0 { interactions.cancelResetAll() } }
        )
        let steps = Binding(get: { service.stepDraft }, set: { service.stepDraft = $0 })
        let relearnSteps = Binding(get: { service.relearnStepDraft }, set: { service.relearnStepDraft = $0 })

        NavigationStack {
            Form {
                Section {
                    Stepper(value: binding(\.newPerDay), in: 0...9_999, step: 5) {
                        LabeledContent(String(localized: "New cards a day"), value: "\(options.newPerDay)")
                    }
                    Stepper(value: binding(\.reviewsPerDay), in: 0...99_999, step: 10) {
                        LabeledContent(String(localized: "Reviews a day"), value: "\(options.reviewsPerDay)")
                    }
                } header: {
                    Text("Daily limits")
                } footer: {
                    Text("New cards also count toward the review limit, like in Anki.")
                }

                Section {
                    LabeledContent(String(localized: "Learning steps")) {
                        TextField(Self.learningPlaceholder, text: steps)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { interactions.commitLearningSteps() }
                    }
                    Stepper(value: binding(\.graduatingInterval), in: 1...365) {
                        LabeledContent(String(localized: "Graduating interval"), value: WordsFormat.interval(days: options.graduatingInterval))
                    }
                    Stepper(value: binding(\.easyInterval), in: 1...365) {
                        LabeledContent(String(localized: "Easy interval"), value: WordsFormat.interval(days: options.easyInterval))
                    }
                    Picker(String(localized: "New card order"), selection: binding(\.newOrder)) {
                        ForEach(MojiWordNewOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    Picker(String(localized: "New cards and reviews"), selection: binding(\.newReviewMix)) {
                        ForEach(MojiWordNewReviewMix.allCases) { mix in
                            Text(mix.title).tag(mix)
                        }
                    }
                } header: {
                    Text("New cards")
                } footer: {
                    Text("Steps are minutes unless you add s, h or d: 1m 10m 1h. Press Return to save them.")
                }

                Section {
                    LabeledContent(String(localized: "Relearning steps")) {
                        TextField(Self.relearningPlaceholder, text: relearnSteps)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { interactions.commitRelearningSteps() }
                    }
                    Stepper(value: binding(\.minimumInterval), in: 1...365) {
                        LabeledContent(String(localized: "Minimum interval"), value: WordsFormat.interval(days: options.minimumInterval))
                    }
                    Stepper(value: binding(\.leechThreshold), in: 0...99) {
                        LabeledContent(
                            String(localized: "Leech after lapses"),
                            value: options.leechThreshold == 0 ? String(localized: "Never") : "\(options.leechThreshold)"
                        )
                    }
                    Picker(String(localized: "Leech action"), selection: binding(\.leechAction)) {
                        ForEach(MojiWordLeechAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                } header: {
                    Text("Lapses")
                } footer: {
                    Text("A lapse is a review card you pressed Again on. A leech is a card that lapses again and again.")
                }

                Section {
                    Picker(String(localized: "Review order"), selection: binding(\.reviewOrder)) {
                        ForEach(MojiWordReviewOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    Toggle(String(localized: "Reverse cards"), isOn: binding(\.reverseCards))
                        .tint(MojiTint.correct)
                    Toggle(String(localized: "Bury siblings"), isOn: binding(\.burySiblings))
                        .tint(MojiTint.correct)
                } header: {
                    Text("Order")
                } footer: {
                    Text("Reverse cards show the meaning and ask for the Japanese word. With burying on, a word's two cards never come on the same day.")
                }

                Section {
                    Picker(String(localized: "Furigana on the front"), selection: binding(\.frontFurigana)) {
                        ForEach(MojiWordFrontFurigana.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Toggle(String(localized: "Play audio on the answer"), isOn: binding(\.autoplayAudio))
                        .tint(MojiTint.correct)
                    Toggle(String(localized: "Replay buttons"), isOn: binding(\.replayButtons))
                        .tint(MojiTint.correct)
                    Toggle(String(localized: "Next intervals on the buttons"), isOn: binding(\.showNextIntervals))
                        .tint(MojiTint.correct)
                    Toggle(String(localized: "Swipe to grade"), isOn: binding(\.swipeToGrade))
                        .tint(MojiTint.correct)
                    Toggle(String(localized: "Answer by typing the reading"), isOn: binding(\.typeReading))
                        .tint(MojiTint.correct)
                    Toggle(String(localized: "Timer on the card"), isOn: binding(\.showTimer))
                        .tint(MojiTint.correct)
                    Picker(String(localized: "Next day starts at"), selection: binding(\.dayStartsAtHour)) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(verbatim: String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                } header: {
                    Text("Display and input")
                } footer: {
                    Text("Swipe a turned card left for Again or right for Good. Words play first, then the sentence when it has a real recording.")
                }

                Section {
                    Stepper(value: binding(\.maximumInterval), in: 1...36_500, step: 30) {
                        LabeledContent(String(localized: "Maximum interval"), value: WordsFormat.interval(days: options.maximumInterval))
                    }
                    Stepper(value: percent(\.startingEase), in: 131...500, step: 5) {
                        LabeledContent(String(localized: "Starting ease"), value: "\(Int((options.startingEase * 100).rounded()))%")
                    }
                    Stepper(value: percent(\.easyBonus), in: 100...500, step: 5) {
                        LabeledContent(String(localized: "Easy bonus"), value: "\(Int((options.easyBonus * 100).rounded()))%")
                    }
                    Stepper(value: percent(\.intervalModifier), in: 50...200, step: 5) {
                        LabeledContent(String(localized: "Interval modifier"), value: "\(Int((options.intervalModifier * 100).rounded()))%")
                    }
                    Stepper(value: percent(\.hardInterval), in: 50...130, step: 5) {
                        LabeledContent(String(localized: "Hard interval"), value: "\(Int((options.hardInterval * 100).rounded()))%")
                    }
                    Stepper(value: percent(\.newInterval), in: 0...100, step: 5) {
                        LabeledContent(String(localized: "New interval after a lapse"), value: "\(Int((options.newInterval * 100).rounded()))%")
                    }
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("The scheduler is Anki's SM-2: ease starts at \(WordsFormat.percent(MojiWordDefaults.startingEase)), Again takes \(WordsFormat.percent(0.2)) off, Hard \(WordsFormat.percent(0.15)), Easy adds \(WordsFormat.percent(0.15)). Intervals get a little random spread so cards don't bunch up.")
                }

                Section {
                    Button(String(localized: "Restore Anki's defaults")) {
                        interactions.restoreDefaultOptions()
                    }
                    Button(String(localized: "Erase all word progress"), role: .destructive) {
                        interactions.requestResetAll()
                    }
                } footer: {
                    Text("Erasing removes the state of every card, their history and the daily counts. Notes and options stay.")
                }

                if !service.catalog.credits.isEmpty {
                    Section {
                        ForEach(service.catalog.credits, id: \.self) { credit in
                            Text(verbatim: credit.text(in: MojiLanguage.current))
                                .font(.system(size: 13))
                                .foregroundStyle(theme.text.secondary)
                        }
                    } header: {
                        Text("About the words")
                    }
                }
            }
            .navigationTitle("Deck options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        interactions.commitLearningSteps()
                        interactions.commitRelearningSteps()
                        interactions.closeSheet()
                    }
                }
            }
            .alert("Erase all word progress?", isPresented: isResetPresented) {
                Button("Erase", role: .destructive) {
                    interactions.confirmResetAll()
                }
                Button("Cancel", role: .cancel) {
                    interactions.cancelResetAll()
                }
            } message: {
                Text("Every word becomes new again. This can't be undone.")
            }
        }
        .tint(theme.text.primary)
    }
}
