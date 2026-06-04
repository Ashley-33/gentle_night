import AVFoundation

/// Gentle synthesized chimes (no audio files needed).
final class SoundPlayer {
    static let shared = SoundPlayer()
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private var ready = false

    private func ensure() {
        guard !ready else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
        player.play()
        ready = true
    }

    /// soft decaying sine blip
    func blip(_ freq: Double, dur: Double = 0.22, vol: Float = 0.16, decay: Double = 8) {
        ensure()
        let frames = AVAudioFrameCount(format.sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buf.frameLength = frames
        let ch = buf.floatChannelData![0]
        let sr = format.sampleRate
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            ch[i] = Float(sin(2 * Double.pi * freq * t)) * Float(exp(-t * decay)) * vol
        }
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
    }

    func drop(_ index: Int) { blip(523 * pow(2, Double(index) / 12), dur: 0.22, vol: 0.16) }
    func seal() { blip(168, dur: 0.18, vol: 0.2, decay: 12) }
    func chime() { blip(880, dur: 0.5, vol: 0.12, decay: 4); blip(1320, dur: 0.55, vol: 0.08, decay: 4) }
}
