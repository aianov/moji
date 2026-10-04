import SwiftUI

enum FuriganaVisibility: Equatable {
    case all
    case exceptTarget
    case none

    init(_ front: MojiWordFrontFurigana) {
        switch front {
        case .all: self = .all
        case .exceptWord: self = .exceptTarget
        case .none: self = .none
        }
    }

    func shows(_ token: MojiWordToken) -> Bool {
        switch self {
        case .all: true
        case .exceptTarget: !token.isTarget
        case .none: false
        }
    }
}

struct MojiFlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 4

    private struct Line {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(subviews, width: proposal.width ?? .infinity)
        let height = lines.reduce(0) { $0 + $1.height } + CGFloat(max(0, lines.count - 1)) * lineSpacing
        let width = lines.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(subviews, width: bounds.width) {
            var x: CGFloat
            if alignment == .center {
                x = bounds.minX + max(0, bounds.width - line.width) / 2
            } else if alignment == .trailing {
                x = bounds.maxX - line.width
            } else {
                x = bounds.minX
            }
            for item in line.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + line.height - item.size.height),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.items.isEmpty, current.width + spacing + size.width > width {
                lines.append(current)
                current = Line()
            }
            current.width += (current.items.isEmpty ? 0 : spacing) + size.width
            current.height = max(current.height, size.height)
            current.items.append((index, size))
        }
        if !current.items.isEmpty {
            lines.append(current)
        }
        return lines
    }
}

private struct FuriganaCharacterKey: Hashable {
    let token: Int
    let segment: Int
    let offset: Int
}

private struct FuriganaTooltip: Equatable {
    let token: Int
    let text: String
    let generation: Int
}

struct FuriganaTextView: View {
    let tokens: [MojiWordToken]
    var size: CGFloat = 22
    var weight: Font.Weight = .regular
    var furigana: FuriganaVisibility = .all
    var highlightsTarget = false
    var alignment: HorizontalAlignment = .leading
    var maxScale: CGFloat = 2.2
    var onOpenCharacter: ((MojiCharacter) -> Void)? = nil

    static let tooltipTime: Duration = .seconds(2)
    static let headwordMaxScale: CGFloat = 1.3

    @ScaledMetric(relativeTo: .title3) private var scale: CGFloat = 1
    @State private var tooltip: FuriganaTooltip?
    @State private var popover: FuriganaCharacterKey?
    @State private var generation = 0

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: WordsServicesStore { .shared }

    private var baseSize: CGFloat {
        size * min(scale, maxScale)
    }

    private var rubySize: CGFloat {
        max(9, baseSize * 0.48)
    }

    private var reservesRuby: Bool {
        tokens.contains { $0.hasKanji && furigana.shows($0) }
    }

    var body: some View {
        MojiFlowLayout(alignment: alignment, spacing: 1, lineSpacing: baseSize * 0.28) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                tokenView(token, index: index)
                    .zIndex(tooltip?.token == index ? 1 : 0)
            }
        }
        .task(id: tooltip?.generation) {
            guard let current = tooltip?.generation else { return }
            try? await Task.sleep(for: Self.tooltipTime)
            guard tooltip?.generation == current else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                tooltip = nil
            }
        }
    }

    private func tokenView(_ token: MojiWordToken, index: Int) -> some View {
        let segments = service.segments(for: token)
        let showsRuby = token.hasKanji && furigana.shows(token)
        let romaji = MojiWordRomaji.romaji(of: token)
        let isHighlighted = highlightsTarget && token.isTarget

        return HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.offset) { segmentIndex, segment in
                segmentView(
                    segment,
                    token: token,
                    index: index,
                    segmentIndex: segmentIndex,
                    showsRuby: showsRuby,
                    romaji: romaji,
                    isHighlighted: isHighlighted
                )
            }
        }
        .padding(.horizontal, isHighlighted ? 3 : 0)
        .background(alignment: .bottom) {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.text.primary.opacity(theme.isDark ? 0.14 : 0.08))
                    .frame(height: baseSize * 1.32)
                    .offset(y: baseSize * 0.08)
            }
        }
        .overlay(alignment: .top) {
            if let tooltip, tooltip.token == index {
                FuriganaTooltipBubble(text: tooltip.text)
                    .offset(y: (reservesRuby ? rubySize * 1.25 : 0) - 32)
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: token.surface))
        .accessibilityValue(Text(verbatim: [token.reading, romaji].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(romaji == nil ? [] : .isButton)
        .accessibilityAction {
            showTooltip(romaji, for: index)
        }
    }

    private func segmentView(
        _ segment: MojiRubySegment,
        token: MojiWordToken,
        index: Int,
        segmentIndex: Int,
        showsRuby: Bool,
        romaji: String?,
        isHighlighted: Bool
    ) -> some View {
        VStack(spacing: 0) {
            if reservesRuby {
                Text(verbatim: segment.ruby ?? " ")
                    .font(.system(size: rubySize, weight: .regular))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .opacity(showsRuby && segment.ruby != nil ? 1 : 0)
                    .padding(.bottom, rubySize * 0.12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTooltip(romaji, for: index)
                    }
            }
            HStack(spacing: 0) {
                ForEach(Array(segment.base.enumerated()), id: \.offset) { offset, character in
                    characterView(
                        character,
                        key: FuriganaCharacterKey(token: index, segment: segmentIndex, offset: offset),
                        segment: segment,
                        token: token,
                        romaji: romaji,
                        isHighlighted: isHighlighted
                    )
                }
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func characterView(
        _ character: Character,
        key: FuriganaCharacterKey,
        segment: MojiRubySegment,
        token: MojiWordToken,
        romaji: String?,
        isHighlighted: Bool
    ) -> some View {
        let glyph = Text(verbatim: String(character))
            .font(.system(size: baseSize, weight: isHighlighted ? .semibold : weight))
            .typesettingLanguage(Locale.Language(identifier: "ja"))
            .foregroundStyle(theme.text.primary)
            .fixedSize()
            .contentShape(Rectangle())
            .onTapGesture {
                showTooltip(romaji, for: key.token)
            }

        if MojiFurigana.isKanji(character) {
            let isPresented = Binding(
                get: { popover == key },
                set: { if !$0, popover == key { popover = nil } }
            )
            glyph
                .onLongPressGesture(minimumDuration: 0.35) {
                    tooltip = nil
                    popover = key
                    MojiHaptics.selection()
                }
                .popover(isPresented: isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    FuriganaKanjiCard(
                        glyph: String(character),
                        reading: segment.base.count == 1 ? segment.ruby : nil,
                        word: token,
                        character: MojiAlphabetCatalog.shared.character("j-\(character)"),
                        onOpen: onOpenCharacter.map { open in
                            { character in
                                popover = nil
                                open(character)
                            }
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                }
        } else {
            glyph
        }
    }

    private func showTooltip(_ romaji: String?, for index: Int) {
        guard let romaji else { return }
        if tooltip?.token == index {
            withAnimation(.easeOut(duration: 0.15)) {
                tooltip = nil
            }
            return
        }
        generation += 1
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            tooltip = FuriganaTooltip(token: index, text: romaji, generation: generation)
        }
        MojiHaptics.selection()
    }
}

private struct FuriganaTooltipBubble: View {
    let text: String

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(theme.text.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .liquidChromeCapsule()
            .fixedSize()
    }
}

struct FuriganaKanjiCard: View {
    let glyph: String
    let reading: String?
    let word: MojiWordToken
    let character: MojiCharacter?
    var onOpen: ((MojiCharacter) -> Void)?

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    private var kana: String? {
        reading ?? character?.reading
    }

    private var romaji: String? {
        if let reading {
            return MojiWordRomaji.spell(reading)
        }
        return character?.romaji
    }

    private var otherReadings: String? {
        guard let character else { return nil }
        var all = [character.reading].compactMap { $0 } + character.otherReadings.map(\.kana)
        if let reading {
            all.removeAll { MojiWordRomaji.hiragana($0.filter { $0 != "(" && $0 != ")" }) == reading }
        }
        return all.isEmpty ? nil : all.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 6) {
            GlyphText(text: glyph, size: 58, color: theme.text.primary)
                .frame(height: 66)

            if let romaji {
                Text(verbatim: romaji)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(theme.text.primary)
            }
            if let kana {
                Text(verbatim: kana)
                    .font(.system(size: 16, weight: .medium))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.secondary)
            }
            if let meaning = character?.meaning {
                Text(meaning)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.text.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            if reading == nil, let wordReading = word.reading, word.surface.count > 1 {
                Text("In \(word.surface): \(wordReading)")
                    .font(.system(size: 12, weight: .medium))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.secondary)
                    .multilineTextAlignment(.center)
            }
            if let otherReadings {
                Text("Readings: \(otherReadings)")
                    .font(.system(size: 12))
                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                    .foregroundStyle(theme.text.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let character, let onOpen {
                Button {
                    onOpen(character)
                } label: {
                    Label("Open the kanji", systemImage: "arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.text.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .liquidChromeCapsule(interactive: true)
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minWidth: 170, maxWidth: 250)
    }
}
