import AppKit
import Combine
import Foundation

enum SessionKind: String, CaseIterable {
    case focus = "Focus"
    case rest = "Rest"

    var defaultMinutes: Int { self == .focus ? 25 : 5 }
    var presets: [Int] { self == .focus ? [15, 25, 45, 60] : [5, 10, 15, 20] }
}

@MainActor
final class TimerModel: ObservableObject {
    @Published private(set) var clock = SessionClock()
    @Published private(set) var kind: SessionKind = .focus
    @Published var isEditingDuration = false
    @Published var soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
            if !soundEnabled { chime.stop() }
        }
    }
    @Published private(set) var now = Date()
    private let chime = CalmChime()
    private var ticker: AnyCancellable?
    private var wakeObserver: AnyCancellable?

    init() {
        ticker = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.update(at: date) }
        wakeObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update(at: Date()) }
    }

    var isRunning: Bool { clock.state == .running }
    var canConfigure: Bool { clock.state == .idle || clock.state == .completed }
    var durationMinutes: Int { Int(clock.duration / 60) }
    var isComplete: Bool { clock.state == .completed }
    var timeText: String {
        let total = Int(ceil(clock.remaining))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
    var endDate: Date { clock.deadline ?? now.addingTimeInterval(clock.remaining) }
    var statusText: String {
        switch clock.state {
        case .idle: return kind == .focus ? "A LITTLE SPACE TO FOCUS" : "A LITTLE ROOM TO BREATHE"
        case .running: return kind == .focus ? "ONE THING AT A TIME" : "LET YOUR MIND WANDER"
        case .paused: return "TAKE YOUR TIME"
        case .completed: return "A MOMENT WELL SPENT"
        }
    }
    var primaryTitle: String {
        switch clock.state {
        case .idle: return kind == .focus ? "Begin focus" : "Begin rest"
        case .running: return "Pause"
        case .paused: return "Continue"
        case .completed: return "Begin again"
        }
    }

    func toggle() {
        guard !isEditingDuration else { return }
        chime.stop()
        let date = Date()
        now = date
        if isRunning {
            if clock.tick(at: date) { completed() }
            else { clock.pause(at: date) }
        } else { clock.start(at: date) }
    }

    func reset() {
        guard !isEditingDuration else { return }
        chime.stop()
        clock.reset()
        now = Date()
    }

    func select(kind: SessionKind) {
        guard canConfigure, self.kind != kind else { return }
        chime.stop()
        self.kind = kind
        clock.setDuration(TimeInterval(kind.defaultMinutes * 60))
        now = Date()
    }

    func setMinutes(_ minutes: Int) {
        guard canConfigure else { return }
        chime.stop()
        clock.setDuration(TimeInterval(min(max(minutes, 1), 180) * 60))
        now = Date()
    }

    func previewSound() { chime.play() }

    private func update(at date: Date) {
        now = date
        if clock.tick(at: date) { completed() }
    }

    private func completed() {
        if soundEnabled { chime.play() }
        NSApplication.shared.requestUserAttention(.informationalRequest)
    }
}
