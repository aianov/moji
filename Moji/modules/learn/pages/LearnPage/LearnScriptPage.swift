import SwiftUI

struct LearnScriptPage: View {
    let script: MojiScript
    let bottomInset: CGFloat

    @State private var didScroll = false

    private static let topID = "learn.top"

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }
    private var search: SearchServicesStore { .shared }

    var body: some View {
        let page = service.page(for: script)
        let path = service.path(for: page)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.topID)
                        .accessibilityHidden(true)

                    if let kanjiTheme = page.theme {
                        KanjiThemeIntro(theme: kanjiTheme, count: MojiAlphabetCatalog.shared.pool(page).count)
                            .padding(.bottom, 6)
                    }

                    ForEach(service.pathSections(path)) { section in
                        if let title = section.title {
                            Text(title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(theme.text.primary)
                                .padding(.top, 18)
                                .padding(.bottom, 2)
                        }
                        ForEach(section.batches) { state in
                            LearnBatchRow(state: state)
                                .id(state.batch.id)
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
                    LearnLaunchBar(page: page, path: path)
                }
            }
            .onAppear {
                scrollToCurrent(path, with: proxy)
            }
            .onChange(of: service.isLoaded) {
                scrollToCurrent(service.path(for: page), with: proxy)
            }
            .onChange(of: page) { _, newPage in
                pageDidChange(newPage, with: proxy)
            }
            .onChange(of: search.learn.focus) { _, focus in
                scrollToMatch(focus, on: page, with: proxy)
            }
        }
    }

    private static func currentTarget(in path: MojiLearnPath) -> String? {
        guard let index = path.currentIndex, index > 2, path.batches.indices.contains(index) else { return nil }
        return path.batches[index].id
    }

    private func scrollToCurrent(_ path: MojiLearnPath, with proxy: ScrollViewProxy) {
        guard !didScroll, service.isLoaded else { return }
        didScroll = true
        guard let target = Self.currentTarget(in: path) else { return }
        proxy.scrollTo(target, anchor: .center)
    }

    private func pageDidChange(_ page: MojiPage, with proxy: ScrollViewProxy) {
        Task { @MainActor in
            if let focus = search.learn.focus, focus.page == page {
                scrollToMatch(focus, on: page, with: proxy)
            } else if let target = Self.currentTarget(in: service.path(for: page)) {
                proxy.scrollTo(target, anchor: .center)
            } else {
                proxy.scrollTo(Self.topID, anchor: .top)
            }
        }
    }

    private func scrollToMatch(_ focus: CharacterSearchFocus?, on page: MojiPage, with proxy: ScrollViewProxy) {
        guard let focus, focus.page == page,
              let target = service.batchID(containing: focus.characterID, in: page) else { return }
        didScroll = true
        let anchor = CharacterSearchField.scrollAnchor(isEditing: search.isEditing(.learn))
        withAnimation(.smooth(duration: 0.4)) {
            proxy.scrollTo(target, anchor: anchor)
        }
    }
}
