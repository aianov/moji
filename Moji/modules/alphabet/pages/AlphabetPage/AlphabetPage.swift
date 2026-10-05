import SwiftUI

struct AlphabetPage: View {
    @State private var liveTabs = AnimatedTabsLiveState()

    private var service: AlphabetServicesStore { .shared }
    private var interactions: AlphabetInteractionsStore { .shared }
    private var practice: PracticeServicesStore { .shared }
    private var practiceInteractions: PracticeInteractionsStore { .shared }
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
        let isDiscardAlertPresented = Binding(
            get: { practice.discardCandidate != nil },
            set: { if !$0 { practiceInteractions.cancelDiscard() } }
        )
        let isBulkMarkPresented = Binding(
            get: { service.bulkMark != nil },
            set: { if !$0 { interactions.cancelBulkMark() } }
        )

        GeometryReader { geometry in
            let bottomInset = geometry.safeAreaInsets.bottom

            VStack(spacing: 14) {
                AlphabetHeader()
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
                    AlphabetScriptPage(
                        script: script,
                        bottomInset: bottomInset
                    )
                }
                .scrollDismissesKeyboard(.immediately)
                .ignoresSafeArea(edges: .bottom)
            }
            .padding(.top, 6)
        }
        .ignoresSafeArea(.keyboard)
        .background {
            AppBackground()
        }
        .onChange(of: service.activeScript) {
            searchInteractions.activeScriptDidChange(on: .practice)
        }
        .sheet(item: detail) { character in
            CharacterDetailSheet(character: character)
                .themedPresentation()
        }
        .alert(
            "Discard this session?",
            isPresented: isDiscardAlertPresented,
            presenting: practice.discardCandidate
        ) { _ in
            Button("Discard", role: .destructive) {
                practiceInteractions.confirmDiscard()
            }
            Button("Keep", role: .cancel) {
                practiceInteractions.cancelDiscard()
            }
        } message: { page in
            Text("Your saved \(page.title) session will be deleted. Mastery you earned in it stays.")
        }
        .alert(
            bulkMarkTitle,
            isPresented: isBulkMarkPresented,
            presenting: service.bulkMark
        ) { mark in
            switch mark.kind {
            case .known:
                Button("Mark as known") {
                    interactions.confirmBulkMark()
                }
            case .reset:
                Button("Reset", role: .destructive) {
                    interactions.confirmBulkMark()
                }
            }
            Button("Cancel", role: .cancel) {
                interactions.cancelBulkMark()
            }
        } message: { mark in
            switch mark.kind {
            case .known:
                Text("\(mark.characterIDs.count) characters get full mastery. Lessons skip past them and bring them back now and then for review.")
            case .reset:
                Text("Mastery of \(mark.characterIDs.count) characters goes back to zero. Answer history stays.")
            }
        }
    }

    private var bulkMarkTitle: Text {
        guard let mark = service.bulkMark else { return Text(verbatim: "") }
        switch (mark.kind, mark.isWholeScript) {
        case (.known, true): return Text("Mark all of \(mark.title) as known?")
        case (.known, false): return Text("Mark \(mark.title) as known?")
        case (.reset, true): return Text("Reset all of \(mark.title)?")
        case (.reset, false): return Text("Reset \(mark.title)?")
        }
    }
}
