import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class WritingServicesStore {
    static let shared = WritingServicesStore()

    var isActive = false
    var isUnavailable = false
    var character: MojiCharacter?
    var figure: MojiWritingFigure?
    var stage: MojiWritingStage = .phantom
    var strokeIndex = 0
    var ink: [CGPoint] = []
    var isTouching = false
    var reachedEnd = false
    var isPaused = false
    var resumePoint: CGPoint?
    var phase: MojiWritingPhase = .writing
    var failure: WritingFailure?
    var writingsLeft = 0
    var writingsDone = 0
    var mistakes = 0
    var passToken = 0
    var results: [WritingResult] = []

    @ObservationIgnored var block: MojiWritingBlock?
    @ObservationIgnored var charactersByID: [String: MojiCharacter] = [:]
    @ObservationIgnored var tickedStroke: String?
    @ObservationIgnored var pauseToken: UUID?
    @ObservationIgnored var onFinish: (@MainActor ([MojiWritingCard]) -> Void)?

    private init() {}

    var prompt: WritingPrompt? {
        character.map(WritingPrompt.init)
    }

    var currentStroke: [CGPoint]? {
        guard let figure, figure.strokes.indices.contains(strokeIndex) else { return nil }
        return figure.strokes[strokeIndex]
    }

    var doneStrokes: [[CGPoint]] {
        guard let figure else { return [] }
        return Array(figure.strokes.prefix(strokeIndex))
    }

    var isFinished: Bool {
        phase == .finished
    }

    func reset() {
        isActive = false
        isUnavailable = false
        character = nil
        figure = nil
        stage = .phantom
        strokeIndex = 0
        ink = []
        isTouching = false
        reachedEnd = false
        isPaused = false
        resumePoint = nil
        phase = .writing
        failure = nil
        writingsLeft = 0
        writingsDone = 0
        mistakes = 0
        results = []
        block = nil
        charactersByID = [:]
        tickedStroke = nil
        pauseToken = nil
        onFinish = nil
    }
}

extension WritingServicesStore: WritingCanvasSource {
    var showsWholePhantom: Bool {
        stage.showsPhantom && phase != .written
    }

    var showsCurrentStroke: Bool {
        (stage.showsPhantom && phase == .writing) || failure != nil || isPaused
    }

    var showsPoints: Bool {
        (stage.showsPoints && phase == .writing) || failure != nil || isPaused
    }

    var isWritten: Bool {
        phase == .written
    }
}
