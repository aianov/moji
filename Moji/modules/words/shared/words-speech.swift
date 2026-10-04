import AVFoundation

enum MojiWordVoice {
    static let fileExtension = "m4a"

    static func url(for audioID: String, in bundle: Bundle = .main) -> URL? {
        guard !audioID.isEmpty else { return nil }
        return bundle.url(forResource: audioID, withExtension: fileExtension)
    }

    static func wordItems(_ word: MojiWord) -> [MojiWordSpeechItem] {
        if let url = url(for: word.id) {
            return [.clip(url)]
        }
        return [.text(word.hasKanji ? word.written : word.reading)]
    }

    static func sentenceItems(_ sentence: MojiWordSentence, allowSynthesis: Bool) -> [MojiWordSpeechItem] {
        if let audioID = sentence.audioID, let url = url(for: audioID) {
            return [.clip(url)]
        }
        return allowSynthesis ? [.text(sentence.text)] : []
    }

    static func hasRecording(_ sentence: MojiWordSentence) -> Bool {
        sentence.audioID.flatMap { url(for: $0) } != nil
    }
}

enum MojiWordSpeechItem: Equatable {
    case clip(URL)
    case text(String)
    case pause(Double)
}

@MainActor
final class MojiWordSpeech: NSObject {
    static let shared = MojiWordSpeech()

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var pending: [MojiWordSpeechItem] = []
    private var current: ObjectIdentifier?
    private var generation = 0
    private var voice: AVSpeechSynthesisVoice?
    private var isPrepared = false

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    func play(_ items: [MojiWordSpeechItem]) {
        prepareIfNeeded()
        MojiSpeech.shared.stop()
        stop()
        pending = items
        advance(generation)
    }

    func stop() {
        generation += 1
        pending = []
        current = nil
        player?.stop()
        player = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    private func advance(_ expected: Int) {
        guard expected == generation, !pending.isEmpty else { return }
        let item = pending.removeFirst()
        switch item {
        case .clip(let url):
            guard let clip = try? AVAudioPlayer(contentsOf: url) else {
                advance(expected)
                return
            }
            clip.delegate = self
            clip.prepareToPlay()
            player = clip
            current = ObjectIdentifier(clip)
            clip.play()
        case .text(let text):
            guard !text.isEmpty else {
                advance(expected)
                return
            }
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.7
            utterance.preUtteranceDelay = 0.05
            current = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        case .pause(let seconds):
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                self?.advance(expected)
            }
        }
    }

    private func itemDidFinish(_ item: ObjectIdentifier) {
        guard item == current else { return }
        current = nil
        player = nil
        advance(generation)
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let japanese = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        voice = japanese.max { lhs, rhs in
            let lhsScore = lhs.quality.rawValue * 2 + (lhs.gender == .female ? 1 : 0)
            let rhsScore = rhs.quality.rawValue * 2 + (rhs.gender == .female ? 1 : 0)
            return lhsScore < rhsScore
        } ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }
}

extension MojiWordSpeech: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let item = ObjectIdentifier(player)
        Task { @MainActor in
            self.itemDidFinish(item)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let item = ObjectIdentifier(player)
        Task { @MainActor in
            self.itemDidFinish(item)
        }
    }
}

extension MojiWordSpeech: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let item = ObjectIdentifier(utterance)
        Task { @MainActor in
            self.itemDidFinish(item)
        }
    }
}
