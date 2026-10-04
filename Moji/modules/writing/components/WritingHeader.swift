import SwiftUI

struct WritingHeader: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    WritingStageIndicator(stage: service.stage)
                    Spacer(minLength: 0)
                    WritingLeftChip(count: service.writingsLeft)
                }
            }

            if let prompt = service.prompt {
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.system(size: prompt.isKana ? 34 : 24, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    if let subtitle = prompt.subtitle {
                        Text(subtitle)
                            .font(.system(size: 16, weight: .medium))
                            .typesettingLanguage(Locale.Language(identifier: "ja"))
                            .foregroundStyle(theme.text.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(service.character?.id)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: service.character?.id)
    }
}

struct WritingStageIndicator: View {
    let stage: MojiWritingStage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MojiWritingStage.allCases, id: \.self) { item in
                let isCurrent = item == stage
                Text(verbatim: "\(item.number)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isCurrent ? theme.bg._100 : theme.text.secondary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(isCurrent ? theme.text.primary : Color.clear))
            }
        }
        .padding(3)
        .liquidChromeCapsule()
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stage \(stage.number) of \(MojiWritingStage.allCases.count)"))
    }
}

struct WritingLeftChip: View {
    let count: Int

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "pencil.line")
                .font(.system(size: 13, weight: .semibold))
            Text("\(count) to write")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(theme.text.primary)
        .padding(.horizontal, 12)
        .frame(height: 34)
        .liquidChromeCapsule()
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(count) writings left"))
    }
}

struct WritingStatusLine: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WritingServicesStore { .shared }

    var body: some View {
        ZStack {
            if let failure = service.failure {
                VStack(spacing: 2) {
                    Text(failure.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MojiTint.wrong)
                    if let detail = failure.detail {
                        Text(detail)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.text.secondary)
                    }
                }
                .transition(.opacity)
            } else {
                Text(service.stage.caption)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.text.secondary)
                    .id(service.stage)
                    .transition(.opacity)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, minHeight: 40)
        .animation(.easeOut(duration: 0.2), value: service.failure)
        .animation(.easeOut(duration: 0.2), value: service.stage)
    }
}
