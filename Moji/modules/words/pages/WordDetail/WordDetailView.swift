import SwiftUI

struct WordDetailView: View {
    let wordID: String

    @Environment(\.dismiss) private var dismiss
    @State private var noteDraft = ""
    @State private var noteLoaded = false

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    private var isOwn: Bool {
        MojiWordDeck.of(wordID: wordID) == .mine
    }

    var body: some View {
        let character = Binding(
            get: { service.detailCharacter },
            set: { if $0 == nil { interactions.closeCharacter() } }
        )
        let editor = Binding(
            get: { service.editor?.origin == .detail && service.editor?.wordID == wordID ? service.editor : nil },
            set: { if $0 == nil { interactions.closeCardEditor() } }
        )
        let deleteRequest = Binding(
            get: { service.deleteRequest?.origin == .detail && service.deleteRequest?.wordID == wordID },
            set: { if !$0 { interactions.cancelDeleteCard() } }
        )

        Group {
            if let word = service.word(wordID) {
                content(word)
                    .navigationTitle(Text(verbatim: word.written))
                    .navigationBarTitleDisplayMode(.inline)
                    .task(id: wordID) {
                        interactions.loadHistory(word)
                        if !noteLoaded {
                            noteDraft = service.note(for: word) ?? ""
                            noteLoaded = true
                        }
                    }
                    .task(id: noteDraft) {
                        guard !isOwn, noteLoaded, noteDraft != (service.note(for: word) ?? "") else { return }
                        try? await Task.sleep(for: .milliseconds(700))
                        guard !Task.isCancelled else { return }
                        interactions.setNote(noteDraft, for: word)
                    }
                    .onDisappear {
                        if !isOwn, noteLoaded, noteDraft != (service.note(for: word) ?? "") {
                            interactions.setNote(noteDraft, for: word)
                        }
                    }
            } else {
                Text(isOwn ? String(localized: "This card is no longer in your cards.") : String(localized: "This word is no longer in the deck."))
                    .font(.system(size: 15))
                    .foregroundStyle(theme.text.secondary)
            }
        }
        .sheet(item: character) { character in
            CharacterDetailSheet(character: character)
                .themedPresentation()
        }
        .sheet(item: editor) { editor in
            WordsCardFormSheet(editor: editor)
                .themedPresentation()
        }
        .alert(
            deleteTitle,
            isPresented: deleteRequest,
            presenting: service.deleteRequest
        ) { _ in
            Button("Delete", role: .destructive) {
                let isDetailSheet = service.detail?.wordID == wordID
                interactions.confirmDeleteCard()
                if !isDetailSheet {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {
                interactions.cancelDeleteCard()
            }
        } message: { _ in
            Text("The card, its progress and its history go away. This can't be undone.")
        }
    }

    private var deleteTitle: Text {
        guard let request = service.deleteRequest else { return Text(verbatim: "") }
        return Text("Delete \(request.written)?")
    }

    private func content(_ word: MojiWord) -> some View {
        List {
            Section {
                WordDetailHero(word: word)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if isOwn {
                Section {
                    Button {
                        interactions.editCard(word, from: .detail)
                    } label: {
                        Label("Edit the card", systemImage: "pencil")
                    }
                }
            }

            if !word.sentences.isEmpty {
                Section {
                    ForEach(Array(word.sentences.enumerated()), id: \.offset) { _, sentence in
                        WordDetailSentence(sentence: sentence)
                    }
                } header: {
                    if isOwn {
                        Text("Example")
                    } else {
                        Text("Examples")
                    }
                }
            }

            let kanji = service.kanjiCharacters(of: word)
            if !kanji.isEmpty {
                Section {
                    WordsKanjiChips(characters: kanji) { interactions.openCharacter($0) }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }

            if isOwn {
                if let note = service.note(for: word) {
                    Section {
                        Text(note)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Text("Your note")
                    }
                }
            } else {
                Section {
                    TextField(String(localized: "Mnemonic, nuance, anything that helps"), text: $noteDraft, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Your note")
                }
            }

            ForEach(service.allCardIDs(of: word), id: \.self) { id in
                WordDetailCardSection(word: word, id: id)
            }

            Section {
                Button {
                    interactions.markKnown(word)
                } label: {
                    Label("I know this word", systemImage: "checkmark.circle")
                }
                Button(role: .destructive) {
                    interactions.forget(word)
                } label: {
                    Label("Forget: make it new again", systemImage: "arrow.counterclockwise")
                }
                if isOwn {
                    Button(role: .destructive) {
                        interactions.requestDeleteCard(word, from: .detail)
                    } label: {
                        Label("Delete the card", systemImage: "trash")
                    }
                }
            }

            WordDetailHistory(word: word)
        }
        .listStyle(.insetGrouped)
    }
}

private struct WordDetailHero: View {
    let word: MojiWord

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                WordsHeadword(
                    token: word.token,
                    size: 44,
                    onOpenCharacter: { interactions.openCharacter($0) }
                )
                WordsSpeakerButton(label: String(localized: "Play the word")) {
                    interactions.playWord(word)
                }
            }
            if !word.readingLine.isEmpty {
                Text(verbatim: word.readingLine)
                    .font(.system(size: 16, weight: .medium))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.secondary)
                    .multilineTextAlignment(.center)
            }
            Text(word.meaning(in: MojiLanguage.current))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(theme.text.primary)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                if MojiWordDeck.of(wordID: word.id) == .mine {
                    WordsChip(text: String(localized: "My card"))
                } else {
                    if let partOfSpeech = word.partOfSpeech {
                        WordsChip(text: partOfSpeech.title)
                    }
                    WordsChip(text: String(localized: "No. \(word.rank)"))
                    WordsChip(text: String(localized: "Section \(word.section)"))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WordDetailSentence: View {
    let sentence: MojiWordSentence

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                FuriganaTextView(
                    tokens: sentence.tokens,
                    size: 19,
                    furigana: .all,
                    highlightsTarget: true,
                    onOpenCharacter: { interactions.openCharacter($0) }
                )
                let translation = sentence.translation(in: MojiLanguage.current)
                if !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: 14))
                        .foregroundStyle(theme.text.secondary)
                }
                if let credit = WordsSentenceCredit.text(for: sentence) {
                    Text(verbatim: credit)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text.secondary.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
            WordsSpeakerButton(
                label: String(localized: "Play the sentence"),
                systemImage: MojiWordVoice.hasRecording(sentence) ? "speaker.wave.2.fill" : "speaker.wave.1"
            ) {
                interactions.playSentence(sentence)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct WordDetailCardSection: View {
    let word: MojiWord
    let id: MojiWordCardID

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let card = service.card(id)
        let today = service.today(of: word.id)
        let state = MojiWordCardState.of(card, today: today)
        let due = Binding(
            get: { service.dueDraft },
            set: { interactions.setDueDraft($0) }
        )

        Section {
            LabeledContent(String(localized: "State")) {
                WordsStateBadge(state: state)
            }
            LabeledContent(String(localized: "Next"), value: WordsFormat.due(card, today: today))
            if card.phase == .review || card.phase == .relearning {
                LabeledContent(String(localized: "Interval"), value: WordsFormat.interval(days: card.interval))
                LabeledContent(String(localized: "Ease"), value: WordsFormat.percent(card.ease))
            }
            if card.reps > 0 {
                LabeledContent(String(localized: "Reviews"), value: "\(card.reps)")
                LabeledContent(String(localized: "Lapses"), value: "\(card.lapses)")
            }

            WordDetailFlags(selected: card.flag) { flag in
                interactions.setFlag(flag, cards: [id])
            }

            Button {
                interactions.setSuspended(!card.isSuspended, cards: [id])
            } label: {
                Label(
                    card.isSuspended ? String(localized: "Unsuspend") : String(localized: "Suspend"),
                    systemImage: card.isSuspended ? "play.circle" : "pause.circle"
                )
            }
            if card.isBuried(on: today) {
                Button {
                    interactions.unbury([id])
                } label: {
                    Label("Unbury", systemImage: "arrow.up.circle")
                }
            } else {
                Button {
                    interactions.bury([id])
                } label: {
                    Label("Bury until tomorrow", systemImage: "moon.zzz")
                }
            }
            if card.isLeech {
                Button {
                    interactions.setLeech(false, cards: [id])
                } label: {
                    Label("Remove the leech tag", systemImage: "tag.slash")
                }
            }
            Stepper(value: due, in: 0...3_650) {
                Text(service.dueDraft == 0 ? String(localized: "Due today") : String(localized: "Due in \(service.dueDraft) days"))
            }
            Button {
                interactions.reschedule([id], word: word)
            } label: {
                Label("Set due date", systemImage: "calendar")
            }
        } header: {
            Text(id.kind == .recognition ? String(localized: "Card: Japanese to meaning") : String(localized: "Card: meaning to Japanese"))
        }
    }
}

private struct WordDetailFlags: View {
    let selected: MojiWordFlag?
    let onSelect: (MojiWordFlag?) -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 10) {
            Text("Flag")
            Spacer(minLength: 0)
            ForEach(MojiWordFlag.allCases) { flag in
                Button {
                    onSelect(selected == flag ? nil : flag)
                } label: {
                    Circle()
                        .fill(flag.color)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if selected == flag {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 28, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(flag.title))
                .accessibilityAddTraits(selected == flag ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

private struct WordDetailHistory: View {
    let word: MojiWord

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }

    var body: some View {
        let history = service.histories[word.id] ?? [:]
        let entries = history
            .flatMap { id, reviews in reviews.map { (id: id, review: $0) } }
            .sorted { $0.review.at > $1.review.at }

        Section {
            if entries.isEmpty {
                Text("No reviews yet")
                    .foregroundStyle(theme.text.secondary)
            } else {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    WordDetailHistoryRow(review: entry.review, isReverse: entry.id.kind == .recall)
                }
            }
        } header: {
            Text("History")
        }
    }
}

private struct WordDetailHistoryRow: View {
    let review: MojiWordReview
    let isReverse: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: review.at.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.text.primary)
                Text(verbatim: isReverse ? "\(review.kind.title) · \(String(localized: "reverse"))" : review.kind.title)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text.secondary)
            }
            Spacer(minLength: 0)
            if let button = review.button {
                Text(button.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(button.tint ?? theme.text.primary)
            }
            if let delay = review.delay {
                Text(verbatim: WordsFormat.interval(delay))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.text.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }
}
