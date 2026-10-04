import SwiftUI

struct WordsCardSurface<Content: View>: View {
    var isBehind = false
    var cornerRadius: CGFloat = 30
    @ViewBuilder let content: () -> Content

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(shape)
            .background {
                shape
                    .fill(fill)
                    .shadow(color: .black.opacity(theme.isDark ? 0.55 : 0.09), radius: 18, x: 0, y: 10)
                    .shadow(color: .black.opacity(theme.isDark ? 0.35 : 0.05), radius: 2, x: 0, y: 1)
            }
            .overlay {
                shape
                    .strokeBorder(border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
    }

    private var fill: Color {
        switch (theme.isDark, isBehind) {
        case (true, false): theme.bg._400
        case (true, true): theme.bg._300
        case (false, false): theme.bg._000
        case (false, true): theme.bg._200
        }
    }

    private var border: Color {
        theme.isDark ? theme.border._300 : theme.border._600.opacity(0.7)
    }
}

private struct WordsFlipFace: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool

    nonisolated var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let visible = isBack == (angle >= 90)
        content
            .rotation3DEffect(
                .degrees(isBack ? angle - 180 : angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.42
            )
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}

private struct WordsCardMotion: ViewModifier {
    let offset: CGSize
    let rotation: Double
    let scale: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static var wordsDeal: AnyTransition {
        .modifier(
            active: WordsCardMotion(offset: CGSize(width: 0, height: 14), rotation: 0, scale: 0.955, opacity: 0.4),
            identity: WordsCardMotion(offset: .zero, rotation: 0, scale: 1, opacity: 1)
        )
    }

    static func wordsFlyAway(_ button: MojiWordButton?) -> AnyTransition {
        let motion: (CGSize, Double)
        switch button {
        case .again: motion = (CGSize(width: -620, height: 80), -18)
        case .hard: motion = (CGSize(width: -90, height: 760), -6)
        case .good: motion = (CGSize(width: 620, height: 80), 18)
        case .easy: motion = (CGSize(width: 90, height: -880), 8)
        case nil: motion = (.zero, 0)
        }
        return .modifier(
            active: WordsCardMotion(offset: motion.0, rotation: motion.1, scale: button == nil ? 0.94 : 1, opacity: button == nil ? 0 : 0.6),
            identity: WordsCardMotion(offset: .zero, rotation: 0, scale: 1, opacity: 1)
        )
    }
}

struct WordsStudyDeck: View {
    let card: MojiWordStudyCard

    private var service: WordsServicesStore { .shared }

    private var behind: Int {
        min(2, max(0, card.counts.total - 1))
    }

    var body: some View {
        ZStack {
            ForEach((0..<behind).reversed(), id: \.self) { layer in
                WordsCardSurface(isBehind: true) {
                    Color.clear
                }
                .scaleEffect(1 - 0.045 * CGFloat(layer + 1), anchor: .bottom)
                .offset(y: 13 * CGFloat(layer + 1))
                .opacity(layer == 0 ? 1 : 0.7)
                .transition(.opacity)
                .accessibilityHidden(true)
            }

            WordsTopCard(card: card)
                .id(card.presentationID)
                .transition(.asymmetric(insertion: .wordsDeal, removal: .wordsFlyAway(service.flyAway?.button)))
        }
        .padding(.bottom, 26)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: behind)
    }
}

private struct WordsTopCard: View {
    let card: MojiWordStudyCard

    static let swipeThreshold: CGFloat = 110

    @State private var drag: CGSize = .zero
    @State private var crossed: MojiWordButton?

    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let angle: Double = service.isFlipped ? 180 : 0
        let canSwipe = service.isFlipped && service.options(service.studyDeck).swipeToGrade && !service.isBusy

        ZStack {
            WordsCardSurface {
                WordsCardFront(card: card)
            }
            .modifier(WordsFlipFace(angle: angle, isBack: false))

            WordsCardSurface {
                WordsCardBack(card: card)
            }
            .modifier(WordsFlipFace(angle: angle, isBack: true))
        }
        .overlay {
            WordsSwipeStamp(drag: drag.width, threshold: Self.swipeThreshold)
                .allowsHitTesting(false)
        }
        .rotationEffect(.degrees(Double(drag.width) / 24), anchor: .bottom)
        .offset(drag)
        .simultaneousGesture(swipe, including: canSwipe ? .all : .subviews)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                let horizontal = value.translation.width
                guard abs(horizontal) > abs(value.translation.height) || drag != .zero else { return }
                drag = CGSize(width: horizontal, height: value.translation.height * 0.12)
                let next: MojiWordButton? = horizontal <= -Self.swipeThreshold
                    ? .again
                    : (horizontal >= Self.swipeThreshold ? .good : nil)
                if next != crossed {
                    crossed = next
                    if next != nil {
                        interactions.swipeCrossedThreshold()
                    }
                }
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                let width = drag.width
                if width <= -Self.swipeThreshold || (width < -40 && projected < -Self.swipeThreshold * 2) {
                    interactions.grade(.again)
                } else if width >= Self.swipeThreshold || (width > 40 && projected > Self.swipeThreshold * 2) {
                    interactions.grade(.good)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        drag = .zero
                    }
                }
                crossed = nil
            }
    }
}

private struct WordsSwipeStamp: View {
    let drag: CGFloat
    let threshold: CGFloat

    var body: some View {
        let progress = min(1, abs(drag) / threshold)
        let button: MojiWordButton = drag < 0 ? .again : .good

        VStack {
            HStack {
                if drag > 0 {
                    stamp(button)
                    Spacer()
                } else {
                    Spacer()
                    stamp(button)
                }
            }
            Spacer()
        }
        .padding(22)
        .opacity(drag == 0 ? 0 : Double(progress))
    }

    private func stamp(_ button: MojiWordButton) -> some View {
        let color = button.tint ?? .primary
        return Text(button.title)
            .font(.system(size: 20, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(color, lineWidth: 3)
            )
            .rotationEffect(.degrees(button == .again ? 10 : -10))
    }
}

struct WordsHeadword: View {
    let token: MojiWordToken
    let size: CGFloat
    var furigana: FuriganaVisibility = .all
    var onOpenCharacter: ((MojiCharacter) -> Void)? = nil

    var body: some View {
        ViewThatFits(in: .horizontal) {
            headword(size)
            headword(size * 0.8)
            headword(size * 0.64)
            headword(size * 0.5)
            headword(size * 0.4)
        }
    }

    private func headword(_ size: CGFloat) -> some View {
        FuriganaTextView(
            tokens: [token],
            size: size,
            weight: .semibold,
            furigana: furigana,
            alignment: .center,
            maxScale: FuriganaTextView.headwordMaxScale,
            onOpenCharacter: onOpenCharacter
        )
        .fixedSize()
    }
}

struct WordsCardTopRow: View {
    let card: MojiWordStudyCard

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 8) {
            WordsChip(text: kindTitle)
            if let partOfSpeech = card.word.partOfSpeech {
                WordsChip(text: partOfSpeech.title)
            }
            Spacer(minLength: 0)
            if card.card.isLeech {
                WordsChip(text: String(localized: "leech"), systemImage: "exclamationmark.triangle")
            }
            if let flag = card.card.flag {
                Image(systemName: "flag.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(flag.color)
                    .accessibilityLabel(Text("Flag: \(flag.title)"))
            }
        }
    }

    private var kindTitle: String {
        if card.isCram {
            return String(localized: "extra practice")
        }
        switch card.kind {
        case .new: return MojiWordCardState.new.badge
        case .learning: return card.card.phase == .relearning ? MojiWordCardState.relearning.badge : MojiWordCardState.learning.badge
        case .review: return String(localized: "review")
        }
    }
}

struct WordsChip: View {
    let text: String
    var systemImage: String? = nil

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(theme.text.secondary)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(Capsule(style: .continuous).fill(theme.text.primary.opacity(theme.isDark ? 0.08 : 0.05)))
    }
}

private struct WordsCardFront: View {
    let card: MojiWordStudyCard

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let options = service.options(service.studyDeck)

        VStack(spacing: 0) {
            WordsCardTopRow(card: card)

            ViewThatFits(in: .vertical) {
                content(options: options, compact: false)
                ScrollView {
                    content(options: options, compact: true)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity)

            if options.typeReading {
                WordsTypeField()
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func content(options: MojiWordOptions, compact: Bool) -> some View {
        VStack(spacing: compact ? 18 : 26) {
            switch card.id.kind {
            case .recognition:
                WordsHeadword(
                    token: card.word.token,
                    size: card.word.written.count > 4 ? 40 : 50,
                    furigana: .none,
                    onOpenCharacter: { interactions.openStudyCharacter($0) }
                )
                if let sentence = card.sentence {
                    FuriganaTextView(
                        tokens: sentence.tokens,
                        size: 21,
                        furigana: FuriganaVisibility(options.frontFurigana),
                        highlightsTarget: true,
                        alignment: .center,
                        onOpenCharacter: { interactions.openStudyCharacter($0) }
                    )
                }
            case .recall:
                VStack(spacing: 10) {
                    Text(card.word.meaning(in: MojiLanguage.current))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(theme.text.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Say it in Japanese")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(theme.text.secondary)
                }
                if let translation = card.sentence?.translation(in: MojiLanguage.current), !translation.isEmpty {
                    Text(translation)
                        .font(.system(size: 17))
                        .foregroundStyle(theme.text.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct WordsTypeField: View {
    @FocusState private var isFocused: Bool

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let text = Binding(
            get: { service.typedReading },
            set: { interactions.setTypedReading($0) }
        )

        TextField(String(localized: "Type the reading"), text: text)
            .font(.system(size: 18, weight: .medium))
            .typesettingLanguage(Locale.Language(identifier: "ja"))
            .foregroundStyle(theme.text.primary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($isFocused)
            .onSubmit { interactions.showAnswer() }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .liquidChromeCapsule(interactive: true)
            .onAppear {
                isFocused = !service.isFlipped
            }
            .onChange(of: service.isFlipped) { _, isFlipped in
                if isFlipped {
                    isFocused = false
                }
            }
    }
}

private struct WordsCardBack: View {
    let card: MojiWordStudyCard

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }
    private var interactions: WordsInteractionsStore { .shared }

    var body: some View {
        let options = service.options(service.studyDeck)
        let word = card.word

        VStack(spacing: 0) {
            WordsCardTopRow(card: card)
                .padding(.horizontal, 20)
                .padding(.top, 18)

            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        HStack(alignment: .center, spacing: 10) {
                            WordsHeadword(
                                token: word.token,
                                size: word.written.count > 4 ? 38 : 46,
                                onOpenCharacter: { interactions.openStudyCharacter($0) }
                            )
                            if options.replayButtons {
                                WordsSpeakerButton(label: String(localized: "Play the word")) {
                                    interactions.replayWord()
                                }
                            }
                        }
                        if !word.readingLine.isEmpty {
                            Text(verbatim: word.readingLine)
                                .font(.system(size: 16, weight: .medium))
                                .typesettingLanguage(Locale.Language(identifier: "ja"))
                                .foregroundStyle(theme.text.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Text(word.meaning(in: MojiLanguage.current))
                            .font(.system(size: 23, weight: .bold))
                            .foregroundStyle(theme.text.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }

                    if let verdict = service.typedVerdict {
                        WordsVerdictRow(verdict: verdict, word: word)
                    }

                    if let sentence = card.sentence {
                        Divider()
                            .overlay(theme.border._200.opacity(0.6))
                        VStack(spacing: 8) {
                            FuriganaTextView(
                                tokens: sentence.tokens,
                                size: 20,
                                furigana: .all,
                                highlightsTarget: true,
                                alignment: .center,
                                onOpenCharacter: { interactions.openStudyCharacter($0) }
                            )
                            let translation = sentence.translation(in: MojiLanguage.current)
                            if !translation.isEmpty {
                                Text(translation)
                                    .font(.system(size: 15))
                                    .foregroundStyle(theme.text.secondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if options.replayButtons {
                                WordsSpeakerButton(
                                    label: String(localized: "Play the sentence"),
                                    systemImage: MojiWordVoice.hasRecording(sentence) ? "speaker.wave.2.fill" : "speaker.wave.1"
                                ) {
                                    interactions.replaySentence()
                                }
                                .padding(.top, 2)
                            }
                            if let credit = WordsSentenceCredit.text(for: sentence) {
                                Text(verbatim: credit)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.text.secondary.opacity(0.7))
                            }
                        }
                    }

                    let kanji = service.kanjiCharacters(of: word)
                    if !kanji.isEmpty {
                        WordsKanjiChips(characters: kanji) {
                            interactions.openStudyCharacter($0)
                        }
                    }

                    if let note = service.note(for: word) {
                        WordsNoteBox(note: note)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 22)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

struct WordsSpeakerButton: View {
    let label: String
    var systemImage = "speaker.wave.2.fill"
    let action: () -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        LiquidGlassButton(shape: .circle, size: 38, accessibilityLabel: label, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
        }
    }
}

private struct WordsVerdictRow: View {
    let verdict: WordsTypedVerdict
    let word: MojiWord

    var body: some View {
        switch verdict {
        case .right:
            Label("You typed it right", systemImage: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MojiTint.correct)
        case .wrong(let typed):
            VStack(spacing: 2) {
                Label("You typed: \(typed)", systemImage: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MojiTint.wrong)
                Text("Right: \(word.reading) · \(word.romaji)")
                    .font(.system(size: 14, weight: .medium))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(MojiTint.correct)
            }
            .multilineTextAlignment(.center)
        case .skipped:
            EmptyView()
        }
    }
}

struct WordsKanjiChips: View {
    let characters: [MojiCharacter]
    let onOpen: (MojiCharacter) -> Void

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        VStack(spacing: 8) {
            Text("Kanji in this word")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
            MojiFlowLayout(alignment: .center, spacing: 8, lineSpacing: 8) {
                ForEach(characters) { character in
                    Button {
                        onOpen(character)
                    } label: {
                        HStack(spacing: 6) {
                            GlyphText(text: character.glyph, size: 22, color: theme.text.primary)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(verbatim: character.reading ?? character.romaji)
                                    .font(.system(size: 11, weight: .medium))
                                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                                    .foregroundStyle(theme.text.secondary)
                                if let meaning = character.shortMeaning {
                                    Text(meaning)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(theme.text.primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .liquidChromeCapsule(interactive: true)
                    .accessibilityLabel(Text(verbatim: "\(character.glyph), \(character.meaning ?? character.romaji)"))
                }
            }
        }
    }
}

struct WordsNoteBox: View {
    let note: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "note.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.text.secondary)
            Text(note)
                .font(.system(size: 14))
                .foregroundStyle(theme.text.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.text.primary.opacity(theme.isDark ? 0.06 : 0.04))
        )
    }
}

enum WordsSentenceCredit {
    static func text(for sentence: MojiWordSentence) -> String? {
        guard let source = sentence.source else { return nil }
        var parts: [String] = []
        if let id = source.tatoebaID {
            parts.append("Tatoeba #\(id)")
        }
        if let speaker = source.speaker, !speaker.isEmpty {
            parts.append(String(localized: "voice: \(speaker)"))
        }
        if let license = source.license, !license.isEmpty {
            parts.append(license)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
