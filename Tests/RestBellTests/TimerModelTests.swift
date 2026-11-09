import Testing
@testable import RestBell

@MainActor
struct TimerModelTests {
    @Test
    func alternatesSessionsWithThreeAlertsEachWay() async throws {
        var updates: [TimerModel.State] = []
        var alertsAtSessionStart: [Int] = []
        var alerts = 0
        let timer = TimerModel(
            duration: { _ in .milliseconds(100) },
            beep: { alerts += 1 },
            onStateChange: { state in
                updates.append(state)
                if case .session = state { alertsAtSessionStart.append(alerts) }
            }
        )
        defer { timer.pauseAndReset() }

        timer.start()
        timer.start()
        try await waitUntil { updates.count >= 9 }

        #expect(Array(updates.prefix(9)) == [
            .session(.work, seconds: 1),
            .countdown(to: .rest, seconds: 3),
            .countdown(to: .rest, seconds: 2),
            .countdown(to: .rest, seconds: 1),
            .session(.rest, seconds: 1),
            .countdown(to: .work, seconds: 3),
            .countdown(to: .work, seconds: 2),
            .countdown(to: .work, seconds: 1),
            .session(.work, seconds: 1)
        ])
        #expect(Array(alertsAtSessionStart.prefix(3)) == [0, 3, 6])
    }

    @Test
    func resetCancelsAlertsAndNextStartBeginsWithWork() async throws {
        var workStarts = 0
        var alerts = 0
        let timer = TimerModel(
            duration: { _ in .milliseconds(50) },
            beep: { alerts += 1 },
            onStateChange: { state in
                if state == .session(.work, seconds: 1) { workStarts += 1 }
            }
        )
        defer { timer.pauseAndReset() }

        timer.start()
        try await waitUntil { alerts >= 1 }
        timer.pauseAndReset()
        try await Task.sleep(for: .milliseconds(1100))
        #expect(timer.state == .ready)
        #expect(alerts == 1)

        timer.start()
        try await waitUntil { workStarts >= 2 }
        #expect(workStarts == 2)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        while !condition() && clock.now < deadline {
            try await clock.sleep(for: .milliseconds(10))
        }
        try #require(condition())
    }
}
