import SwiftUI

struct WordsMyCardsEmptyCard: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Your own cards")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Text("Write a word, its reading and meaning, and a sentence if you like. Your cards flip and come back on the same schedule as the deck, and you can study only them.")
                    .font(.system(size: 15))
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ProgressCapsuleButton(
                title: String(localized: "Add a card"),
                systemImage: "plus",
                role: .primary,
                action: { interactions.newCard() }
            )
        }
        .wordsCard()
    }
}

struct WordsMyCardsList: View {
    let words: [MojiWord]

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                WordsMyCardRow(word: word)
                if index < words.count - 1 {
                    Divider()
                        .overlay(theme.border._200.opacity(0.5))
                }
            }
        }
        .wordsCard()
    }
}

struct WordsMyCardRow: View {
    let word: MojiWord

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        HStack(spacing: 2) {
            Button {
                interactions.openWord(word)
            } label: {
                WordsWordRow(word: word)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Menu {
                WordsMyCardMenuItems(word: word)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                    .frame(width: 34, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Actions for \(word.written)"))
        }
        .contextMenu {
            WordsMyCardMenuItems(word: word)
        }
    }
}

struct WordsMyCardMenuItems: View {
    let word: MojiWord

    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        Button {
            interactions.editCard(word, from: .page)
        } label: {
            Label("Edit the card", systemImage: "pencil")
        }
        Button {
            interactions.openWord(word)
        } label: {
            Label("Card details", systemImage: "info.circle")
        }
        Divider()
        Button(role: .destructive) {
            interactions.requestDeleteCard(word, from: .page)
        } label: {
            Label("Delete the card", systemImage: "trash")
        }
    }
}
