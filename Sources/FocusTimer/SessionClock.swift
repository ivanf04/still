import Foundation

/// The timer's deadline-based state, independent of the UI's refresh frequency.
struct SessionClock: Sendable {
    enum State: Equatable, Sendable {
        case idle
        case running
        case paused
        case completed
    }

    private(set) var state: State = .idle
    private(set) var duration: TimeInterval
    private(set) var remaining: TimeInterval
    private(set) var deadline: Date?

    init(duration: TimeInterval = 1_500) {
        let normalizedDuration = Self.normalized(duration)
        self.duration = normalizedDuration
        self.remaining = normalizedDuration
    }

    /// The elapsed fraction of this session, from zero to one.
    var progress: Double {
        min(1, max(0, 1 - remaining / duration))
    }

    mutating func start(at now: Date = Date()) {
        guard state != .running else { return }

        if state == .completed {
            remaining = duration
        }

        deadline = now.addingTimeInterval(remaining)
        state = .running
    }

    mutating func pause(at now: Date = Date()) {
        guard state == .running else { return }
        if tick(at: now) { return }

        deadline = nil
        state = .paused
    }

    mutating func reset() {
        remaining = duration
        deadline = nil
        state = .idle
    }

    /// Choosing a duration prepares a fresh, idle session.
    mutating func setDuration(_ seconds: TimeInterval) {
        duration = Self.normalized(seconds)
        reset()
    }

    /// Returns true exactly when this call completes a running session.
    @discardableResult
    mutating func tick(at now: Date = Date()) -> Bool {
        guard state == .running, let deadline else { return false }

        remaining = min(duration, max(0, deadline.timeIntervalSince(now)))
        guard remaining == 0 else { return false }

        self.deadline = nil
        state = .completed
        return true
    }

    private static func normalized(_ seconds: TimeInterval) -> TimeInterval {
        guard seconds.isFinite else { return 1_500 }
        return min(10_800, max(60, seconds))
    }
}
