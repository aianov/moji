import SwiftUI

struct WordsPage: View {
    static let refreshInterval: Duration = .seconds(30)

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
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
        let sectionAction = Binding(
            get: { service.sectionAction != nil },
            set: { if !$0 { interactions.cancelSectionAction() } }
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                WordsHeader()

                WordsSearchField(text: service.query) { interactions.setQuery($0) }

                if service.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    WordsOverviewCard()
                    sections
                    credits
                } else {
                    results
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
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
    }

    private var sectionActionTitle: Text {
        guard let action = service.sectionAction else { return Text(verbatim: "") }
        switch action.kind {
        case .known: return Text("Mark section \(action.section.number) as known?")
        case .reset: return Text("Reset section \(action.section.number)?")
        }
    }

    @ViewBuilder
    private var sections: some View {
        let catalog = service.catalog
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
        let credits = service.catalog.credits
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
        let found = service.searchResults(service.query)
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
