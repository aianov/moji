import SwiftUI

struct WordsStudySummaryView: View {
    let model: WordsStudySummaryModel

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let summary = model.summary

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(WordsScopeTitle.text(summary.scope, deck: summary.deck))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(theme.text.secondary)
                    Group {
                        if summary.answered == 0 {
                            Text("Nothing to study right now")
                        } else {
                            Text("Done for now")
                        }
                    }
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(theme.text.primary)
                }

                if summary.answered > 0 {
                    score(summary)
                    numbers(summary)
                }

                if summary.learningLater > 0, let next = summary.nextLearningAt {
                    WordsSummaryNote(
                        systemImage: "clock",
                        text: String(localized: "Cards in learning come back at \(next.formatted(date: .omitted, time: .shortened)). Open Words then to finish them.")
                    )
                }

                if !summary.leeches.isEmpty {
                    leeches(summary.leeches, deck: summary.deck)
                }

                if summary.isComplete, summary.remaining.total == 0, summary.learningLater == 0 {
                    WordsSummaryNote(
                        systemImage: "checkmark.seal",
                        text: String(localized: "That's all for today. New cards and reviews come back tomorrow.")
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 6) {
                ProgressCapsuleButton(
                    title: String(localized: "Done"),
                    role: .primary,
                    action: { interactions.finishStudy() }
                )
                Button {
                    interactions.openCustomStudyAfterSession()
                } label: {
                    Text("Custom study")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    private func score(_ summary: MojiWordSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: WordsFormat.percent(model.accuracy))
                .font(.system(size: 64, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
            Text("Without Again: \(summary.correct) of \(summary.answered)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.text.secondary)

            if model.extendedStreak, let streak = model.streak {
                Label {
                    Group {
                        if streak <= 1 {
                            Text("Streak started: day 1")
                        } else {
                            Text("Day \(streak) of your streak")
                        }
                    }
                    .foregroundStyle(theme.text.primary)
                } icon: {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(MojiTint.flame)
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 8)
            }
        }
    }

    private func numbers(_ summary: MojiWordSessionSummary) -> some View {
        let hairline = theme.border._200.opacity(theme.isDark ? 1 : 0.55)

        return HStack(alignment: .top, spacing: 0) {
            WordsSummaryNumber(title: String(localized: "New"), value: "\(summary.newCards)")
            WordsSummaryNumber(title: String(localized: "Again"), value: "\(summary.again)")
            WordsSummaryNumber(title: String(localized: "Time"), value: WordsFormat.clock(summary.seconds))
        }
        .padding(.vertical, 16)
        .overlay(alignment: .top) {
            hairline.frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            hairline.frame(height: 0.5)
        }
    }

    private func leeches(_ wordIDs: [String], deck: MojiWordDeck) -> some View {
        let catalog = service.catalog(deck)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Leeches")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(theme.text.primary)
            Text("These words keep slipping. Look at them in the browser, add a note, or study them on their own.")
                .font(.system(size: 14))
                .foregroundStyle(theme.text.secondary)
                .fixedSize(horizontal: false, vertical: true)
            MojiFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(wordIDs, id: \.self) { wordID in
                    if let word = catalog.word(wordID) {
                        Text(verbatim: word.written)
                            .font(.system(size: 18, weight: .semibold))
                            .typesettingLanguage(Locale.Language(identifier: "ja"))
                            .foregroundStyle(theme.text.primary)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .liquidChromeCapsule()
                    }
                }
            }
        }
    }
}

private struct WordsSummaryNumber: View {
    let title: String
    let value: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: value)
                .font(.system(size: 22, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WordsSummaryNote: View {
    let systemImage: String
    let text: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(theme.text.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum WordsScopeTitle {
    static func text(_ scope: MojiWordScope, deck: MojiWordDeck) -> String {
        switch scope {
        case .deck:
            deck == .mine ? String(localized: "My cards") : String(localized: "Words")
        case .section(let number):
            String(localized: "Section \(number)")
        case .sectionOnly(let number):
            String(localized: "Section \(number) only")
        case .reviewAhead:
            String(localized: "Review ahead")
        case .forgotten:
            String(localized: "Forgotten cards")
        }
    }
}
