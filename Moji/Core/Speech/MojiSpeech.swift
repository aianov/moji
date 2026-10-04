import AVFoundation

@MainActor
final class MojiSpeech {
    static let shared = MojiSpeech()

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var queuePlayer: AVQueuePlayer?
    private var voice: AVSpeechSynthesisVoice?
    private var isPrepared = false

    private init() {}

    func speak(_ character: MojiCharacter) {
        prepareIfNeeded()
        stop()

        if let url = MojiVoiceLibrary.url(for: character),
           let clip = try? AVAudioPlayer(contentsOf: url) {
            clip.prepareToPlay()
            clip.play()
            player = clip
            return
        }
        speakWithSystemVoice(character.speech)
    }

    func speak(sequence characters: [MojiCharacter]) {
        prepareIfNeeded()
        stop()

        let urls = characters.compactMap { MojiVoiceLibrary.url(for: $0) }
        guard !urls.isEmpty, urls.count == characters.count else {
            speakWithSystemVoice(characters.map(\.speech).joined())
            return
        }
        let queue = AVQueuePlayer(items: urls.map { AVPlayerItem(url: $0) })
        queue.play()
        queuePlayer = queue
    }

    func stop() {
        player?.stop()
        player = nil
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        queuePlayer = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func speakWithSystemVoice(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.7
        utterance.preUtteranceDelay = 0.05
        synthesizer.speak(utterance)
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers]
        )
        try? session.setActive(true)

        let japanese = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        voice = japanese.max { lhs, rhs in
            let lhsScore = lhs.quality.rawValue * 2 + (lhs.gender == .female ? 1 : 0)
            let rhsScore = rhs.quality.rawValue * 2 + (rhs.gender == .female ? 1 : 0)
            return lhsScore < rhsScore
        } ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }
}
