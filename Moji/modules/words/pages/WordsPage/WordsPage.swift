import SwiftUI

struct WordsPage: View {
    static let refreshInterval: Duration = .seconds(30)

    @State private var liveTabs = AnimatedTabsLiveState()

    private static let tabs = MojiWordDeck.allCases.map {
        TabHeaderConfig(id: $0, text: $0.title)
    }

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let selection = Binding(
            get: { service.selectedDeck },
            set: { interactions.selectDeck($0) }
        )
        let sheet = Binding(
            get: { service.sheet },
            set: { if $0 == nil { interactions.closeSheet() } }
        )
        let detail = Binding(
            get: { service.sheet == nil ? service.detail : nil },
            set: { if $0 == nil { interactions.closeWord() } }
        )
        let character = Binding(
            get: { service.sheet == nil && service.detail == nil ? service.detailCharacter : nil },
            set: { if $0 == nil { interactions.closeCharacter() } }
        )
        let editor = Binding(
            get: { service.sheet == nil && service.detail == nil && service.editor?.origin == .page ? service.editor : nil },
            set: { if $0 == nil { interactions.closeCardEditor() } }
        )
        let sectionAction = Binding(
            get: { service.sectionAction != nil },
            set: { if !$0 { interactions.cancelSectionAction() } }
        )
        let deleteRequest = Binding(
            get: { service.detail == nil && service.deleteRequest?.origin == .page },
            set: { if !$0 { interactions.cancelDeleteCard() } }
        )

        GeometryReader { geometry in
            let bottomInset = geometry.safeAreaInsets.bottom

            VStack(spacing: 14) {
                WordsHeader()
                    .padding(.horizontal, 16)

                AnimatedTabsHeader(
                    tabs: Self.tabs,
                    selection: service.selectedDeck,
                    liveState: liveTabs,
                    onSelect: { interactions.selectDeck($0) }
                )
                .padding(.horizontal, 16)

                AnimatedTabsPager(
                    ids: MojiWordDeck.allCases,
                    selection: selection,
                    liveState: liveTabs
                ) { deck in
                    WordsDeckPage(deck: deck, bottomInset: bottomInset)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .padding(.top, 6)
        }
        .ignoresSafeArea(.keyboard)
        .background {
            AppBackground()
        }
        .task {
            interactions.refreshClock()
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.refreshInterval)
                guard !Task.isCancelled else { return }
                interactions.refreshClock()
            }
        }
        .sheet(item: sheet) { sheet in
            Group {
                switch sheet {
                case .options: WordsOptionsSheet()
                case .browser: WordsBrowserSheet()
                case .stats: WordsStatsSheet()
                case .customStudy: WordsCustomStudySheet()
                }
            }
            .themedPresentation()
        }
        .sheet(item: detail) { target in
            NavigationStack {
                WordDetailView(wordID: target.wordID)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                interactions.closeWord()
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .themedPresentation()
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
            sectionActionTitle,
            isPresented: sectionAction,
            presenting: service.sectionAction
        ) { action in
            switch action.kind {
            case .known:
                Button("Mark as known") {
                    interactions.confirmSectionAction()
                }
            case .reset:
                Button("Reset", role: .destructive) {
                    interactions.confirmSectionAction()
                }
            }
            Button("Cancel", role: .cancel) {
                interactions.cancelSectionAction()
            }
        } message: { action in
            switch action.kind {
            case .known:
                Text("All \(action.section.count) words become mature reviews and come back now and then over the next weeks.")
            case .reset:
                Text("All \(action.section.count) words become new again. Notes and flags stay.")
            }
        }
        .alert(
            deleteTitle,
            isPresented: deleteRequest,
            presenting: service.deleteRequest
        ) { _ in
            Button("Delete", role: .destructive) {
                interactions.confirmDeleteCard()
            }
            Button("Cancel", role: .cancel) {
                interactions.cancelDeleteCard()
            }
        } message: { _ in
            Text("The card, its progress and its history go away. This can't be undone.")
        }
    }

    private var sectionActionTitle: Text {
        guard let action = service.sectionAction else { return Text(verbatim: "") }
        switch action.kind {
        case .known: return Text("Mark section \(action.section.number) as known?")
        case .reset: return Text("Reset section \(action.section.number)?")
        }
    }

    private var deleteTitle: Text {
        guard let request = service.deleteRequest else { return Text(verbatim: "") }
        return Text("Delete \(request.written)?")
    }
}

private struct WordsDeckPage: View {
    let deck: MojiWordDeck
    let bottomInset: CGFloat

    var body: some View {
        ScrollView {
            Group {
                switch deck {
                case .frequent: WordsFrequentDeckContent()
                case .mine: WordsMyCardsContent()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .contentMargins(.bottom, bottomInset + 28, for: .scrollContent)
    }
}

private struct WordsFrequentDeckContent: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WordsSearchField(text: service.query) { interactions.setQuery($0) }

            if service.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                WordsOverviewCard(deck: .frequent)
                sections
                credits
            } else {
                results
            }
        }
    }

    @ViewBuilder
    private var sections: some View {
        let catalog = service.catalog(.frequent)
        if !catalog.sections.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text("Sections")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.text.primary)
                Spacer(minLength: 0)
                Text("\(catalog.words.count) words, most frequent first")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
            }
            .padding(.top, 10)

            LazyVStack(spacing: 10) {
                ForEach(catalog.sections) { section in
                    WordsSectionRow(section: section)
                }
            }
        }
    }

    @ViewBuilder
    private var credits: some View {
        let credits = service.catalog(.frequent).credits
        if !credits.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(credits, id: \.self) { credit in
                    Text(verbatim: credit.text(in: MojiLanguage.current))
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(theme.text.secondary.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var results: some View {
        let found = service.searchResults(service.query, deck: .frequent)
        if found.isEmpty {
            Text("No words found")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 30)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(found) { word in
                    Button {
                        interactions.openWord(word)
                    } label: {
                        WordsWordRow(word: word)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .overlay(theme.border._200.opacity(0.5))
                }
            }
            .wordsCard()
        }
    }
}

private struct WordsMyCardsContent: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let catalog = service.catalog(.mine)
        let isSearching = !service.myQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        VStack(alignment: .leading, spacing: 14) {
            if !service.isLoaded(.mine) {
                ProgressView()
                    .tint(theme.text.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if catalog.isEmpty {
                WordsMyCardsEmptyCard()
            } else {
                WordsSearchField(
                    placeholder: String(localized: "Search my cards"),
                    text: service.myQuery
                ) { interactions.setMyQuery($0) }

                if isSearching {
                    let found = service.myCards()
                    if found.isEmpty {
                        Text("No cards found")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(theme.text.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    } else {
                        WordsMyCardsList(words: found)
                    }
                } else {
                    WordsOverviewCard(deck: .mine)

                    HStack(alignment: .firstTextBaseline) {
                        Text("Cards")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(theme.text.primary)
                        Spacer(minLength: 0)
                        Text("\(catalog.words.count) cards, newest last")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.text.secondary)
                    }
                    .padding(.top, 10)

                    WordsMyCardsList(words: catalog.words)
                }
            }
        }
    }
}
