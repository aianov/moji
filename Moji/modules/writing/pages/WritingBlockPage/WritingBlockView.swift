import SwiftUI

struct WritingBlockView: View {
    var showsSummaryTitle = true

    private var service: WritingServicesStore { .shared }

    var body: some View {
        ZStack {
            if service.isFinished {
                WritingFinishedView(results: service.results, showsTitle: showsSummaryTitle)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else if service.isActive {
                VStack(spacing: 6) {
                    WritingHeader()
                    WritingStatusLine()
                    WritingCanvas()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .transition(.opacity)
            } else if service.isUnavailable {
                WritingUnavailableView()
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: service.isFinished)
        .animation(.easeOut(duration: 0.2), value: service.isActive)
        .animation(.easeOut(duration: 0.2), value: service.isUnavailable)
    }
}

private struct WritingFinishedView: View {
    let results: [WritingResult]
    let showsTitle: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(spacing: 18) {
            if showsTitle {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52, weight: .regular))
                        .foregroundStyle(MojiTint.correct)
                    Text("All written")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                }
            }

            if !results.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 64, maximum: 84), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(results) { result in
                        WritingResultTile(result: result)
                    }
                }
                .frame(maxWidth: 420)
            }

            Text("You wrote every character from memory.")
                .font(.system(size: 15))
                .foregroundStyle(theme.text.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

private struct WritingResultTile: View {
    let result: WritingResult

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        GlyphText(
            text: result.character.glyph,
            size: result.character.glyph.count > 1 ? 24 : 32,
            color: theme.text.primary
        )
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(shape.fill(theme.bg._300))
        .overlay(shape.strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.6), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if result.isClean {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MojiTint.correct)
                    .background(Circle().fill(theme.bg._100).padding(2))
                    .offset(x: 5, y: -5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(result.character.glyph))
        .accessibilityValue(result.isClean ? Text("No mistakes") : Text("\(result.mistakes) mistakes"))
    }
}

private struct WritingUnavailableView: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pencil.slash")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(theme.text.secondary)
            Text("No stroke order for these characters")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}
