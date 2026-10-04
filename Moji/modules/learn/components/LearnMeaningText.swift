import SwiftUI

struct LearnMeaningText: View {
    let meaning: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let words = Self.unbreakableWords(in: meaning)

        ViewThatFits(in: .horizontal) {
            wrapped(words, size: 11.5)
            wrapped(words, size: 11)
            wrapped(words, size: 10.5)
            wrapped(words, size: 10)
            wrapped(words, size: 9.5)
            wrapped(words, size: 9)
            wrapped(words, size: 8.5)
            wrapped(words, size: 8)
            wrapped(words, size: 7.5)
            Text(meaning)
                .font(.system(size: 9, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(theme.text.primary.opacity(0.85))
    }

    private func wrapped(_ words: String, size: CGFloat) -> some View {
        let font = Font.system(size: size, weight: .semibold)

        return ZStack {
            Text(verbatim: words)
                .font(font)
                .fixedSize()
                .frame(height: 0)
                .hidden()
            Text(meaning)
                .font(font)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
                .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity)
        }
    }

    static func unbreakableWords(in text: String) -> String {
        var words: [String] = []
        for part in text.split(separator: " ") {
            var word = ""
            for character in part {
                word.append(character)
                if character == "-" || character == "/", word.count > 1 {
                    words.append(word)
                    word = ""
                }
            }
            if !word.isEmpty {
                words.append(word)
            }
        }
        return words.joined(separator: "\n")
    }
}
