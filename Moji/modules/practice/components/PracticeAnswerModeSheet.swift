import SwiftUI

struct PracticeAnswerModeSheet: View {
    let page: MojiPage

    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: PracticeServicesStore { .shared }
    private var interactions: PracticeInteractionsStore { .shared }

    var body: some View {
        let mode = service.answerMode(for: page)
        let script = page.script
        let input = Binding(
            get: { service.answerMode(for: page).input },
            set: { interactions.setAnswerInput($0, for: page) }
        )
        let side = Binding(
            get: { service.answerMode(for: page).side },
            set: { interactions.setAnswerSide($0, for: page) }
        )

        NavigationStack {
            Form {
                Section {
                    Picker("Answer by", selection: input) {
                        ForEach(MojiAnswerInput.allCases) { option in
                            PracticeAnswerModeRow(
                                title: option.title,
                                caption: option.caption(for: script)
                            ) {
                                Image(systemName: option.systemImage)
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Answer by")
                }

                Section {
                    Picker("Answer with", selection: side) {
                        ForEach(MojiAnswerSide.allCases) { option in
                            PracticeAnswerModeRow(
                                title: option.title(for: script),
                                caption: option.caption(for: script)
                            ) {
                                Text(verbatim: option.arrow(for: script))
                                    .font(.system(size: 15, weight: .medium))
                                    .typesettingLanguage(Locale.Language(identifier: "ja"))
                            }
                            .tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .disabled(mode.input == .drawing)
                    .opacity(mode.input == .drawing ? 0.45 : 1)
                } header: {
                    Text("Answer with")
                } footer: {
                    sideFooter(mode)
                }

                Section {
                    if page.isKanji {
                        if service.usesSameAnswerModeInEveryTheme {
                            Label("Every kanji theme uses this mode", systemImage: "checkmark")
                                .foregroundStyle(theme.text.secondary)
                        } else {
                            Button("Use in every kanji theme") {
                                interactions.useAnswerModeInEveryTheme(from: page)
                            }
                        }
                    }
                    if service.usesSameAnswerModeEverywhere {
                        Label("Every page uses this mode", systemImage: "checkmark")
                            .foregroundStyle(theme.text.secondary)
                    } else {
                        Button("Use on all pages") {
                            interactions.useAnswerModeEverywhere(from: page)
                        }
                    }
                } footer: {
                    Text("Saved for the \(page.title) page. A change applies from the next question: a saved session keeps the question it stopped on.")
                }
            }
            .navigationTitle(Text("Answer mode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        interactions.closeAnswerMode()
                    }
                }
            }
        }
        .tint(theme.text.primary)
    }

    @ViewBuilder
    private func sideFooter(_ mode: MojiAnswerMode) -> some View {
        if mode.input == .drawing {
            VStack(alignment: .leading, spacing: 6) {
                Text("Drawing always asks you to draw the character, so this choice is off for now.")
                if page.isKanji {
                    if service.hasUndrawableKanji(on: page) {
                        Text("Kanji without stroke order data come as a list.")
                    }
                } else {
                    glyphFirstNote
                }
            }
        } else if !page.isKanji, mode.side == .character {
            glyphFirstNote
        }
    }

    @ViewBuilder
    private var glyphFirstNote: some View {
        let kana = service.glyphFirstKana(for: page)
        if !kana.isEmpty {
            Text("\(kana.formatted(.list(type: .and))) always show the character: their romaji is the same as another kana's.")
        }
    }
}

private struct PracticeAnswerModeRow<Leading: View>: View {
    let title: String
    let caption: String
    @ViewBuilder let leading: () -> Leading

    private var theme: AppTheme { ThemeStore.shared.currentTheme }

    var body: some View {
        HStack(spacing: 14) {
            leading()
                .foregroundStyle(theme.text.primary)
                .frame(width: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(theme.text.primary)
                Text(caption)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
}
