import SwiftUI

struct ProfileSettingsSheet: View {
    private var theme: AppTheme { ThemeStore.shared.currentTheme }
    private var service: ProfileServicesStore { .shared }
    private var interactions: ProfileInteractionsStore { .shared }
    private var preferences: MojiPreferencesStore { .shared }

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        let appearance = Binding(
            get: { ThemeStore.shared.preference },
            set: { interactions.setAppearance($0) }
        )
        let speaksCharacters = Binding(
            get: { preferences.speaksCharacters },
            set: { interactions.setSpeaksCharacters($0) }
        )
        let isResetConfirmPresented = Binding(
            get: { service.isResetConfirmPresented },
            set: { if !$0 { interactions.cancelReset() } }
        )

        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: appearance) {
                        ForEach(ThemeAppearancePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Toggle("Speak characters", isOn: speaksCharacters)
                        .tint(MojiTint.correct)
                } header: {
                    Text("Practice")
                } footer: {
                    Text("Characters are read by native Japanese speakers. The recordings are inside the app, so it works offline.")
                }

                BackupSettingsSection()

                Section {
                    Button("Erase all progress", role: .destructive) {
                        interactions.requestReset()
                    }
                } footer: {
                    Text("Removes lesson progress, saved sessions, mastery, word cards and the streak history from this iPhone.")
                }

                Section {
                    LabeledContent("Version", value: version)
                    LabeledContent("Voice", value: MojiVoiceLibrary.credit)
                    LabeledContent("Stroke order", value: MojiStrokeLibrary.credit)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Kana: NHK WORLD-JAPAN, Easy Japanese. Words: JapanesePod101. A few words: AivisSpeech, voice morioki.")
                        Text("Stroke order: KanjiVG by Ulrich Apel, kanjivg.tagaini.net, CC BY-SA 3.0.")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        interactions.closeSettings()
                    }
                }
            }
            .alert("Erase all progress?", isPresented: isResetConfirmPresented) {
                Button("Erase", role: .destructive) {
                    interactions.confirmReset()
                }
                Button("Cancel", role: .cancel) {
                    interactions.cancelReset()
                }
            } message: {
                Text("Lessons, sessions, mastery and your streak history will be gone. This can't be undone.")
            }
            .backupPresentations()
        }
        .tint(theme.text.primary)
    }
}
