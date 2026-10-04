import SwiftUI

struct WordsCardFormSheet: View {
    let editor: WordsCardEditor

    static let focusDelay: Duration = .milliseconds(400)

    @FocusState private var focus: WordsCardField?
    @State private var showsFixes = false

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let draft = service.draft
        let problems = draft.problems
        let canSave = problems.isEmpty && !service.isSavingCard
        let isDiscardPresented = Binding(
            get: { service.isDiscardCardPresented },
            set: { if !$0 { interactions.keepEditingCard() } }
        )

        NavigationStack {
            Form {
                wordSection(draft, problems: problems)
                meaningSection(draft, problems: problems)
                exampleSection(draft)
                noteSection
                if editor.isNew {
                    addAnotherSection(canSave: canSave)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editor.isNew ? String(localized: "New card") : String(localized: "Edit card"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        interactions.cancelCard()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        interactions.saveCard(addAnother: false)
                    }
                    .disabled(!canSave)
                }
                if editor.isNew {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button {
                            interactions.saveCard(addAnother: true)
                        } label: {
                            Label("Save and add another", systemImage: "plus")
                                .labelStyle(.titleAndIcon)
                        }
                        .disabled(!canSave)
                    }
                }
            }
            .alert(
                editor.isNew ? String(localized: "Discard this card?") : String(localized: "Discard the changes?"),
                isPresented: isDiscardPresented
            ) {
                Button("Don't save", role: .destructive) {
                    interactions.discardCard()
                }
                Button("Keep editing", role: .cancel) {
                    interactions.keepEditingCard()
                }
            } message: {
                Text("What you wrote here isn't saved yet.")
            }
        }
        .tint(theme.text.primary)
        .interactiveDismissDisabled(draft.hasChanges)
        .onChange(of: service.cardFocusToken) {
            showsFixes = false
            focus = .word
        }
        .onChange(of: focus) { old, new in
            guard old != new else { return }
            if old == .reading {
                interactions.commitCardReading()
            }
            if case .fix(let surface) = old {
                interactions.commitTokenReading(for: surface)
            }
        }
        .task {
            guard editor.isNew else { return }
            try? await Task.sleep(for: Self.focusDelay)
            if focus == nil {
                focus = .word
            }
        }
    }

    private func wordSection(_ draft: WordsCardDraft, problems: [MojiOwnWordProblem]) -> some View {
        let word = draft.word.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasKanji = word.contains(where: MojiFurigana.isKanji)
        let reading = MojiWordReadings.normalized(draft.reading)
        let romaji = MojiWordRomaji.spell(reading.isEmpty ? word : reading) ?? ""

        return Section {
            if hasKanji {
                WordsHeadword(
                    token: MojiWordToken(surface: word, reading: reading.isEmpty ? nil : reading, isTarget: true),
                    size: 34
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            TextField(String(localized: "Kanji or kana"), text: binding(\.word, next: .meaning, set: interactions.setCardWord))
                .font(.system(size: 22, weight: .semibold))
                .typesettingLanguage(Locale.Language(identifier: "ja"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .word)
                .onSubmit { focus = .meaning }

            LabeledContent {
                HStack(spacing: 6) {
                    TextField(String(localized: "In hiragana"), text: binding(\.reading, next: .meaning, set: interactions.setCardReading))
                        .multilineTextAlignment(.trailing)
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .reading)
                        .onSubmit { focus = .meaning }
                    if draft.isReadingEdited, !draft.autoReading.isEmpty {
                        Button {
                            interactions.restoreCardReading()
                        } label: {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(theme.text.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Use the reading from the word"))
                    }
                }
            } label: {
                Text("Reading")
            }

            LabeledContent(String(localized: "Romaji"), value: romaji.isEmpty ? "-" : romaji)
        } header: {
            HStack(spacing: 8) {
                Text("Word")
                Spacer(minLength: 0)
                if let lastAdded = draft.lastAdded {
                    Label {
                        Text("Added: \(lastAdded)")
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "checkmark")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: draft.lastAdded)
        } footer: {
            if problems.contains(.wordNotJapanese) {
                Text("Write the word in kanji or kana.")
            } else if !draft.isReadingEdited, !draft.reading.isEmpty {
                Text("The reading and romaji fill in by themselves. Fix the reading if it's wrong.")
            }
        }
    }

    private func meaningSection(_ draft: WordsCardDraft, problems: [MojiOwnWordProblem]) -> some View {
        Section {
            TextField(
                String(localized: "In Russian or English"),
                text: binding(\.meaning, next: .sentence, set: interactions.setCardMeaning),
                axis: .vertical
            )
            .lineLimit(1...4)
            .submitLabel(.next)
            .focused($focus, equals: .meaning)
        } header: {
            Text("Meaning")
        } footer: {
            if problems.contains(.missingMeaning), !draft.word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("A card needs a meaning.")
            }
        }
    }

    private func exampleSection(_ draft: WordsCardDraft) -> some View {
        let fixable = draft.fixableTokens
        let hasSentence = !draft.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Section {
            TextField(
                String(localized: "A sentence in Japanese"),
                text: binding(\.sentence, next: .translation, set: interactions.setCardSentence),
                axis: .vertical
            )
            .lineLimit(1...5)
            .typesettingLanguage(Locale.Language(identifier: "ja"))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)
            .focused($focus, equals: .sentence)

            if hasSentence, !draft.tokens.isEmpty {
                FuriganaTextView(
                    tokens: draft.tokens,
                    size: 19,
                    furigana: .all,
                    highlightsTarget: true
                )
                .padding(.vertical, 4)
            }

            if hasSentence, !fixable.isEmpty {
                DisclosureGroup(isExpanded: $showsFixes) {
                    ForEach(fixable, id: \.surface) { token in
                        fixRow(token, draft: draft)
                    }
                } label: {
                    Text("Fix a reading")
                }
            }

            TextField(
                String(localized: "Translation, if you like"),
                text: binding(\.translation, next: .note, set: interactions.setCardTranslation),
                axis: .vertical
            )
            .lineLimit(1...4)
            .submitLabel(.next)
            .focused($focus, equals: .translation)
        } header: {
            Text("Example")
        } footer: {
            Text("Optional. Furigana fills in by itself. Tap a word to see its romaji.")
        }
    }

    private func fixRow(_ token: MojiWordToken, draft: WordsCardDraft) -> some View {
        let surface = token.surface
        let auto = draft.autoReading(of: surface) ?? ""
        let isFixed = draft.fixes[surface] != nil
        let reading = Binding(
            get: { service.draft.fixes[surface] ?? token.reading ?? "" },
            set: { interactions.setTokenReading($0, for: surface) }
        )

        return HStack(spacing: 10) {
            Text(verbatim: surface)
                .font(.system(size: 19, weight: .medium))
                .typesettingLanguage(Locale.Language(identifier: "ja"))
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 8)
            TextField(auto, text: reading)
                .multilineTextAlignment(.trailing)
                .typesettingLanguage(Locale.Language(identifier: "ja"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focus, equals: .fix(surface))
            if isFixed {
                Button {
                    interactions.restoreTokenReading(for: surface)
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(theme.text.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Use the reading found for \(surface)"))
            }
        }
    }

    private var noteSection: some View {
        Section {
            TextField(
                String(localized: "Mnemonic, nuance, anything that helps"),
                text: Binding(
                    get: { service.draft.note },
                    set: { interactions.setCardNote($0) }
                ),
                axis: .vertical
            )
            .lineLimit(2...6)
            .focused($focus, equals: .note)
        } header: {
            Text("Your note")
        }
    }

    private func addAnotherSection(canSave: Bool) -> some View {
        Section {
            Button {
                interactions.saveCard(addAnother: true)
            } label: {
                Label("Save and add another", systemImage: "plus.circle")
            }
            .disabled(!canSave)
        } footer: {
            Text("The word and its meaning are enough. Everything else can wait.")
        }
    }

    private func binding(
        _ keyPath: KeyPath<WordsCardDraft, String>,
        next: WordsCardField,
        set: @escaping (String) -> Void
    ) -> Binding<String> {
        Binding(
            get: { service.draft[keyPath: keyPath] },
            set: { text in
                let old = service.draft[keyPath: keyPath]
                guard text.filter(\.isNewline).count > old.filter(\.isNewline).count else {
                    set(text)
                    return
                }
                set(old.contains(where: \.isNewline) ? old : text.filter { !$0.isNewline })
                focus = next
            }
        )
    }
}
