import SwiftUI

// Explicitly use the property wrapper, including SDKs that also export a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

private struct Palette {
    let dark: Bool
    var background: Color { dark ? Color(hex: 0x17191F) : Color(hex: 0xF6F5F1) }
    var surface: Color { dark ? Color(hex: 0x22252E) : Color(hex: 0xECEBE7) }
    var ink: Color { dark ? Color(hex: 0xEEEDF6) : Color(hex: 0x303238) }
    var muted: Color { dark ? Color(hex: 0xA8AAB9) : Color(hex: 0x686B73) }
    var accent: Color { dark ? Color(hex: 0xC6BBED) : Color(hex: 0x746493) }
    var mint: Color { dark ? Color(hex: 0x8DAEA5) : Color(hex: 0xA4BEB0) }
    var button: Color { dark ? Color(hex: 0xC7BCEB) : Color(hex: 0x343A38) }
    var buttonText: Color { dark ? Color(hex: 0x22232B) : Color(hex: 0xFFFFFF) }
}

struct ContentView: View {
    @ObservedObject var model: TimerModel
    @Binding var darkAppearance: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var customMinutes = "25"
    @FocusState private var customFocused: Bool

    private var colors: Palette { Palette(dark: darkAppearance) }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 36)
            Spacer(minLength: 25)
            modePicker
            Spacer(minLength: 27)
            Text(model.statusText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(2.7)
                .foregroundStyle(colors.muted)
                .padding(.bottom, 24)

            timerDial
                .frame(width: 320, height: 320)

            Text(caption)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(colors.muted)
                .padding(.top, 24)

            Spacer(minLength: 30)
            durationPicker
            controls.padding(.top, 23)
            Spacer(minLength: 26)
            footer.padding(.bottom, 26)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: darkAppearance)
        .sheet(isPresented: $model.isEditingDuration) { customDurationSheet }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().stroke(colors.accent.opacity(0.25), lineWidth: 1.5).frame(width: 25, height: 25)
                    Circle().trim(from: 0.05, to: 0.73)
                        .stroke(colors.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 17, height: 17)
                    Circle().fill(colors.accent).frame(width: 4, height: 4)
                }
                Text("still").font(.system(size: 25, weight: .semibold, design: .serif)).tracking(-0.8)
            }
            .foregroundStyle(colors.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Still focus timer")
            Spacer()
            HStack(spacing: 2) {
                appearanceButton(dark: false, symbol: "sun.max")
                appearanceButton(dark: true, symbol: "moon")
            }
            .padding(4)
            .background(colors.surface, in: Capsule())
        }
    }

    private func appearanceButton(dark: Bool, symbol: String) -> some View {
        Button { darkAppearance = dark } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(darkAppearance == dark ? colors.ink : colors.muted)
                .frame(width: 30, height: 28)
                .background {
                    if darkAppearance == dark {
                        Capsule().fill(colors.background)
                            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(dark ? "Dark appearance" : "Light appearance")
        .accessibilityLabel(dark ? "Dark appearance" : "Light appearance")
        .accessibilityAddTraits(darkAppearance == dark ? [.isSelected] : [])
    }

    private var modePicker: some View {
        HStack(spacing: 3) {
            ForEach(SessionKind.allCases, id: \.self) { kind in
                Button { model.select(kind: kind) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: kind == .focus ? "circle.dotted.circle" : "leaf")
                            .font(.system(size: 12))
                        Text(kind.rawValue).font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(model.kind == kind ? colors.ink : colors.muted)
                    .frame(width: 94, height: 34)
                    .background {
                        if model.kind == kind {
                            Capsule().fill(colors.background)
                                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!model.canConfigure)
                .accessibilityAddTraits(model.kind == kind ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(colors.surface, in: Capsule())
        .help(model.canConfigure ? "Choose focus or rest" : "Reset the timer to change session type")
    }

    private var timerDial: some View {
        ZStack {
            ProgressOrb(progress: model.clock.progress, running: model.isRunning,
                        complete: model.isComplete, colors: colors, reduceMotion: reduceMotion)
            VStack(spacing: 14) {
                Text(model.isComplete ? "WELL DONE" : model.clock.state == .paused ? "PAUSED" : model.kind.rawValue.uppercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(3)
                    .foregroundStyle(colors.accent)
                Text(model.timeText)
                    .font(.system(size: 64, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .tracking(-2.5)
                    .foregroundStyle(colors.ink)
                    .contentTransition(.identity)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(accessibleTime)
                HStack(spacing: 5) {
                    Image(systemName: model.isComplete ? "checkmark" : model.clock.state == .paused ? "pause" : "arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                    if model.isComplete {
                        Text("Time for a breath")
                    } else if model.clock.state == .paused {
                        Text("End time on resume")
                    } else {
                        Text("Ends at \(model.endDate.formatted(date: .omitted, time: .shortened))")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(colors.muted)
            }
        }
    }

    private var accessibleTime: String {
        let seconds = Int(ceil(model.clock.remaining))
        return "\(seconds / 60) minutes, \(seconds % 60) seconds"
    }

    private var caption: String {
        if model.isComplete { return model.kind == .focus ? "You showed up. Let that be enough." : "A fresh start, whenever you’re ready." }
        if model.clock.state == .paused { return "A pause is part of the process." }
        return model.kind == .focus ? "Settle in. The rest can wait." : "Unclench your shoulders. Take a breath."
    }

    private var durationPicker: some View {
        HStack(spacing: 7) {
            ForEach(model.kind.presets, id: \.self) { minutes in
                Button { model.setMinutes(minutes) } label: {
                    Text("\(minutes)")
                        .font(.system(size: 12, weight: model.durationMinutes == minutes ? .semibold : .regular))
                        .frame(width: 44, height: 32)
                        .foregroundStyle(model.durationMinutes == minutes ? colors.accent : colors.muted)
                        .background {
                            if model.durationMinutes == minutes {
                                Capsule().fill(colors.accent.opacity(darkAppearance ? 0.15 : 0.09))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(minutes) minutes")
                .accessibilityAddTraits(model.durationMinutes == minutes ? [.isSelected] : [])
            }
            Rectangle().fill(colors.muted.opacity(0.2)).frame(width: 1, height: 13).padding(.horizontal, 3)
            Button {
                customMinutes = String(model.durationMinutes)
                model.isEditingDuration = true
            } label: {
                Text(model.kind.presets.contains(model.durationMinutes) ? "Custom" : "\(model.durationMinutes) min")
                    .font(.system(size: 12))
                    .foregroundStyle(model.kind.presets.contains(model.durationMinutes) ? colors.muted : colors.accent)
                    .frame(minWidth: 53, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Set custom duration")
        }
        .disabled(!model.canConfigure)
        .opacity(model.canConfigure ? 1 : 0.45)
        .help(model.canConfigure ? "Session length in minutes" : "Reset the timer to change its length")
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { model.toggle() } label: {
                HStack(spacing: 10) {
                    Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(model.primaryTitle).font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(colors.buttonText)
                .frame(width: 224, height: 48)
                .background(colors.button, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(SoftPressStyle())
            .disabled(model.isEditingDuration)
            .keyboardShortcut(.space, modifiers: [])
            .help("\(model.primaryTitle) (Space)")
            Button { model.reset() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(colors.muted)
                    .frame(width: 48, height: 48)
                    .background(Circle().strokeBorder(colors.muted.opacity(0.2), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(SoftPressStyle())
            .help("Reset timer (⌘R)")
            .accessibilityLabel("Reset timer")
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(model.isRunning ? colors.mint : colors.muted.opacity(0.45)).frame(width: 5, height: 5)
                Text(model.isRunning ? "In your own time" : "A quieter kind of productive")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.muted)
            }
            Spacer()
            Menu {
                Toggle("Play when timer ends", isOn: $model.soundEnabled)
                Button("Preview gentle chime") { model.previewSound() }
            } label: {
                Image(systemName: model.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.muted)
                    .frame(width: 30, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Completion sound: \(model.soundEnabled ? "on" : "off")")
            .accessibilityLabel("Completion sound options, \(model.soundEnabled ? "on" : "off")")
        }
    }

    private var customDurationSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Make time for yourself.").font(.system(size: 22, weight: .medium, design: .serif))
            Text("Choose a session from 1 to 180 minutes.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField("Minutes", text: $customMinutes)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 95)
                    .focused($customFocused)
                    .accessibilityLabel("Duration in minutes")
                    .onSubmit { applyCustomDuration() }
                Text("minutes").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { model.isEditingDuration = false }.keyboardShortcut(.cancelAction)
                Button("Set duration") { applyCustomDuration() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(validCustomMinutes == nil)
            }
        }
        .padding(28)
        .frame(width: 340)
        .onAppear { customFocused = true }
    }

    private var validCustomMinutes: Int? {
        guard let minutes = Int(customMinutes.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...180).contains(minutes) else { return nil }
        return minutes
    }

    private func applyCustomDuration() {
        guard let minutes = validCustomMinutes else { return }
        model.setMinutes(minutes)
        model.isEditingDuration = false
    }
}

private struct ProgressOrb: View {
    let progress: Double
    let running: Bool
    let complete: Bool
    let colors: Palette
    let reduceMotion: Bool
    @ViewState private var phase: Double = 0
    @ViewState private var lastFrame: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running || reduceMotion)) { timeline in
            ZStack {
                // A broad, low-contrast halo drifts slowly behind the crisp progress line.
                Circle()
                    .fill(RadialGradient(colors: [colors.accent.opacity(colors.dark ? 0.1 : 0.07), .clear],
                                         center: .center, startRadius: 90, endRadius: 164))
                    .frame(width: 328, height: 328)
                Circle()
                    .stroke(AngularGradient(colors: [colors.accent.opacity(0.12), colors.mint.opacity(0.22),
                                                     colors.accent.opacity(0.35), colors.accent.opacity(0.12)],
                                            center: .center, angle: .degrees(phase)), lineWidth: 14)
                    .blur(radius: 13)
                    .frame(width: 284, height: 284)
                Circle().stroke(colors.muted.opacity(colors.dark ? 0.08 : 0.06), lineWidth: 1)
                    .frame(width: 316, height: 316)
                Circle().stroke(colors.accent.opacity(colors.dark ? 0.17 : 0.13), lineWidth: 3)
                    .frame(width: 286, height: 286)
                Circle()
                    .trim(from: 0, to: max(0.001, 1 - progress))
                    .stroke(AngularGradient(colors: [colors.accent.opacity(0.5), colors.mint, colors.accent],
                                            center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 286, height: 286)
                    .opacity(complete ? 0.25 : 1)
                    .animation(reduceMotion ? nil : .linear(duration: 0.2), value: progress)
                Circle().stroke(colors.accent.opacity(0.055), lineWidth: 1)
                    .frame(width: 267, height: 267)
                if !complete {
                    Circle().fill(colors.accent.opacity(0.12)).frame(width: 19, height: 19)
                        .overlay(Circle().fill(colors.accent).frame(width: 7, height: 7))
                        .offset(y: -143)
                        .rotationEffect(.degrees(-360 * progress))
                        .animation(reduceMotion ? nil : .linear(duration: 0.2), value: progress)
                }
                ForEach(0..<4) { index in
                    Circle().fill(colors.muted.opacity(0.28)).frame(width: 2, height: 2)
                        .offset(y: -158).rotationEffect(.degrees(Double(index) * 90))
                }
            }
            .onChange(of: timeline.date) { _, newDate in
                if let lastFrame, running && !reduceMotion {
                    phase = (phase + min(newDate.timeIntervalSince(lastFrame), 0.1) * 4).truncatingRemainder(dividingBy: 360)
                }
                lastFrame = newDate
            }
        }
        .accessibilityHidden(true)
    }
}

private struct SoftPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1)
    }
}
