import SwiftUI

struct CharacterDetailSheet: View {
    let character: MojiCharacter

    @State private var writing: WritingPracticeRequest?

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var practice: PracticeServicesStore { .shared }
    private var interactions: AlphabetInteractionsStore { .shared }

    var body: some View {
        let progress = practice.progress(for: character.id) ?? .fresh

        ScrollView {
            VStack(spacing: 20) {
                tile

                VStack(spacing: 6) {
                    if let meaning = character.meaning {
                        Text(meaning)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(theme.text.primary)
                            .multilineTextAlignment(.center)
                        Text(character.readingLine)
                            .font(.system(size: 17, weight: .medium))
                            .typesettingLanguage(Locale.Language(identifier: "ja"))
                            .foregroundStyle(theme.text.secondary)
                        if let others = character.otherReadingsLine {
                            Text("Also: \(others)")
                                .font(.system(size: 14))
                                .typesettingLanguage(Locale.Language(identifier: "ja"))
                                .foregroundStyle(theme.text.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(character.romaji)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(theme.text.primary)
                    }
                }

                if !WritingPracticeRequest.available([character]).isEmpty {
                    LiquidGlassButton(
                        shape: .capsule,
                        size: 48,
                        horizontalPadding: 24,
                        action: {
                            MojiHaptics.impact()
                            writing = WritingPracticeRequest(title: character.glyph, characters: [character])
                        }
                    ) {
                        Label("Write it", systemImage: "pencil.and.scribble")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.text.primary)
                    }
                }

                MasteryEditor(character: character, strength: progress.strength, isWritten: progress.isWritten)

                HStack(spacing: 0) {
                    stat(value: "\(progress.seen)") { Text("Seen") }
                    stat(value: "\(progress.correct)") { Text("Correct") }
                    stat(value: progress.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "-") {
                        Text("Accuracy")
                    }
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(580), .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            interactions.characterDetailDidAppear(character)
        }
        .fullScreenCover(item: $writing) { request in
            WritingPracticeView(request: request) { cards in
                PracticeActionsStore.shared.markWrittenAction(cards.map(\.id))
            }
            .themedPresentation()
        }
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)

        return Button {
            interactions.speak(character)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                GlyphText(
                    text: character.glyph,
                    size: character.glyph.count > 2 ? 46 : (character.glyph.count == 2 ? 56 : 76),
                    color: theme.text.primary
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
                    .padding(14)
            }
            .frame(width: 148, height: 148)
            .background(shape.fill(theme.bg._300))
            .overlay(shape.strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Play \(character.glyph)"))
    }

    private func stat(value: String, @ViewBuilder title: () -> Text) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(theme.text.primary)
            title()
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MasteryEditor: View {
    let character: MojiCharacter
    let strength: Int
    let isWritten: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: AlphabetInteractionsStore { .shared }

    var body: some View {
        let level = MojiCharacterProgress.masteryLevel
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mastery")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Spacer(minLength: 0)
                Group {
                    if strength >= level && isWritten {
                        Text("Known")
                    } else if strength >= level {
                        Text("Writing is left")
                    } else {
                        Text("\(strength) of \(level)")
                    }
                }
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(strength >= level && isWritten ? MojiTint.gold : theme.text.secondary)
                .contentTransition(.numericText(value: Double(strength)))
            }

            HStack(spacing: 6) {
                ForEach(1...level, id: \.self) { step in
                    Button {
                        interactions.setStrength(step, for: character)
                    } label: {
                        Capsule(style: .continuous)
                            .fill(step <= strength ? MojiTint.gold : theme.bg._600)
                            .frame(height: 10)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Set mastery to \(step) of \(level)"))
                }

                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isWritten ? Color.white : theme.text.secondary)
                    .frame(width: 34, height: 18)
                    .background(Capsule(style: .continuous).fill(isWritten ? MojiTint.gold : theme.bg._600))
                    .frame(height: 34)
                    .accessibilityLabel(isWritten ? Text("Written") : Text("Not written yet"))
            }

            HStack(spacing: 10) {
                ProgressCapsuleButton(
                    title: String(localized: "Reset"),
                    systemImage: "arrow.counterclockwise",
                    role: .secondary,
                    height: 44,
                    action: { interactions.setStrength(0, for: character) }
                )
                .disabled(strength == 0)

                ProgressCapsuleButton(
                    title: String(localized: "I know it"),
                    systemImage: "checkmark",
                    role: .primary,
                    height: 44,
                    action: { interactions.setStrength(level, for: character) }
                )
                .disabled(strength >= level)
            }
        }
        .padding(16)
        .background(shape.fill(theme.bg._300))
        .overlay(shape.strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1))
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: strength)
    }
}
