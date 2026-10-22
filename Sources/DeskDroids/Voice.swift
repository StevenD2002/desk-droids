import AVFoundation

/// One synthesized sweep. Frequencies glide exponentially from `from` to `to`, which is what
/// makes it sound like a droid rather than a microwave.
struct Tone {
    enum Wave { case sine, droid, square }

    var from: Double
    var to: Double
    var duration: Double
    var wave: Wave = .droid
    var volume: Double = 1
    /// Warble: `vibratoDepth` is a fraction of the frequency.
    var vibratoRate: Double = 0
    var vibratoDepth: Double = 0
    var gapAfter: Double = 0.02
}

/// The droid's vocabulary. Every call to `tones()` is a little different.
enum Phrase: String, CaseIterable {
    case boot, acknowledge, chatter, alert, happy, confused, sleepy

    /// Phrases that cut off whatever is playing instead of queueing behind it.
    var interrupts: Bool { self == .alert || self == .happy }

    func tones() -> [Tone] {
        func r(_ range: ClosedRange<Double>) -> Double { .random(in: range) }

        switch self {
        case .boot:
            return [
                Tone(from: 300, to: 1800, duration: 0.22, wave: .sine, gapAfter: 0.04),
                Tone(from: 1500, to: 1500, duration: 0.05),
                Tone(from: 2000, to: 2100, duration: 0.08),
            ]
        case .acknowledge:
            let base = r(1100...1700)
            return (0..<Int.random(in: 2...3)).map { i in
                let start = base * (1 + 0.25 * Double(i))
                return Tone(from: start, to: start * r(1.4...1.7), duration: r(0.05...0.08), gapAfter: 0.03)
            }
        case .chatter:
            return (0..<Int.random(in: 1...2)).map { _ in
                let pitch = r(1400...2600)
                return Tone(from: pitch, to: pitch * r(0.8...1.3), duration: r(0.025...0.045),
                            volume: 0.3, gapAfter: 0.03)
            }
        case .alert:
            let beep = Tone(from: 2200, to: 2200, duration: 0.07, wave: .square, volume: 0.6, gapAfter: 0.05)
            return [beep, beep, beep, Tone(from: 1200, to: 2600, duration: 0.16, gapAfter: 0)]
        case .happy:
            let shift = pow(2, Double(Int.random(in: -2...2)) / 12)
            let arpeggio = [1046.5, 1318.5, 1568.0].map {
                Tone(from: $0 * shift, to: $0 * shift * 1.03, duration: 0.065, gapAfter: 0.01)
            }
            let top = 2093.0 * shift
            return arpeggio + [Tone(from: top, to: top * 1.05, duration: 0.24, vibratoRate: 28, vibratoDepth: 0.06)]
        case .confused:
            return [
                Tone(from: 900, to: 1500, duration: 0.15, vibratoRate: 9, vibratoDepth: 0.05, gapAfter: 0),
                Tone(from: 1500, to: 700, duration: 0.25, vibratoRate: 9, vibratoDepth: 0.06),
            ]
        case .sleepy:
            return [Tone(from: 800, to: 350, duration: 0.7, wave: .sine, volume: 0.6, vibratoRate: 5, vibratoDepth: 0.03)]
        }
    }

    /// What the droid says when a session moves between states. `from` is nil for a brand-new session.
    static func forTransition(from: DroidState?, to: DroidState) -> Phrase? {
        guard let from else { return .boot }
        switch to {
        case .needsYou where from != .needsYou: return .alert
        case .done where from != .done: return .happy
        case .compacting where from != .compacting: return .confused
        case _ where to.isBusy && !from.isBusy: return .acknowledge
        case _ where to.isBusy: return .chatter
        default: return nil
        }
    }

    /// Each state's signature sound, for the fashion show.
    static func signature(for state: DroidState) -> Phrase {
        switch state {
        case .idle: return .boot
        case .thinking: return .acknowledge
        case .reading, .writing, .running, .delegating, .tinkering: return .chatter
        case .compacting: return .confused
        case .needsYou: return .alert
        case .done: return .happy
        case .sleeping: return .sleepy
        }
    }
}

/// Renders phrases to audio buffers and plays them. Main thread only.
final class Voice {
    enum Mode: String, CaseIterable {
        case all, importantOnly, muted

        var label: String {
            switch self {
            case .all: return "All beeps"
            case .importantOnly: return "Important only"
            case .muted: return "Muted"
            }
        }
    }

    private static let masterVolume = 0.3
    private static let chatterCooldown: TimeInterval = 2
    private static let idleShutdown: TimeInterval = 10
    private static let modeKey = "soundMode"

    var mode: Mode {
        get { Mode(rawValue: UserDefaults.standard.string(forKey: Self.modeKey) ?? "") ?? .all }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: Self.modeKey) }
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var lastChatter = Date.distantPast
    private var shutdown: DispatchWorkItem?

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    /// `force` plays chatter even in important-only mode (used by the fashion show). Muted always wins.
    func say(_ phrase: Phrase, force: Bool = false) {
        guard mode != .muted else { return }
        if phrase == .chatter && !force {
            guard mode == .all, Date().timeIntervalSince(lastChatter) > Self.chatterCooldown else { return }
            lastChatter = Date()
        }
        guard startEngine() else { return }

        player.scheduleBuffer(render(phrase.tones()), at: nil, options: phrase.interrupts ? .interrupts : [])
        if !player.isPlaying { player.play() }
        scheduleShutdown()
    }

    /// The engine starts on demand. It also stops itself when the output device changes
    /// (headphones, AirPods), so this restarts it too.
    private func startEngine() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            NSLog("desk-droids: couldn't start audio: \(error)")
            return false
        }
    }

    /// Don't hold the audio device open while the droid is quiet.
    private func scheduleShutdown() {
        shutdown?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.player.stop()
            self?.engine.stop()
        }
        shutdown = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleShutdown, execute: work)
    }

    private func render(_ tones: [Tone]) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let seconds = tones.reduce(0) { $0 + $1.duration + $1.gapAfter }
        let capacity = AVAudioFrameCount(seconds * sampleRate) + 1
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
        buffer.frameLength = capacity
        let samples = buffer.floatChannelData![0]
        samples.update(repeating: 0, count: Int(capacity))

        var index = 0
        var phase = 0.0
        for tone in tones {
            let count = Int(tone.duration * sampleRate)
            for n in 0..<count where index < Int(capacity) {
                let t = Double(n) / sampleRate
                var frequency = tone.from * pow(tone.to / tone.from, t / tone.duration)
                if tone.vibratoDepth > 0 {
                    frequency *= 1 + tone.vibratoDepth * sin(2 * .pi * tone.vibratoRate * t)
                }
                phase = (phase + 2 * .pi * frequency / sampleRate).truncatingRemainder(dividingBy: 2 * .pi)

                let wave: Double
                switch tone.wave {
                case .sine: wave = sin(phase)
                case .droid: wave = 0.8 * sin(phase) + 0.2 * sin(2 * phase)
                case .square: wave = 0.7 * (sin(phase) + sin(3 * phase) / 3 + sin(5 * phase) / 5)
                }
                // Short fades on both ends so tones don't click.
                let envelope = min(1, t / 0.004) * min(1, (tone.duration - t) / 0.012)
                samples[index] = Float(wave * envelope * tone.volume * Self.masterVolume)
                index += 1
            }
            index += Int(tone.gapAfter * sampleRate)
        }
        return buffer
    }
}
