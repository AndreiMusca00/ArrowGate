import UIKit
import AVFoundation

final class AudioHapticsManager {
    private let store: ProgressStore
    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private var successPlayer: AVAudioPlayer?
    private var errorPlayer: AVAudioPlayer?
    private var audioPrepared = false
    init(store: ProgressStore) {
        self.store = store
        impact.prepare(); notification.prepare()
        if store.sound { prepareAudio() }
    }
    private func prepareAudio() {
        guard !audioPrepared else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        successPlayer = makePlayer(success: true); errorPlayer = makePlayer(success: false)
        successPlayer?.prepareToPlay(); errorPlayer?.prepareToPlay()
        audioPrepared = true
    }
    func selected() {
        if store.haptics { impact.impactOccurred(intensity: 0.35); impact.prepare() }
    }
    func feedback(success: Bool) {
        if store.haptics { notification.notificationOccurred(success ? .success : .error); notification.prepare() }
        guard store.sound else { return }
        prepareAudio()
        let player = success ? successPlayer : errorPlayer
        player?.currentTime = 0; player?.play()
    }
    private func makePlayer(success: Bool) -> AVAudioPlayer? {
        // Small synthesized tones, with no external asset or dependency.
        let rate = 22050, count = 2205
        var data = Data()
        func bytes<T: FixedWidthInteger>(_ value: T) { var value = value.littleEndian; withUnsafeBytes(of: &value) { data.append(contentsOf: $0) } }
        data.append(contentsOf: Array("RIFF".utf8)); bytes(UInt32(36 + count * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); bytes(UInt32(16)); bytes(UInt16(1)); bytes(UInt16(1))
        bytes(UInt32(rate)); bytes(UInt32(rate * 2)); bytes(UInt16(2)); bytes(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); bytes(UInt32(count * 2))
        for i in 0..<count {
            let envelope = sin(Double.pi * Double(i) / Double(count))
            let sample = sin(2 * Double.pi * (success ? 660 : 180) * Double(i) / Double(rate))
            bytes(Int16(sample * envelope * 4500))
        }
        return try? AVAudioPlayer(data: data)
    }
}
