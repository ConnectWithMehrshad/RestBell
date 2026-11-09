import Foundation

@MainActor
final class TimerModel {
    enum Session: String {
        case work = "W"
        case rest = "R"

        var next: Self {
            self == .work ? .rest : .work
        }
    }

    enum State: Equatable {
        case ready
        case session(Session, seconds: Int)
        case countdown(to: Session, seconds: Int)

        var title: String {
            switch self {
            case .ready:
                return "RestBell"
            case let .session(session, seconds):
                let time = String(format: "%02d:%02d", seconds / 60, seconds % 60)
                return "\(session.rawValue) \(time)"
            case let .countdown(session, seconds):
                return "\(session.rawValue) in \(seconds)"
            }
        }
    }

    private(set) var state = State.ready {
        didSet {
            if state != oldValue { onStateChange(state) }
        }
    }

    private let clock = SuspendingClock()
    private let duration: (Session) -> Duration
    private let beep: () -> Void
    private let onStateChange: (State) -> Void
    private var cycle: Task<Void, Error>?

    init(
        duration: @escaping (Session) -> Duration,
        beep: @escaping () -> Void,
        onStateChange: @escaping (State) -> Void
    ) {
        self.duration = duration
        self.beep = beep
        self.onStateChange = onStateChange
    }

    func start() {
        guard cycle == nil else { return }
        cycle = Task {
            try await runCycle()
        }
    }

    func pauseAndReset() {
        cycle?.cancel()
        cycle = nil
        state = .ready
    }

    private func runCycle() async throws {
        var session = Session.work
        while true {
            try await runSession(session)
            session = session.next

            for seconds in (1...3).reversed() {
                try Task.checkCancellation()
                let nextTick = clock.now + .seconds(1)
                state = .countdown(to: session, seconds: seconds)
                beep()
                try await clock.sleep(until: nextTick)
            }
        }
    }

    private func runSession(_ session: Session) async throws {
        let deadline = clock.now.advanced(by: duration(session))
        while true {
            try Task.checkCancellation()
            let remaining = clock.now.duration(to: deadline)
            guard remaining > .zero else { return }

            let parts = remaining.components
            let seconds = Int(parts.seconds) + (parts.attoseconds > 0 ? 1 : 0)
            state = .session(session, seconds: seconds)
            try await clock.sleep(until: deadline.advanced(by: .seconds(1 - seconds)))
        }
    }
}
