import AVFoundation
import Foundation

/// A short, locally synthesized completion sound with a soft attack and a fading tail.
@MainActor
final class CalmChime {
    private var player: AVAudioPlayer?

    var isAvailable: Bool { player != nil }

    init() {
        player = try? AVAudioPlayer(data: Self.makeWaveData())
        player?.volume = 0.7
        player?.prepareToPlay()
    }

    /// Restarting the sound also makes previewing it safe while it is already playing.
    func play() {
        guard let player else { return }
        player.stop()
        player.currentTime = 0
        player.prepareToPlay()
        player.play()
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
    }

    private static func makeWaveData() -> Data {
        let sampleRate = 44_100
        let duration = 5.5
        let sampleCount = Int(Double(sampleRate) * duration)
        let bytesPerSample = 2
        let payloadSize = UInt32(sampleCount * bytesPerSample)

        var data = Data(capacity: 44 + Int(payloadSize))
        data.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(payloadSize + 36, to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        appendLittleEndian(UInt32(16), to: &data) // PCM format chunk size.
        appendLittleEndian(UInt16(1), to: &data) // Linear PCM.
        appendLittleEndian(UInt16(1), to: &data) // Mono.
        appendLittleEndian(UInt32(sampleRate), to: &data)
        appendLittleEndian(UInt32(sampleRate * bytesPerSample), to: &data)
        appendLittleEndian(UInt16(bytesPerSample), to: &data)
        appendLittleEndian(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        appendLittleEndian(payloadSize, to: &data)

        // A gently ascending A-major chord, voiced as warm sine bells.
        let notes: [(frequency: Double, onset: Double, gain: Double)] = [
            (440.0, 0.0, 0.19),
            (554.365, 0.72, 0.16),
            (659.255, 1.44, 0.14),
        ]

        for frame in 0..<sampleCount {
            let time = Double(frame) / Double(sampleRate)
            var sample = 0.0

            for note in notes {
                let age = time - note.onset
                guard age >= 0 else { continue }

                // A 45 ms eased attack avoids the sharp click of a struck bell.
                let attackProgress = min(age / 0.045, 1)
                let attack = 0.5 - 0.5 * cos(.pi * attackProgress)
                let envelope = attack * exp(-age / 1.18)
                let phase = 2 * Double.pi * note.frequency * age
                let fundamental = sin(phase)
                let warmOvertone = 0.12 * sin(phase * 2) * exp(-age / 0.7)
                let airyOvertone = 0.035 * sin(phase * 3) * exp(-age / 0.35)
                sample += note.gain * envelope * (fundamental + warmOvertone + airyOvertone)
            }

            // Explicitly fade to silence so stopping at the end produces no pop.
            let fadeProgress = min(max((duration - time) / 0.7, 0), 1)
            let fade = 0.5 - 0.5 * cos(.pi * fadeProgress)
            let clamped = min(max(sample * fade, -1), 1)
            appendLittleEndian(Int16(clamped * Double(Int16.max)), to: &data)
        }

        return data
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}
