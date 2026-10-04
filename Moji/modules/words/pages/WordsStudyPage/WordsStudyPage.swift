import SwiftUI

struct WordsStudyPage: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let isExitAlertPresented = Binding(
            get: { service.isExitAlertPresented },
            set: { if !$0 { interactions.keepStudying() } }
        )
        let character = Binding(
            get: { service.studyCharacter },
            set: { if $0 == nil { interactions.closeStudyCharacter() } }
        )

        ZStack {
            WordsStudyBackground()

            switch service.stage {
            case .loading:
                ProgressView()
                    .tint(theme.text.secondary)
            case .card(let card):
                VStack(spacing: 0) {
                    WordsStudyTopBar(card: card)
                        .padding(.horizontal, 16)

                    WordsStudyDeck(card: card)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    WordsAnswerBar(card: card)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            case .finished(let model):
                WordsStudySummaryView(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if let notice = service.leechNotice {
                VStack {
                    WordsLeechToast(notice: notice)
                        .padding(.top, 64)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: stageKey)
        .alert("Stop for now?", isPresented: isExitAlertPresented) {
            Button("Keep studying", role: .cancel) {
                interactions.keepStudying()
            }
            Button("Stop") {
                interactions.stopStudying()
            }
        } message: {
            Text("Every answer is already saved. Finish the queue to count today for your streak.")
        }
        .sheet(item: character) { character in
            CharacterDetailSheet(character: character)
                .themedPresentation()
        }
    }

    private var stageKey: String {
        switch service.stage {
        case .loading: "loading"
        case .card: "card"
        case .finished: "finished"
        }
    }
}

struct WordsStudyBackground: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        (theme.isDark ? theme.bg._100 : theme.bg._300)
            .ignoresSafeArea()
    }
}

private struct WordsLeechToast: View {
    let notice: WordsLeechNotice

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MojiTint.wrong)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(notice.word) keeps slipping")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Group {
                    if notice.suspended {
                        Text("Tagged as a leech and suspended")
                    } else {
                        Text("Tagged as a leech")
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(theme.text.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .liquidChromeRoundedRectangle(cornerRadius: 20)
    }
}
