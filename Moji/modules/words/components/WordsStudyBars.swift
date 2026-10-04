import SwiftUI

struct WordsStudyTopBar: View {
    let card: MojiWordStudyCard

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        HStack(spacing: 12) {
            LiquidGlassButton(
                shape: .circle,
                size: 44,
                accessibilityLabel: String(localized: "Close"),
                action: { interactions.close() }
            ) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
            }

            Spacer(minLength: 0)

            VStack(spacing: 4) {
                WordsQueueCounts(counts: card.counts, current: card.isCram ? nil : card.kind, isCram: card.isCram)
                if service.options.showTimer {
                    WordsCardTimer(since: service.cardShownAt)
                }
            }

            Spacer(minLength: 0)

            LiquidGlassButton(
                shape: .circle,
                size: 44,
                disabled: !card.canUndo || service.isBusy,
                accessibilityLabel: String(localized: "Undo the last answer"),
                action: { interactions.undo() }
            ) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
            }
        }
        .padding(.top, 8)
    }
}

struct WordsQueueCounts: View {
    let counts: MojiWordQueueCounts
    let current: MojiWordQueueKind?
    var isCram = false

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 14) {
            if isCram {
                item(counts.review, title: String(localized: "Left"), isCurrent: true)
            } else {
                item(counts.new, title: String(localized: "New"), isCurrent: current == .new)
                item(counts.learning, title: String(localized: "Learning"), isCurrent: current == .learning)
                item(counts.review, title: String(localized: "Due"), isCurrent: current == .review)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .liquidChromeCapsule()
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: counts)
    }

    private func item(_ value: Int, title: String, isCurrent: Bool) -> some View {
        VStack(spacing: 0) {
            Text("\(value)")
                .font(.system(size: 16, weight: isCurrent ? .bold : .semibold).monospacedDigit())
                .foregroundStyle(isCurrent ? theme.text.primary : theme.text.secondary)
                .contentTransition(.numericText(value: Double(value)))
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
        }
        .frame(minWidth: 34)
        .overlay(alignment: .bottom) {
            if isCurrent {
                Capsule()
                    .fill(theme.text.primary)
                    .frame(width: 14, height: 2)
                    .offset(y: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(title) \(value)"))
    }
}

struct WordsCardTimer: View {
    let since: Date

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        TimelineView(.periodic(from: since, by: 1)) { context in
            Text(verbatim: WordsFormat.clock(min(MojiWordDefaults.maximumAnswerSeconds, context.date.timeIntervalSince(since))))
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(theme.text.secondary.opacity(0.8))
        }
        .accessibilityHidden(true)
    }
}

struct WordsAnswerBar: View {
    let card: MojiWordStudyCard

    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        Group {
            if service.isFlipped {
                HStack(spacing: 8) {
                    ForEach(MojiWordButton.allCases) { button in
                        WordsGradeButton(
                            button: button,
                            interval: service.options.showNextIntervals ? card.delays[button].map(WordsFormat.interval) : nil,
                            action: { interactions.grade(button) }
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                ProgressCapsuleButton(
                    title: String(localized: "Show answer"),
                    systemImage: "rectangle.on.rectangle.angled",
                    role: .primary,
                    height: 58,
                    action: { interactions.showAnswer() }
                )
                .transition(.opacity)
            }
        }
        .disabled(service.isBusy)
        .animation(.easeInOut(duration: 0.2), value: service.isFlipped)
    }
}

struct WordsGradeButton: View {
    let button: MojiWordButton
    let interval: String?
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let color = button.tint ?? theme.text.primary

        Button(action: action) {
            VStack(spacing: 2) {
                if let interval {
                    Text(verbatim: interval)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(color.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(button.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(shape.fill(button.tint.map { $0.opacity(theme.isDark ? 0.2 : 0.12) } ?? theme.bg._400))
            .overlay(shape.strokeBorder(color.opacity(button.tint == nil ? 0.08 : 0.3), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.94))
        .accessibilityLabel(Text(verbatim: [button.title, interval].compactMap { $0 }.joined(separator: ", ")))
    }
}
