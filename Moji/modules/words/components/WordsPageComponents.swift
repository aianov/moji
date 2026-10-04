import SwiftUI

struct WordsHeader: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let activity = service.activity

        HStack(alignment: .center, spacing: 10) {
            Text("Words")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(theme.text.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            WordsMenu()

            StreakPill(
                streak: activity.currentStreak,
                isLit: activity.isTodayDone,
                action: { interactions.openProfile() }
            )
        }
        .frame(height: 44)
    }
}

struct WordsMenu: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        Menu {
            Button {
                interactions.openBrowser()
            } label: {
                Label("Browse words", systemImage: "list.bullet.rectangle")
            }
            Button {
                interactions.openSheet(.stats)
            } label: {
                Label("Statistics", systemImage: "chart.bar")
            }
            Button {
                interactions.openSheet(.customStudy)
            } label: {
                Label("Custom study", systemImage: "slider.horizontal.3")
            }
            Divider()
            Button {
                interactions.openSheet(.options)
            } label: {
                Label("Deck options", systemImage: "gearshape")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.text.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
                .liquidChromeCircle(interactive: true)
        }
        .accessibilityLabel(Text("Words menu"))
    }
}

struct WordsSearchField: View {
    var placeholder = String(localized: "食べる, taberu, eat")
    let text: String
    let onChange: (String) -> Void

    @FocusState private var isFocused: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let binding = Binding(get: { text }, set: { onChange($0) })

        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
                .frame(width: 24, height: CharacterSearchField.height)
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
                .accessibilityHidden(true)

            TextField(placeholder, text: binding)
                .font(.system(size: 16))
                .typesettingLanguage(Locale.Language(identifier: "ja"))
                .foregroundStyle(theme.text.primary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFocused)
                .frame(maxWidth: .infinity)
                .frame(height: CharacterSearchField.height)
                .accessibilityLabel(Text("Search words"))

            if !text.isEmpty {
                Button {
                    onChange("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(theme.text.secondary.opacity(0.8))
                        .frame(width: 34, height: CharacterSearchField.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear search"))
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, text.isEmpty ? 14 : 4)
        .frame(height: CharacterSearchField.height)
        .liquidChromeCapsule()
        .animation(.snappy(duration: 0.22), value: text.isEmpty)
    }
}

struct WordsCardBackground: ViewModifier {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius._100 + 4, style: .continuous)

        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(theme.bg._300.opacity(theme.isDark ? 0.92 : 1)))
            .overlay(
                shape.strokeBorder(
                    theme.border._200.opacity(theme.isDark ? 0.9 : 0.45),
                    lineWidth: 1
                )
            )
    }
}

extension View {
    func wordsCard() -> some View {
        modifier(WordsCardBackground())
    }
}

struct WordsOverviewCard: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let snapshot = service.snapshot
        let queue = snapshot.queue
        let today = snapshot.todayStats

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
                Spacer(minLength: 0)
                if today.answers > 0 {
                    Text("Answers: \(today.answers) · \(WordsFormat.duration(today.seconds))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.text.secondary)
                }
            }

            HStack(spacing: 10) {
                WordsCountTile(value: queue.new, title: String(localized: "New"))
                WordsCountTile(value: queue.learning, title: String(localized: "Learning"))
                WordsCountTile(value: queue.review, title: String(localized: "To review"))
            }

            if queue.total > 0 {
                ProgressCapsuleButton(
                    title: String(localized: "Study"),
                    detail: "\(queue.total)",
                    systemImage: "play.fill",
                    role: .primary,
                    action: { interactions.study() }
                )
                .disabled(!service.isLoaded)
            } else if let next = snapshot.nextLearningAt {
                ProgressCapsuleButton(
                    title: String(localized: "Learning cards at \(next.formatted(date: .omitted, time: .shortened))"),
                    systemImage: "clock",
                    role: .secondary,
                    action: { interactions.study() }
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(service.isLoaded ? doneText(snapshot) : String(localized: "Loading the deck…"))
                        .font(.system(size: 15))
                        .foregroundStyle(theme.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if service.isLoaded, !snapshot.catalog.isEmpty {
                        ProgressCapsuleButton(
                            title: String(localized: "Custom study"),
                            systemImage: "slider.horizontal.3",
                            role: .secondary,
                            height: 50,
                            action: { interactions.openSheet(.customStudy) }
                        )
                    }
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    WordsQuickButton(title: String(localized: "Browse"), systemImage: "list.bullet.rectangle") {
                        interactions.openBrowser()
                    }
                    WordsQuickButton(title: String(localized: "Statistics"), systemImage: "chart.bar") {
                        interactions.openSheet(.stats)
                    }
                    WordsQuickButton(title: String(localized: "Custom study"), systemImage: "slider.horizontal.3") {
                        interactions.openSheet(.customStudy)
                    }
                    WordsQuickButton(title: String(localized: "Options"), systemImage: "gearshape") {
                        interactions.openSheet(.options)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .wordsCard()
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: queue)
    }

    private func doneText(_ snapshot: MojiWordRepositorySnapshot) -> String {
        if snapshot.catalog.isEmpty {
            return String(localized: "The word list isn't in this build yet.")
        }
        if snapshot.states.new == 0, snapshot.states.total > 0, snapshot.queue.total == 0 {
            return String(localized: "Every word is in your reviews. Come back tomorrow.")
        }
        return String(localized: "All done for today. New words and reviews come back tomorrow.")
    }
}

struct WordsCountTile: View {
    let value: Int
    let title: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 26, weight: .semibold).monospacedDigit())
                .foregroundStyle(value > 0 ? theme.text.primary : theme.text.secondary)
                .contentTransition(.numericText(value: Double(value)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.bg._500.opacity(theme.isDark ? 0.7 : 0.55))
        )
        .accessibilityElement(children: .combine)
    }
}

struct WordsQuickButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        LiquidGlassButton(shape: .capsule, size: 38, horizontalPadding: 14, action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(theme.text.primary)
        }
    }
}

struct WordsProgressRing: View {
    let seen: Double
    let mature: Double
    var size: CGFloat = 46
    var lineWidth: CGFloat = 3.5
    let label: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.bg._600, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, seen)))
                .stroke(MojiTint.gold.opacity(0.35), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: min(1, max(0, mature)))
                .stroke(MojiTint.gold, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(verbatim: label)
                .font(.system(size: size * 0.32, weight: .bold).monospacedDigit())
                .foregroundStyle(mature >= 1 ? MojiTint.gold : theme.text.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(lineWidth + 2)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: seen)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: mature)
    }
}

struct WordsSectionRow: View {
    let section: MojiWordSection

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let stats = service.sectionStats(section)
        let preview = section.wordIDs.prefix(4).compactMap { service.catalog.word($0)?.written }.joined(separator: "、")
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        HStack(spacing: 12) {
            Button {
                interactions.openBrowser(section: section.number)
            } label: {
                HStack(spacing: 12) {
                    WordsProgressRing(
                        seen: stats.seenFraction,
                        mature: stats.matureFraction,
                        label: "\(section.number)"
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Section \(section.number)")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(theme.text.primary)
                            if stats.isKnown {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(MojiTint.gold)
                            }
                        }
                        Text("Words \(section.first)-\(section.last)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(theme.text.secondary)
                        Text(verbatim: preview)
                            .font(.system(size: 13))
                            .typesettingLanguage(Locale.Language(identifier: "ja"))
                            .foregroundStyle(theme.text.secondary)
                            .lineLimit(1)
                        WordsSectionCounts(stats: stats)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.98))

            VStack(spacing: 8) {
                LiquidGlassButton(
                    shape: .circle,
                    size: 40,
                    disabled: !service.isLoaded,
                    accessibilityLabel: String(localized: "Study section \(section.number)"),
                    action: { interactions.studySection(section) }
                ) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                }
                WordsSectionMenu(section: section, stats: stats)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(shape.fill(theme.bg._300))
        .overlay(shape.strokeBorder(theme.border._200.opacity(theme.isDark ? 1 : 0.55), lineWidth: 1))
        .contextMenu {
            WordsSectionMenuItems(section: section, stats: stats)
        }
    }
}

private struct WordsSectionCounts: View {
    let stats: MojiWordSectionStats

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Group {
            if stats.isKnown {
                Text("Known: \(stats.states.mature) of \(stats.cards)")
                    .foregroundStyle(MojiTint.gold)
            } else if stats.isUntouched {
                Text("Not started")
                    .foregroundStyle(theme.text.secondary)
            } else {
                Text("Learned \(stats.states.mature) · learning \(stats.states.learning + stats.states.relearning + stats.states.young) · new \(stats.states.new)")
                    .foregroundStyle(theme.text.secondary)
            }
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

private struct WordsSectionMenu: View {
    let section: MojiWordSection
    let stats: MojiWordSectionStats

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Menu {
            WordsSectionMenuItems(section: section, stats: stats)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
                .frame(width: 40, height: 32)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Section \(section.number) actions"))
    }
}

private struct WordsSectionMenuItems: View {
    let section: MojiWordSection
    let stats: MojiWordSectionStats

    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        Button {
            interactions.studySection(section)
        } label: {
            Label("Study this section", systemImage: "play.fill")
        }
        Button {
            interactions.startCustomStudy(.sectionOnly(section.number))
        } label: {
            Label("Only this section", systemImage: "scope")
        }
        Button {
            interactions.openBrowser(section: section.number)
        } label: {
            Label("Show the words", systemImage: "list.bullet")
        }
        Divider()
        Button {
            interactions.requestSectionAction(.known, section: section)
        } label: {
            Label("Mark section as known", systemImage: "checkmark.circle")
        }
        .disabled(stats.isKnown)
        Button(role: .destructive) {
            interactions.requestSectionAction(.reset, section: section)
        } label: {
            Label("Reset section", systemImage: "arrow.counterclockwise")
        }
        .disabled(stats.isUntouched)
    }
}

struct WordsWordRow: View {
    let word: MojiWord

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }

    var body: some View {
        let card = service.card(MojiWordCardID(wordID: word.id))
        let state = MojiWordCardState.of(card, today: service.snapshot.today)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: word.written)
                        .font(.system(size: 20, weight: .semibold))
                        .typesettingLanguage(Locale.Language(identifier: "ja"))
                        .foregroundStyle(theme.text.primary)
                    if word.hasKanji {
                        Text(verbatim: word.reading)
                            .font(.system(size: 14))
                            .typesettingLanguage(Locale.Language(identifier: "ja"))
                            .foregroundStyle(theme.text.secondary)
                    }
                }
                Text(verbatim: "\(word.romaji) · \(word.meaning(in: MojiLanguage.current))")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let flag = card.flag {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(flag.color)
            }
            if card.isLeech {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text.secondary)
            }
            WordsStateBadge(state: state)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct WordsStateBadge: View {
    let state: MojiWordCardState

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Text(state.badge)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(state == .mature ? MojiTint.gold : theme.text.secondary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                Capsule(style: .continuous)
                    .fill(state == .mature ? MojiTint.gold.opacity(theme.isDark ? 0.16 : 0.14) : theme.text.primary.opacity(theme.isDark ? 0.08 : 0.05))
            )
            .lineLimit(1)
            .fixedSize()
    }
}
