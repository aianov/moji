import SwiftUI

struct WordsBrowserSheet: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let deck = service.sheetDeck
        let query = Binding(
            get: { service.browserQuery },
            set: { interactions.setBrowserQuery($0) }
        )
        let words = service.browserWords()
        let title = deck == .mine
            ? String(localized: "My cards")
            : service.browserSection.map { String(localized: "Section \($0)") } ?? String(localized: "Browse")

        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(WordsBrowserFilter.allCases) { filter in
                                WordsFilterChip(
                                    title: filter.title,
                                    isSelected: service.browserFilter == filter,
                                    action: { interactions.setBrowserFilter(filter) }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))

                    if deck == .frequent {
                        Picker(String(localized: "Section"), selection: Binding(
                            get: { service.browserSection ?? 0 },
                            set: { interactions.setBrowserSection($0 == 0 ? nil : $0) }
                        )) {
                            Text("All sections").tag(0)
                            ForEach(service.catalog(deck).sections) { section in
                                Text("Section \(section.number)").tag(section.number)
                            }
                        }
                    }
                }

                Section {
                    if words.isEmpty {
                        Text(deck == .mine ? String(localized: "No cards here") : String(localized: "No words here"))
                            .foregroundStyle(theme.text.secondary)
                    } else {
                        ForEach(words) { word in
                            NavigationLink(value: word.id) {
                                WordsWordRow(word: word)
                            }
                        }
                    }
                } header: {
                    if deck == .mine {
                        Text(WordsCustomStudyText.cards(words.count))
                    } else {
                        Text("\(words.count) words")
                    }
                } footer: {
                    if let section = service.browserSection, !words.isEmpty {
                        Button {
                            interactions.studySectionFromBrowser(section)
                        } label: {
                            Label("Study section \(section)", systemImage: "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(theme.text.primary)
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: query, prompt: Text("Kanji, kana, romaji or meaning"))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { wordID in
                WordDetailView(wordID: wordID)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        interactions.closeSheet()
                    }
                }
            }
        }
    }
}

struct WordsFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? theme.bg._100 : theme.text.primary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidChromeCapsule(tint: isSelected ? theme.text.primary : nil, interactive: true)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct WordsSheetTitle: View {
    let title: String
    let deck: MojiWordDeck

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)
            Text(deck.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
