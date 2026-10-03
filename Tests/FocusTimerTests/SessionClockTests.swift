import Foundation

// This runner uses only the Swift standard library and Foundation so it also
// works with Command Line Tools, without the XCTest bundled with full Xcode.
@main
struct SessionClockTests {
    static func main() {
        let suite = SessionClockTests()
        let cases: [(String, () -> Void)] = [
            ("idle/start and stable deadline", suite.testIdleClockStartsWithADeadlineAndIgnoresRepeatedStart),
            ("fractional pause/resume", suite.testPauseCapturesElapsedTimeAndResumePreservesRemainder),
            ("delayed completion exactly once", suite.testDelayedTickCompletesExactlyOnceWithoutGoingNegative),
            ("restart completed session", suite.testCompletedSessionCanRestartAtFullDuration),
            ("reset and duration change", suite.testResetAndDurationChangeCancelTheOldDeadline),
            ("invalid duration normalization", suite.testInvalidDurationsAlwaysProduceAFiniteSupportedSession),
            ("pause at deadline", suite.testPauseAtDeadlineCompletesAndCannotReviveAnExpiredRemainder),
            ("clock rollback bounds", suite.testClockMovingBackwardKeepsProgressInBounds),
        ]
        for (name, test) in cases {
            test()
            print("PASS: \(name)")
        }
        print("All \(cases.count) clock regression tests passed.")
    }

    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    func testIdleClockStartsWithADeadlineAndIgnoresRepeatedStart() {
        var clock = SessionClock(duration: 300)
        expectEqual(clock.state, .idle)
        expectEqual(clock.remaining, 300)
        expectEqual(clock.progress, 0)
        expectNil(clock.deadline)
        expectFalse(clock.tick(at: origin))

        clock.start(at: origin)
        expectEqual(clock.state, .running)
        expectEqual(clock.deadline, origin.addingTimeInterval(300))

        clock.start(at: origin.addingTimeInterval(30))
        expectEqual(clock.deadline, origin.addingTimeInterval(300))
        expectFalse(clock.tick(at: origin.addingTimeInterval(75)))
        expectEqual(clock.remaining, 225)
        expectEqual(clock.progress, 0.25, accuracy: 0.000_001)
    }

    func testPauseCapturesElapsedTimeAndResumePreservesRemainder() {
        var clock = SessionClock(duration: 300)
        clock.start(at: origin)
        clock.pause(at: origin.addingTimeInterval(72.5))

        expectEqual(clock.state, .paused)
        expectEqual(clock.remaining, 227.5)
        expectNil(clock.deadline)
        expectFalse(clock.tick(at: origin.addingTimeInterval(1_000)))
        expectEqual(clock.remaining, 227.5)

        clock.start(at: origin.addingTimeInterval(1_000))
        expectEqual(clock.deadline, origin.addingTimeInterval(1_227.5))
        expectFalse(clock.tick(at: origin.addingTimeInterval(1_027.5)))
        expectEqual(clock.remaining, 200)
        expectTrue(clock.tick(at: origin.addingTimeInterval(1_227.5)))
    }

    func testDelayedTickCompletesExactlyOnceWithoutGoingNegative() {
        var clock = SessionClock(duration: 300)
        clock.start(at: origin)

        // A suspended machine or delayed refresh can skip the whole deadline.
        expectTrue(clock.tick(at: origin.addingTimeInterval(3_600)))
        expectEqual(clock.state, .completed)
        expectEqual(clock.remaining, 0)
        expectEqual(clock.progress, 1)
        expectNil(clock.deadline)
        expectFalse(clock.tick(at: origin.addingTimeInterval(3_601)))
        expectFalse(clock.tick(at: origin.addingTimeInterval(7_200)))
    }

    func testCompletedSessionCanRestartAtFullDuration() {
        var clock = SessionClock(duration: 120)
        clock.start(at: origin)
        expectTrue(clock.tick(at: origin.addingTimeInterval(120)))

        clock.start(at: origin.addingTimeInterval(500))
        expectEqual(clock.state, .running)
        expectEqual(clock.remaining, 120)
        expectEqual(clock.progress, 0)
        expectEqual(clock.deadline, origin.addingTimeInterval(620))
        expectTrue(clock.tick(at: origin.addingTimeInterval(620)))
        expectFalse(clock.tick(at: origin.addingTimeInterval(621)))
    }

    func testResetAndDurationChangeCancelTheOldDeadline() {
        var clock = SessionClock(duration: 600)
        clock.start(at: origin)
        clock.tick(at: origin.addingTimeInterval(150))
        clock.reset()

        expectEqual(clock.state, .idle)
        expectEqual(clock.remaining, 600)
        expectEqual(clock.progress, 0)
        expectNil(clock.deadline)

        clock.start(at: origin)
        clock.setDuration(900)
        expectEqual(clock.state, .idle)
        expectEqual(clock.duration, 900)
        expectEqual(clock.remaining, 900)
        expectNil(clock.deadline)
        expectFalse(clock.tick(at: origin.addingTimeInterval(1_000)))
    }

    func testInvalidDurationsAlwaysProduceAFiniteSupportedSession() {
        expectEqual(SessionClock(duration: -50).duration, 60)
        expectEqual(SessionClock(duration: 0).duration, 60)
        expectEqual(SessionClock(duration: 50_000).duration, 10_800)
        expectEqual(SessionClock(duration: .nan).duration, 1_500)
        expectEqual(SessionClock(duration: .infinity).duration, 1_500)
        expectEqual(SessionClock(duration: -.infinity).duration, 1_500)

        var clock = SessionClock()
        clock.setDuration(.nan)
        expectEqual(clock.remaining, 1_500)
        expectEqual(clock.progress, 0)
    }

    func testPauseAtDeadlineCompletesAndCannotReviveAnExpiredRemainder() {
        var clock = SessionClock(duration: 60)
        clock.start(at: origin)
        clock.pause(at: origin.addingTimeInterval(60))

        expectEqual(clock.state, .completed)
        expectEqual(clock.remaining, 0)
        expectNil(clock.deadline)
        clock.pause(at: origin.addingTimeInterval(100))
        expectEqual(clock.state, .completed)
    }

    func testClockMovingBackwardKeepsProgressInBounds() {
        var clock = SessionClock(duration: 60)
        clock.start(at: origin)
        clock.tick(at: origin.addingTimeInterval(-10))

        expectEqual(clock.remaining, 60)
        expectEqual(clock.progress, 0)
    }
}

private func expectEqual<Value: Equatable>(
    _ actual: Value,
    _ expected: Value,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard actual == expected else {
        fatalError("Expected \(expected), received \(actual)", file: file, line: line)
    }
}

private func expectEqual(
    _ actual: Double,
    _ expected: Double,
    accuracy: Double,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard abs(actual - expected) <= accuracy else {
        fatalError("Expected \(expected) ± \(accuracy), received \(actual)", file: file, line: line)
    }
}

private func expectNil<Value>(
    _ value: Value?,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard value == nil else {
        fatalError("Expected nil, received \(String(describing: value))", file: file, line: line)
    }
}

private func expectTrue(
    _ value: Bool,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard value else { fatalError("Expected true", file: file, line: line) }
}

private func expectFalse(
    _ value: Bool,
    file: StaticString = #file,
    line: UInt = #line
) {
    guard !value else { fatalError("Expected false", file: file, line: line) }
}
