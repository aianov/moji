import SwiftUI

struct AlphabetScriptPage: View {
    let script: MojiScript
    let bottomInset: CGFloat

    private static let topID = "alphabet.top"

    private var service: AlphabetServicesStore { .shared }
    private var interactions: AlphabetInteractionsStore { .shared }
    private var search: SearchServicesStore { .shared }

    var body: some View {
        let page = service.page(for: script)
        let sections = service.sections(page)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.topID)
                        .accessibilityHidden(true)

                    if let theme = page.theme {
                        KanjiThemeIntro(theme: theme, count: MojiAlphabetCatalog.shared.pool(page).count)
                            .padding(.bottom, -8)
                    }

                    ForEach(sections) { section in
                        let opensPage = section.id == sections.first?.id && page.theme == nil

                        if section.hasHeader {
                            CharacterSectionHeader(section: section)
                                .padding(.top, opensPage ? 0 : 20)
                                .padding(.bottom, 4)
                        } else if !opensPage {
                            Color.clear
                                .frame(height: 10)
                                .accessibilityHidden(true)
                        }

                        ForEach(section.rows) { row in
                            CharacterSectionRow(row: row, columns: section.columns, script: script)
                                .id(row.id)
                        }
                    }
                }
                .id(page)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, bottomInset + 28, for: .scrollContent)
            .safeAreaBar(edge: .top) {
                VStack(spacing: 0) {
                    if script.isKanji {
                        KanjiThemeBar(
                            selection: service.activeTheme,
                            onSelect: { interactions.selectTheme($0) }
                        )
                        .padding(.top, 8)
                    }
                    PracticeLaunchBar(page: page)
                }
            }
            .onChange(of: page) { _, newPage in
                pageDidChange(newPage, with: proxy)
            }
            .onChange(of: search.practice.focus) { _, focus in
                scrollToMatch(focus, on: page, with: proxy)
            }
        }
    }

    private func pageDidChange(_ page: MojiPage, with proxy: ScrollViewProxy) {
        Task { @MainActor in
            if let focus = search.practice.focus, focus.page == page {
                scrollToMatch(focus, on: page, with: proxy)
            } else {
                proxy.scrollTo(Self.topID, anchor: .top)
            }
        }
    }

    private func scrollToMatch(_ focus: CharacterSearchFocus?, on page: MojiPage, with proxy: ScrollViewProxy) {
        guard let focus, focus.page == page,
              let rowID = service.rowID(containing: focus.characterID, in: page) else { return }
        let anchor = CharacterSearchField.scrollAnchor(isEditing: search.isEditing(.practice))
        withAnimation(.smooth(duration: 0.4)) {
            proxy.scrollTo(rowID, anchor: anchor)
        }
    }
}
