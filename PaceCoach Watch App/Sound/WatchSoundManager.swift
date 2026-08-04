import AVFoundation
import WatchKit

/// Lightweight sound manager for watchOS.
/// Prefers the same bundled whistle samples as iPhone, with synthesis as fallback.
class WatchSoundManager {
    static let shared = WatchSoundManager()

    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()
    private let volumeKey = "watch_sound_volume"
    private let sampleRate: Double = 44_100
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private let audioFormat: AVAudioFormat?
    private var volume: Float

    private let poolSize = 4
    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private var isPrepared = false
    private var isAudioAvailable = true

    // Drive/loudness constants (same as iPhone)
    private let globalLoudnessDrive: Float = 1.20
    private let whistleExtraDrive: Float = 2.10
    private let whistleSelectableDriveBoost: Float = 1.45
    private let whistleSegmentDriveBoost: Float = 1.35
    private let whistleSequenceDriveBoost: Float = 1.40

    private init() {
        volume = Self.loadStoredVolume()
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        if audioFormat == nil {
            isAudioAvailable = false
        }
    }

    // MARK: - Setup (lazy)

    private func ensurePrepared() {
        guard !isPrepared, isAudioAvailable, audioFormat != nil else { return }
        setupAudioSession()
        setupEngine()
        prebakeAllSounds()
        isPrepared = true
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {}
    }

    private func setupEngine() {
        guard let audioFormat else { return }
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: audioFormat)
        engine.mainMixerNode.outputVolume = 1.0
        mixer.outputVolume = volume
        do { try engine.start() } catch {}
        for _ in 0..<poolSize {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: audioFormat)
            playerPool.append(player)
        }
    }

    private func ensureEngineRunning() {
        guard !engine.isRunning else { return }
        do { try engine.start() } catch {}
    }

    // MARK: - Pre-bake

    private func prebakeAllSounds() {
        let fallbackCountdownLast = makeWhistle(
            baseFreq: 3050, dur: 1.20, atk: 0.002, rel: 0.24,
            fmDepth: 520, fmRate: 26)
        let fallbackWhistleStandard = makeWhistle(
            baseFreq: 3050, dur: 1.10, atk: 0.002, rel: 0.24,
            fmDepth: 520, fmRate: 26,
            driveMultiplier: whistleSelectableDriveBoost)
        let fallbackWhistleSegmentShort = makeWhistle(
            baseFreq: 3050, dur: 0.62, atk: 0.002, rel: 0.14,
            fmDepth: 500, fmRate: 27,
            driveMultiplier: whistleSegmentDriveBoost)
        let fallbackWhistleShort = makeWhistle(
            baseFreq: 3050, dur: 1.35, atk: 0.0025, rel: 0.28,
            fmDepth: 520, fmRate: 26,
            driveMultiplier: whistleSelectableDriveBoost)
        let fallbackWhistleDouble = makeWhistleSequence(
            blasts: 2, blastDur: 0.48, gap: 0.14,
            baseFreq: 3050, fmDepth: 500, fmRate: 27,
            driveMultiplier: whistleSequenceDriveBoost)
        let fallbackWhistleTriple = makeWhistleSequence(
            blasts: 3, blastDur: 0.33, gap: 0.11,
            baseFreq: 3050, fmDepth: 500, fmRate: 27,
            driveMultiplier: whistleSequenceDriveBoost)

        // Countdown
        cache["countdown_normal"] = makeBeep(freq: 880, dur: 0.15, atk: 0.003, rel: 0.06)
        cache["countdown_last"] = loadWhistleSample(
            candidates: ["countdown_last", "whistle_standard", "whistle_long_airy"],
            target: 1.0
        ) ?? fallbackCountdownLast

        // Pre-warning ticks
        cache["warn_3"] = makeBeep(freq: 660, dur: 0.12, atk: 0.003, rel: 0.05)
        cache["warn_2"] = makeBeep(freq: 880, dur: 0.12, atk: 0.003, rel: 0.05)
        cache["warn_1"] = makeBeep(freq: 1046.5, dur: 0.15, atk: 0.003, rel: 0.06)

        // Segment short whistle
        let standardWhistle = loadWhistleSample(
            candidates: ["whistle_standard", "whistle_long_airy"],
            target: 1.0,
            driveMultiplier: whistleSelectableDriveBoost
        ) ?? fallbackWhistleStandard

        cache["whistle_segment_short"] = loadWhistleSample(
            candidates: ["whistle_segment_short", "whistle_medium_bright", "whistle_short"],
            target: 0.98,
            driveMultiplier: whistleSegmentDriveBoost
        ) ?? fallbackWhistleSegmentShort

        // Selectable sound types
        cache[SoundType.whistleStandard.rawValue] = standardWhistle

        cache[SoundType.whistleShort.rawValue] = loadWhistleSample(
            candidates: ["whistle_short", "whistle_standard", "whistle_long_airy"],
            target: 0.98,
            driveMultiplier: whistleSelectableDriveBoost
        ) ?? fallbackWhistleShort

        cache[SoundType.whistleQixinlu.rawValue] = loadWhistleSample(
            candidates: ["whistle_qixinlu"],
            target: 1.0,
            driveMultiplier: whistleSelectableDriveBoost
        ) ?? standardWhistle

        cache[SoundType.whistleDouble.rawValue] = makeSampleSequence(
            sampleCandidates: ["whistle_segment_short", "whistle_short", "whistle_medium_bright"],
            blasts: 2,
            gap: 0.14,
            target: 0.98,
            driveMultiplier: whistleSequenceDriveBoost
        ) ?? fallbackWhistleDouble

        cache[SoundType.whistleTriple.rawValue] = makeSampleSequence(
            sampleCandidates: ["whistle_segment_short", "whistle_short", "whistle_medium_bright"],
            blasts: 3,
            gap: 0.11,
            target: 0.98,
            driveMultiplier: whistleSequenceDriveBoost
        ) ?? fallbackWhistleTriple

        cache[SoundType.airHorn.rawValue] = makeAirHorn()
        cache[SoundType.buzzer.rawValue] = makeBuzzer()
    }

    // MARK: - Public API

    func playCountdown(_ count: Int, whistleOnLast: Bool = false) {
        if whistleOnLast && count == 1 {
            scheduleBuffer("countdown_last")
        } else {
            scheduleBuffer("countdown_normal")
        }
    }

    func playPreWarning(secondsLeft: Int) {
        scheduleBuffer("warn_\(secondsLeft)")
    }

    func playSound(_ type: SoundType) {
        scheduleBuffer(type.rawValue)
    }

    func playSegmentShortWhistle() {
        scheduleBuffer("whistle_segment_short")
    }

    func playStandardWhistle() {
        scheduleBuffer(SoundType.whistleStandard.rawValue)
    }

    func setVolume(_ newVolume: Float) {
        let clamped = max(0, min(1, newVolume))
        volume = clamped
        UserDefaults.standard.set(clamped, forKey: volumeKey)
        if isPrepared {
            mixer.outputVolume = clamped
        }
    }

    // MARK: - Schedule

    private func scheduleBuffer(_ key: String) {
        guard isAudioAvailable else { return }
        ensurePrepared()
        guard !playerPool.isEmpty else { return }
        ensureEngineRunning()
        guard engine.isRunning else { return }
        guard let buffer = cache[key] ?? cache["countdown_normal"] else { return }
        let player = playerPool[nextPlayerIndex % poolSize]
        nextPlayerIndex += 1
        player.stop()
        player.scheduleBuffer(buffer)
        player.play()
    }

    // MARK: - Sample loading

    private func loadWhistleSample(candidates: [String], target: Float, driveMultiplier: Float = 1.0) -> AVAudioPCMBuffer? {
        for name in candidates {
            if let sample = loadWhistleSample(named: name, target: target, driveMultiplier: driveMultiplier) {
                return sample
            }
        }
        return nil
    }

    private func loadWhistleSample(named name: String, target: Float, driveMultiplier: Float = 1.0) -> AVAudioPCMBuffer? {
        guard let audioFormat, let url = resolveSampleURL(named: name) else { return nil }
        do {
            let file = try AVAudioFile(forReading: url)
            let sourceFormat = file.processingFormat
            let sourceCapacity = max(1, AVAudioFrameCount(file.length))
            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: sourceCapacity) else {
                return nil
            }
            try file.read(into: sourceBuffer)

            let outputBuffer: AVAudioPCMBuffer
            if sourceFormat.sampleRate == audioFormat.sampleRate && sourceFormat.channelCount == audioFormat.channelCount {
                outputBuffer = sourceBuffer
            } else {
                guard let converter = AVAudioConverter(from: sourceFormat, to: audioFormat) else { return nil }
                let ratio = audioFormat.sampleRate / max(1, sourceFormat.sampleRate)
                let outCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * ratio) + 256
                guard let converted = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: outCapacity) else {
                    return nil
                }
                var provided = false
                var convertError: NSError?
                _ = converter.convert(to: converted, error: &convertError) { _, outStatus in
                    if provided {
                        outStatus.pointee = .endOfStream
                        return nil
                    }
                    provided = true
                    outStatus.pointee = .haveData
                    return sourceBuffer
                }
                if convertError != nil {
                    return nil
                }
                outputBuffer = converted
            }

            guard let data = outputBuffer.floatChannelData?[0] else { return nil }
            normalizeToTarget(
                data: data,
                frames: Int(outputBuffer.frameLength),
                target: target,
                drive: globalLoudnessDrive * whistleExtraDrive * driveMultiplier
            )
            return outputBuffer
        } catch {
            return nil
        }
    }

    private func resolveSampleURL(named name: String) -> URL? {
        let exts = ["wav", "mp3", "m4a", "caf", "aiff"]
        let subdirs: [String?] = ["Sounds", "Resources/Sounds", nil]

        for ext in exts {
            for subdir in subdirs {
                if let subdir {
                    if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir) {
                        return url
                    }
                } else if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }

        for ext in exts {
            let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []
            if let matched = urls.first(where: {
                let base = $0.deletingPathExtension().lastPathComponent
                return base == name || base.hasPrefix(name + "_")
            }) {
                return matched
            }
        }

        return nil
    }

    private func makeSampleSequence(sampleCandidates: [String], blasts: Int, gap: Double, target: Float, driveMultiplier: Float = 1.0) -> AVAudioPCMBuffer? {
        guard blasts > 0,
              let audioFormat,
              let sample = loadWhistleSample(candidates: sampleCandidates, target: 0.98, driveMultiplier: driveMultiplier),
              let sampleData = sample.floatChannelData?[0] else { return nil }

        let sampleFrames = Int(sample.frameLength)
        let gapFrames = Int(sampleRate * gap)
        let totalFrames = blasts * sampleFrames + max(0, blasts - 1) * gapFrames
        let totalFrameCount = AVAudioFrameCount(totalFrames)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: totalFrameCount),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = totalFrameCount
        for i in 0..<totalFrames { data[i] = 0 }
        for b in 0..<blasts {
            let offset = b * (sampleFrames + gapFrames)
            for i in 0..<sampleFrames where (offset + i) < totalFrames {
                data[offset + i] = sampleData[i]
            }
        }
        normalizeToTarget(
            data: data,
            frames: totalFrames,
            target: target,
            drive: globalLoudnessDrive * whistleExtraDrive * driveMultiplier
        )
        return buf
    }

    // MARK: - Whistle Synthesis (ported from iPhone SoundManager)

    private func makeWhistle(baseFreq: Float, dur: Double,
                             atk: Double, rel: Double,
                             fmDepth: Float, fmRate: Float,
                             driveMultiplier: Float = 1.0) -> AVAudioPCMBuffer? {
        guard let audioFormat else { return nil }
        let frameCount = AVAudioFrameCount(sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frameCount
        fillWhistle(data: data, frames: Int(frameCount),
                    baseFreq: baseFreq, fmDepth: fmDepth, fmRate: fmRate,
                    atk: atk, rel: rel, driveMultiplier: driveMultiplier)
        return buf
    }

    private func fillWhistle(data: UnsafeMutablePointer<Float>, frames: Int,
                             baseFreq: Float, fmDepth: Float, fmRate: Float,
                             atk: Double, rel: Double,
                             driveMultiplier: Float = 1.0) {
        let sr = Float(sampleRate)
        let atkF = Int(sampleRate * atk)
        let relStart = frames - Int(sampleRate * rel)
        let chirpFrames = Int(sampleRate * 0.035)
        let fastAttackFrames = Int(sampleRate * 0.008)

        var phase1: Float = 0, h2Phase: Float = 0, h3Phase: Float = 0
        var h5Phase: Float = 0, subPhase: Float = 0
        var modulatorPhase: Float = 0, modulator2Phase: Float = 0, jitterPhase: Float = 0
        var noisePrev: Float = 0
        let noiseAlpha: Float = 2.0 * .pi * 7600.0 / (2.0 * .pi * 7600.0 + sr)
        var noiseHPPrev: Float = 0, noiseHPOut: Float = 0
        let hpAlpha: Float = 1.0 - (2.0 * .pi * 2400.0 / (2.0 * .pi * 2400.0 + sr))
        var shimmerPhase: Float = 0
        let shimmerRate: Float = 6.4, shimmerDepth: Float = 0.05

        for i in 0..<frames {
            let chirp = i < chirpFrames ? 140.0 * (1.0 - Float(i) / Float(max(1, chirpFrames))) : 0.0
            let fmRamp = i < atkF ? Float(i) / Float(max(1, atkF)) : 1.0

            modulatorPhase += 2.0 * .pi * fmRate / sr
            modulator2Phase += 2.0 * .pi * (fmRate * 0.47) / sr
            jitterPhase += 2.0 * .pi * 3.2 / sr

            let fm1 = sinf(modulatorPhase) * fmDepth * fmRamp
            let fm2 = sinf(modulator2Phase) * (fmDepth * 0.18) * fmRamp
            let jitter = (sinf(jitterPhase) + 0.5 * sinf(jitterPhase * 1.61)) * 18.0
            let instFreq = max(900.0, baseFreq + chirp + fm1 + fm2 + jitter)

            phase1 += 2.0 * .pi * instFreq / sr
            let fundamental = sinf(phase1) * 0.58

            subPhase += 2.0 * .pi * (instFreq * 0.5) / sr
            let sub = sinf(subPhase) * 0.24

            h2Phase += 2.0 * .pi * (instFreq * 2.0) / sr
            let h2 = sinf(h2Phase) * 0.34

            h3Phase += 2.0 * .pi * (instFreq * 3.0) / sr
            let h3 = sinf(h3Phase) * 0.20

            h5Phase += 2.0 * .pi * (instFreq * 5.0) / sr
            let h5 = sinf(h5Phase) * 0.10

            let whiteNoise = Float.random(in: -1.0...1.0)
            let noiseLPF = noisePrev + noiseAlpha * (whiteNoise - noisePrev)
            noisePrev = noiseLPF
            noiseHPOut = hpAlpha * (noiseHPOut + noiseLPF - noiseHPPrev)
            noiseHPPrev = noiseLPF
            var noise = noiseHPOut * (0.06 + 0.05 * fmRamp)
            if i < fastAttackFrames { noise *= 1.35 }

            shimmerPhase += 2.0 * .pi * shimmerRate / sr
            let shimmer = 1.0 + sinf(shimmerPhase) * shimmerDepth

            var s = (sub + fundamental + h2 + h3 + h5 + noise) * shimmer

            if i < atkF {
                let env = Float(i) / Float(max(1, atkF))
                s *= powf(env, 0.62)
                if i < fastAttackFrames { s *= 1.08 }
            } else if i >= relStart {
                let relF = frames - relStart
                let relEnv = 1.0 - Float(i - relStart) / Float(max(1, relF))
                s *= relEnv * relEnv
            }

            s = softClip(s)
            data[i] = s
        }
        normalizeToTarget(data: data, frames: frames, target: 0.98,
                          drive: globalLoudnessDrive * whistleExtraDrive * driveMultiplier)
    }

    // MARK: - Whistle Sequence

    private func makeWhistleSequence(blasts: Int, blastDur: Double, gap: Double,
                                     baseFreq: Float, fmDepth: Float, fmRate: Float,
                                     driveMultiplier: Float = 1.0) -> AVAudioPCMBuffer? {
        guard let audioFormat else { return nil }
        let totalDur = Double(blasts) * blastDur + Double(blasts - 1) * gap
        let totalFrames = AVAudioFrameCount(sampleRate * totalDur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: totalFrames),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = totalFrames
        for i in 0..<Int(totalFrames) { data[i] = 0 }

        let blastFrames = Int(sampleRate * blastDur)
        let atkSec = 0.002
        let relSec = min(0.08, blastDur * 0.2)

        for b in 0..<blasts {
            let offset = Int(sampleRate * (Double(b) * (blastDur + gap)))
            let tempBuf = UnsafeMutablePointer<Float>.allocate(capacity: blastFrames)
            fillWhistle(data: tempBuf, frames: blastFrames,
                        baseFreq: baseFreq, fmDepth: fmDepth, fmRate: fmRate,
                        atk: atkSec, rel: relSec, driveMultiplier: driveMultiplier)
            for i in 0..<blastFrames {
                let g = offset + i
                guard g < Int(totalFrames) else { break }
                data[g] = tempBuf[i]
            }
            tempBuf.deallocate()
        }
        normalizeToTarget(data: data, frames: Int(totalFrames), target: 0.98,
                          drive: globalLoudnessDrive * whistleExtraDrive * driveMultiplier)
        return buf
    }

    // MARK: - Air Horn

    private func makeAirHorn() -> AVAudioPCMBuffer? {
        guard let audioFormat else { return nil }
        let dur = 1.2
        let frameCount = AVAudioFrameCount(sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frameCount
        let sr = Float(sampleRate)
        let frames = Int(frameCount)
        let atkFrames = Int(sampleRate * 0.12)
        let relStart = frames - Int(sampleRate * 0.25)

        var phase1: Float = 0, phase2: Float = 0, phase3: Float = 0
        var phase4: Float = 0, phase5: Float = 0, wobblePhase: Float = 0

        for i in 0..<frames {
            let t = Float(i) / sr
            let sweepFrac = min(1.0, t / 0.15)
            let freq: Float = 270 + 40 * sweepFrac

            wobblePhase += 2 * .pi * 5.5 / sr
            let wobble: Float = 1.0 + sinf(wobblePhase) * 0.06

            phase1 += 2 * .pi * freq / sr
            phase2 += 2 * .pi * (freq * 2) / sr
            phase3 += 2 * .pi * (freq * 3) / sr
            phase4 += 2 * .pi * (freq * 4) / sr
            phase5 += 2 * .pi * (freq * 5) / sr

            var s = sinf(phase1) + sinf(phase2) * 0.75 + sinf(phase3) * 0.55
                  + sinf(phase4) * 0.30 + sinf(phase5) * 0.15
            s *= wobble

            if i < atkFrames {
                s *= Float(i) / Float(max(1, atkFrames))
            } else if i >= relStart {
                let relF = frames - relStart
                s *= 1 - Float(i - relStart) / Float(max(1, relF))
            }
            data[i] = softClip(s)
        }
        normalizeToTarget(data: data, frames: frames, target: 0.98, drive: globalLoudnessDrive)
        return buf
    }

    // MARK: - Buzzer

    private func makeBuzzer() -> AVAudioPCMBuffer? {
        guard let audioFormat else { return nil }
        let dur = 0.9
        let frameCount = AVAudioFrameCount(sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frameCount
        let sr = Float(sampleRate)
        let frames = Int(frameCount)
        let atkFrames = Int(sampleRate * 0.005)
        let relStart = frames - Int(sampleRate * 0.12)
        let freq: Float = 370

        var phase1: Float = 0, phase3: Float = 0, phase5: Float = 0
        var phase7: Float = 0, phase9: Float = 0, amPhase: Float = 0

        for i in 0..<frames {
            phase1 += 2 * .pi * freq / sr
            phase3 += 2 * .pi * (freq * 3) / sr
            phase5 += 2 * .pi * (freq * 5) / sr
            phase7 += 2 * .pi * (freq * 7) / sr
            phase9 += 2 * .pi * (freq * 9) / sr

            var s = sinf(phase1) + sinf(phase3) * 0.33 + sinf(phase5) * 0.20
                  + sinf(phase7) * 0.14 + sinf(phase9) * 0.11

            amPhase += 2 * .pi * 15 / sr
            s *= 1.0 + sinf(amPhase) * 0.25

            if i < atkFrames {
                s *= Float(i) / Float(max(1, atkFrames))
            } else if i >= relStart {
                let relF = frames - relStart
                s *= 1 - Float(i - relStart) / Float(max(1, relF))
            }
            data[i] = softClip(s)
        }
        normalizeToTarget(data: data, frames: frames, target: 0.98, drive: globalLoudnessDrive)
        return buf
    }

    // MARK: - Beep

    private func makeBeep(freq: Float, dur: Double, atk: Double, rel: Double) -> AVAudioPCMBuffer? {
        guard let audioFormat else { return nil }
        let frameCount = AVAudioFrameCount(sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frameCount
        let atkF = Int(sampleRate * atk)
        let relStart = Int(frameCount) - Int(sampleRate * rel)
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(sampleRate)
            let fundamental = sinf(2 * .pi * freq * t)
            let h3 = sinf(2 * .pi * freq * 3.0 * t) * 0.25
            let h5 = sinf(2 * .pi * freq * 5.0 * t) * 0.12
            var s = fundamental + h3 + h5
            if i < atkF { s *= Float(i) / Float(max(1, atkF)) }
            else if i >= relStart {
                let relF = Int(frameCount) - relStart
                s *= 1 - Float(i - relStart) / Float(max(1, relF))
            }
            data[i] = softClip(s)
        }
        normalizeToTarget(data: data, frames: Int(frameCount), target: 0.85, drive: globalLoudnessDrive)
        return buf
    }

    // MARK: - Helpers

    private func softClip(_ x: Float) -> Float {
        let driven = tanhf(x * 2.2)
        return driven / tanhf(2.2)
    }

    private func normalizeToTarget(data: UnsafeMutablePointer<Float>, frames: Int, target: Float, drive: Float = 1.0) {
        var peak: Float = 0
        for i in 0..<frames { peak = max(peak, abs(data[i])) }
        guard peak > 0 else { return }
        let scale = target / peak
        for i in 0..<frames { data[i] *= scale }
        guard drive > 1.001 else { return }
        for i in 0..<frames { data[i] = softClip(data[i] * drive) }
        var postPeak: Float = 0
        for i in 0..<frames { postPeak = max(postPeak, abs(data[i])) }
        guard postPeak > 0 else { return }
        let postScale = target / postPeak
        for i in 0..<frames { data[i] *= postScale }
    }

    private static func loadStoredVolume() -> Float {
        let raw = UserDefaults.standard.object(forKey: "watch_sound_volume") as? Float ?? 1.0
        return max(0, min(1, raw))
    }
}
