import SwiftUI

struct LearnPage: View {
    @State private var liveTabs = AnimatedTabsLiveState()

    private var service: LearnServicesStore { .shared }
    private var interactions: LearnInteractionsStore { .shared }
    private var searchInteractions: SearchInteractionsStore { .shared }

    private static let tabs = MojiScript.allCases.map {
        TabHeaderConfig(id: $0, text: $0.title)
    }

    var body: some View {
        let selection = Binding(
            get: { service.activeScript },
            set: { interactions.selectScript($0) }
        )
        let detail = Binding(
            get: { service.detailCharacter },
            set: { if $0 == nil { interactions.closeCharacter() } }
        )
        let writing = Binding(
            get: { service.writingPractice },
            set: { if $0 == nil { interactions.closeWriting() } }
        )
        let isBulkMarkPresented = Binding(
            get: { service.bulkMark != nil },
            set: { if !$0 { interactions.cancelBulkMark() } }
        )

        GeometryReader { geometry in
            let bottomInset = geometry.safeAreaInsets.bottom

            VStack(spacing: 14) {
                LearnHeader(page: service.activePage)
                    .padding(.horizontal, 16)

                AnimatedTabsHeader(
                    tabs: Self.tabs,
                    selection: service.activeScript,
                    liveState: liveTabs,
                    onSelect: { interactions.selectScript($0) }
                )
                .padding(.horizontal, 16)

                AnimatedTabsPager(
                    ids: MojiScript.allCases,
                    selection: selection,
                    liveState: liveTabs
                ) { script in
                    LearnScriptPage(
                        script: script,
                        bottomInset: bottomInset
                    )
                }
                .scrollDismissesKeyboard(.immediately)
                .ignoresSafeArea(edges: .bottom)
            }
            .padding(.top, 6)
        }
        .background {
            AppBackground()
        }
        .onChange(of: service.activeScript) {
            searchInteractions.activeScriptDidChange(on: .learn)
        }
        .sheet(item: detail) { character in
            CharacterDetailSheet(character: character)
                .themedPresentation()
        }
        .fullScreenCover(item: writing) { practice in
            WritingPracticeView(request: practice.request) { cards in
                interactions.finishPracticeWriting(practice, cards: cards)
            }
            .themedPresentation()
        }
        .alert(
            bulkMarkTitle,
            isPresented: isBulkMarkPresented,
            presenting: service.bulkMark
        ) { _ in
            Button("Mark as known") {
                interactions.confirmBulkMark()
            }
            Button("Cancel", role: .cancel) {
                interactions.cancelBulkMark()
            }
        } message: { mark in
            Text("\(mark.characterIDs.count) characters get full mastery. Lessons skip past them and bring them back now and then for review.")
        }
    }

    private var bulkMarkTitle: Text {
        guard let mark = service.bulkMark else { return Text(verbatim: "") }
        return mark.isWholeScript
            ? Text("Mark all of \(mark.title) as known?")
            : Text("Mark \(mark.title) as known?")
    }
}
