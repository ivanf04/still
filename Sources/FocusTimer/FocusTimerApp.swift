import SwiftUI

@main
struct FocusTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TimerModel()
    @AppStorage("darkAppearance") private var darkAppearance = false

    var body: some Scene {
        WindowGroup("Still", id: "main") {
            AppRootView(model: model, darkAppearance: $darkAppearance, appDelegate: appDelegate)
                .preferredColorScheme(darkAppearance ? .dark : .light)
                .frame(minWidth: 460, idealWidth: 520, maxWidth: .infinity,
                       minHeight: 780, idealHeight: 780, maxHeight: .infinity)
        }
        .defaultSize(width: 520, height: 780)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Timer") {
                Button(model.isRunning ? "Pause Timer" : "Start or Resume Timer") { model.toggle() }
                    .disabled(model.isEditingDuration)
                    .keyboardShortcut(.space, modifiers: [.command])
                Button("Reset Timer") { model.reset() }
                    .disabled(model.isEditingDuration)
                    .keyboardShortcut("r", modifiers: [.command])
                Divider()
                Toggle("Completion Sound", isOn: $model.soundEnabled)
                Button("Preview Chime") { model.previewSound() }
                Divider()
                Toggle("Dark Appearance", isOn: $darkAppearance)
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra(isInserted: .constant(model.isRunning || model.clock.state == .paused)) {
            TimerMenuBarContent(model: model)
        } label: {
            // Text keeps the countdown visible; image labels can become icon-only.
            Text(model.isRunning ? model.timeText : "⏸ \(model.timeText)")
            .monospacedDigit()
            .accessibilityLabel("Still \(model.kind.rawValue.lowercased()) timer, \(model.timeText) remaining\(model.isRunning ? "" : ", paused")")
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct TimerMenuBarContent: View {
    @ObservedObject var model: TimerModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("\(model.kind.rawValue) · \(model.isRunning ? "Ends at " + model.endDate.formatted(date: .omitted, time: .shortened) : "Paused")")
        Button(model.isRunning ? "Pause Timer" : "Resume Timer") { model.toggle() }
        Button("Reset Timer") { model.reset() }
        Divider()
        Button("Show Still") {
            // Reuse the existing window rather than opening a second timer window.
            if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                window.deminiaturize(nil)
                window.makeKeyAndOrderFront(nil)
            } else {
                openWindow(id: "main")
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var reopenWindow: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { reopenWindow?() }
        return true
    }
}

private struct AppRootView: View {
    @ObservedObject var model: TimerModel
    @Binding var darkAppearance: Bool
    let appDelegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ContentView(model: model, darkAppearance: $darkAppearance)
            .onAppear { appDelegate.reopenWindow = { openWindow(id: "main") } }
    }
}
