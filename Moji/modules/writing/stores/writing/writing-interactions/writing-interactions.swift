import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class WritingInteractionsStore {
    static let shared = WritingInteractionsStore()

    private static let writtenPause: Duration = .milliseconds(800)
    private static let stageDropPause: Duration = .milliseconds(1300)
    private static let strokeRetryPause: Duration = .milliseconds(650)

    private var service: WritingServicesStore { .shared }
    private var actions: WritingActionsStore { .shared }
    private var preferences: MojiPreferencesStore { .shared }

    private init() {}

    @discardableResult
    func start(
        _ characters: [MojiCharacter],
        onFinish: (@MainActor ([MojiWritingCard]) -> Void)? = nil
    ) -> Bool {
        stop()
        guard let block = actions.makeBlockAction(characters) else {
            service.isUnavailable = true
            return false
        }
        var byID: [String: MojiCharacter] = [:]
        for character in characters where byID[character.id] == nil {
            byID[character.id] = character
        }
        service.charactersByID = byID
        service.block = block
        service.onFinish = onFinish
        service.isActive = true
        service.passToken += 1
        sync()
        return true
    }

    func stop() {
        if service.isActive {
            actions.stopSpeakingAction()
        }
        service.reset()
    }

    func handle(_ touch: WritingTouch) {
        guard var block = service.block, block.phase == .writing else { return }
        var event: MojiWritingEvent?
        switch touch {
        case .began(let point):
            event = block.touchBegan(at: point)
        case .moved(let points):
            for point in points {
                guard let next = block.touchMoved(to: point) else { continue }
                event = next
                if block.phase != .writing { break }
            }
        case .ended(let point):
            event = block.touchEnded(at: point)
        case .cancelled:
            block.touchCancelled()
        }
        service.block = block
        sync()
        respond(to: event)
    }

    private func respond(to event: MojiWritingEvent?) {
        switch event {
        case .reachedEnd(let stroke), .strokeDone(let stroke):
            tick(stroke)
        case .written:
            MojiHaptics.success()
            if preferences.speaksCharacters, let character = service.character {
                actions.speakAction(character)
            }
            pause(Self.writtenPause)
        case .failed:
            MojiHaptics.error()
            let isStrokeRetry = service.block?.verdict == .strokeAgain
            pause(isStrokeRetry ? Self.strokeRetryPause : Self.stageDropPause)
        case .paused, nil:
            break
        }
    }

    private func tick(_ stroke: Int) {
        let key = "\(service.passToken).\(stroke)"
        guard service.tickedStroke != key else { return }
        service.tickedStroke = key
        MojiHaptics.selection()
    }

    private func pause(_ duration: Duration) {
        let token = UUID()
        service.pauseToken = token
        Task {
            try? await Task.sleep(for: duration)
            guard service.pauseToken == token else { return }
            service.pauseToken = nil
            resume()
        }
    }

    private func resume() {
        guard var block = service.block else { return }
        block.advance()
        service.block = block
        service.passToken += 1
        sync()
        guard block.isFinished else { return }
        service.results = block.cards.compactMap { card in
            service.charactersByID[card.id].map { WritingResult(character: $0, mistakes: card.mistakes) }
        }
        let onFinish = service.onFinish
        service.onFinish = nil
        onFinish?(block.cards)
    }

    private func sync() {
        guard let block = service.block else { return }
        let pass = block.pass
        let tracer = pass.tracer

        assign(\.character, service.charactersByID[block.card.id])
        assign(\.figure, pass.figure)
        assign(\.stage, pass.stage)
        assign(\.strokeIndex, pass.strokeIndex)
        assign(\.ink, tracer?.ink ?? [])
        assign(\.isTouching, tracer?.isTouching ?? false)
        assign(\.reachedEnd, tracer?.hasReachedEnd ?? false)
        assign(\.isPaused, tracer?.isPaused ?? false)
        assign(\.resumePoint, tracer?.resumePoint)
        assign(\.phase, block.phase)
        assign(\.writingsLeft, block.writingsLeft)
        assign(\.writingsDone, block.writingsDone)
        assign(\.mistakes, block.mistakes)

        if case .failed(let reason) = block.phase {
            assign(\.failure, WritingFailure(
                reason: reason,
                stroke: pass.strokeIndex,
                touch: tracer?.touchDown,
                verdict: block.verdict
            ))
        } else {
            assign(\.failure, nil)
        }
    }

    private func assign<Value: Equatable>(
        _ keyPath: ReferenceWritableKeyPath<WritingServicesStore, Value>,
        _ value: Value
    ) {
        guard service[keyPath: keyPath] != value else { return }
        service[keyPath: keyPath] = value
    }
}
