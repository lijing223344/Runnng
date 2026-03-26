import AVFoundation
import AudioToolbox
import Combine
import UIKit

// MARK: - SoundType
enum SoundType: String, CaseIterable, Identifiable {
    case whistleShort    // single long referee whistle
    case whistleDouble   // two short sharp whistle blasts
    case whistleTriple   // three short whistle blasts
    case airHorn         // stadium air horn
    case buzzer          // gym/stadium buzzer
    case whistleStandard // professional start whistle (same timbre as built-in 3-2-1 GO cue)
    case whistleQixinlu  // extracted whistle sample from qixinlu recording

    var id: String { rawValue }

    var displayNameKey: String {
        switch self {
        case .whistleShort:  return "sound_whistle_short"
        case .whistleDouble: return "sound_whistle_double"
        case .whistleTriple: return "sound_whistle_triple"
        case .airHorn:       return "sound_air_horn"
        case .buzzer:        return "sound_buzzer"
        case .whistleStandard: return "sound_whistle_standard"
        case .whistleQixinlu: return "sound_whistle_qixinlu"
        }
    }

    // Backward-compatible decoding: old values (beepShort, beepDouble, beepTriple) → whistleShort
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SoundType(rawValue: raw) ?? .whistleShort
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension SoundType: Codable {}

// MARK: - SoundManager
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    @Published var volume: Float = 1.0   // max by default
    @Published var vibrationEnabled: Bool = true

    private let engine      = AVAudioEngine()
    private let mixer       = AVAudioMixerNode()
    private let sampleRate: Double = 44_100
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private let audioFormat: AVAudioFormat
    private var audioSessionObservers: [NSObjectProtocol] = []
    private let isAudioDisabled: Bool
    private let isDebugLoggingEnabled: Bool
    private let shouldThrottleSimulatorAudio: Bool
    private let globalLoudnessDrive: Float = 1.20
    private let whistleExtraDrive: Float = 2.10
    private let whistleSelectableDriveBoost: Float = 1.45
    private let whistleSegmentDriveBoost: Float = 1.35
    private let whistleSequenceDriveBoost: Float = 1.40
    private let keepAliveSampleAmplitude: Float = 0.00008
    private var keepAlivePlayer: AVAudioPlayerNode?
    private var keepAliveBuffer: AVAudioPCMBuffer?
    private var runtimeSupportRefCount: Int = 0
    private var runtimeOriginalVolume: Float?
    private var lastScheduledAt: TimeInterval = 0
    private var lastScheduledKey: String = ""
    private var isPrepared = false

    private init() {
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            fatalError("SoundManager: failed to create audio format")
        }
        audioFormat = fmt
        isAudioDisabled = AppRuntimeConfiguration.shouldDisableAudio()
        isDebugLoggingEnabled = AppRuntimeConfiguration.shouldEnableAudioDebugLogs()
#if targetEnvironment(simulator)
        shouldThrottleSimulatorAudio = true
#else
        shouldThrottleSimulatorAudio = false
#endif
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default,
                                    options: [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay])
            try session.setActive(true)
        } catch {
            debugLog("SoundManager: failed to configure audio session: \(error)")
        }
    }

    private func setupEngine() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: audioFormat)
        engine.mainMixerNode.outputVolume = volume
        do {
            try engine.start()
        } catch {
            debugLog("SoundManager: failed to start audio engine: \(error)")
        }
        setupPlayerPool()
    }

    private func registerAudioSessionObservers() {
        let center = NotificationCenter.default
        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let rawType = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ?? 0
            let type = AVAudioSession.InterruptionType(rawValue: rawType) ?? .ended
            switch type {
            case .began:
                break
            case .ended:
                self.setupAudioSession()
                self.ensureEngineRunning()
                if self.runtimeSupportRefCount > 0 {
                    self.startKeepAlivePlayback()
                }
            @unknown default:
                self.setupAudioSession()
                self.ensureEngineRunning()
                if self.runtimeSupportRefCount > 0 {
                    self.startKeepAlivePlayback()
                }
            }
        }

        let routeChange = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.ensureEngineRunning()
            if self.runtimeSupportRefCount > 0 {
                self.startKeepAlivePlayback()
            }
        }

        let mediaReset = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.setupAudioSession()
            self.ensureEngineRunning()
            self.prebakeAllSounds()
            if self.runtimeSupportRefCount > 0 {
                self.startKeepAlivePlayback()
            }
        }

        let didEnterBackground = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.runtimeSupportRefCount > 0 else { return }
            self.setupAudioSession()
            self.ensureEngineRunning()
            self.startKeepAlivePlayback()
        }

        audioSessionObservers = [interruption, routeChange, mediaReset, didEnterBackground]
    }

    func setVolume(_ v: Float) {
        volume = max(0, min(1, v))
        if isPrepared {
            engine.mainMixerNode.outputVolume = volume
        }
    }

    func setVibrationEnabled(_ enabled: Bool) {
        vibrationEnabled = enabled
    }

    // MARK: - Training Runtime Support

    /// Keep training audible/reliable in real usage:
    /// 1) prevent screen auto-lock
    /// 2) keep background audio session alive while training is active
    func beginTrainingRuntimeSupport() {
        runtimeSupportRefCount += 1
        if runtimeSupportRefCount == 1 {
            runtimeOriginalVolume = volume
            if volume < 1.0 {
                setVolume(1.0)
            }
        }
        updateIdleTimerDisabled(true)
        guard !isAudioDisabled else { return }
        ensurePrepared()
        startKeepAlivePlayback()
    }

    func endTrainingRuntimeSupport() {
        runtimeSupportRefCount = max(0, runtimeSupportRefCount - 1)
        guard runtimeSupportRefCount == 0 else { return }
        updateIdleTimerDisabled(false)
        if let original = runtimeOriginalVolume {
            setVolume(original)
            runtimeOriginalVolume = nil
        }
        guard !isAudioDisabled else { return }
        stopKeepAlivePlayback()
    }

    // MARK: - Pre-bake

    private func prebakeAllSounds() {
        let fallbackCountdownLast = makeWhistle(
            baseFreq: 3050, dur: 1.20, atk: 0.002, rel: 0.24,
            fmDepth: 520, fmRate: 26)
        let fallbackWhistleStandard = makeWhistle(
            baseFreq: 3050, dur: 1.10, atk: 0.002, rel: 0.24,
            fmDepth: 520, fmRate: 26)
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

        // ── Countdown ticks ─────────────────────────────────────
        cache["countdown_normal"] = makeBeep(freq: 880, dur: 0.15, atk: 0.003, rel: 0.06)
        cache["countdown_last"] = loadWhistleSample(
            candidates: ["countdown_last", "whistle_standard", "whistle_long_airy"],
            target: 1.0
        )
            ?? fallbackCountdownLast
        let standardWhistle = loadWhistleSample(
            candidates: ["whistle_standard", "whistle_long_airy"],
            target: 1.0,
            driveMultiplier: whistleSelectableDriveBoost
        )
            ?? fallbackWhistleStandard
        cache["whistle_standard"] = standardWhistle
        cache[SoundType.whistleStandard.rawValue] = standardWhistle
        cache[SoundType.whistleQixinlu.rawValue] = loadWhistleSample(
            candidates: ["whistle_qixinlu"],
            target: 1.0,
            driveMultiplier: whistleSelectableDriveBoost
        )
            ?? standardWhistle
        cache["whistle_segment_short"] = loadWhistleSample(
            candidates: ["whistle_segment_short", "whistle_medium_bright", "whistle_short_soft"],
            target: 0.98,
            driveMultiplier: whistleSegmentDriveBoost
        )
            ?? fallbackWhistleSegmentShort

        // ── Pre-warning ticks (3-2-1 before segment end) ────────
        cache["warn_3"] = makeBeep(freq: 660,    dur: 0.12, atk: 0.003, rel: 0.05)
        cache["warn_2"] = makeBeep(freq: 880,    dur: 0.12, atk: 0.003, rel: 0.05)
        cache["warn_1"] = makeBeep(freq: 1046.5, dur: 0.15, atk: 0.003, rel: 0.06)

        // ── 1. Single referee whistle ────────────────────────────
        cache[SoundType.whistleShort.rawValue] = loadWhistleSample(
            candidates: ["whistle_short", "whistle_standard", "whistle_long_airy"],
            target: 0.98,
            driveMultiplier: whistleSelectableDriveBoost
        )
            ?? fallbackWhistleShort

        // ── 2. Double whistle blast ──────────────────────────────
        cache[SoundType.whistleDouble.rawValue] = makeSampleSequence(
            sampleCandidates: ["whistle_segment_short", "whistle_short", "whistle_medium_bright"],
            blasts: 2, gap: 0.14, target: 0.98,
            driveMultiplier: whistleSequenceDriveBoost)
            ?? fallbackWhistleDouble

        // ── 3. Triple whistle blast ──────────────────────────────
        cache[SoundType.whistleTriple.rawValue] = makeSampleSequence(
            sampleCandidates: ["whistle_segment_short", "whistle_short", "whistle_medium_bright"],
            blasts: 3, gap: 0.11, target: 0.98,
            driveMultiplier: whistleSequenceDriveBoost)
            ?? fallbackWhistleTriple

        // ── 4. Stadium air horn ──────────────────────────────────
        cache[SoundType.airHorn.rawValue] = makeAirHorn()

        // ── 5. Gym buzzer ────────────────────────────────────────
        cache[SoundType.buzzer.rawValue] = makeBuzzer()
    }

    // MARK: - Public API

    /// Play countdown tick.
    /// - whistleOnLast=false: all ticks use normal beep.
    /// - whistleOnLast=true: count==1 uses whistle as GO signal.
    func playCountdown(_ count: Int, whistleOnLast: Bool = false) {
        if whistleOnLast && count == 1 {
            scheduleBuffer("countdown_last")
        } else {
            scheduleBuffer("countdown_normal")
        }
        vibrate()
    }

    func playPreWarning(secondsLeft: Int) {
        scheduleBuffer("warn_\(secondsLeft)")
    }

    func playSound(_ type: SoundType) {
        scheduleBuffer(type.rawValue)
        vibrate()
    }

    func playStandardWhistle() {
        scheduleBuffer(SoundType.whistleStandard.rawValue)
        vibrate()
    }

    func playConfiguredRunStartSound() {
        let configured = StorageManager.shared.loadSettings().soundConfig.runStartSound
        playSound(configured)
    }

    func playSegmentShortWhistle() {
        scheduleBuffer("whistle_segment_short")
        vibrate()
    }

    // MARK: - Player Pool

    private let poolSize = 8
    private var playerPool: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0

    private func setupPlayerPool() {
        for _ in 0..<poolSize {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: audioFormat)
            playerPool.append(player)
        }
    }

    private func makeKeepAlivePlayerIfNeeded() {
        guard keepAlivePlayer == nil else { return }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: mixer, format: audioFormat)
        keepAlivePlayer = player
    }

    private func makeKeepAliveBufferIfNeeded() {
        guard keepAliveBuffer == nil else { return }
        let frameCount = AVAudioFrameCount(sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            data[i] = (i % 2 == 0) ? keepAliveSampleAmplitude : -keepAliveSampleAmplitude
        }
        keepAliveBuffer = buffer
    }

    private func startKeepAlivePlayback() {
        ensureEngineRunning()
        guard engine.isRunning else { return }
        makeKeepAlivePlayerIfNeeded()
        makeKeepAliveBufferIfNeeded()
        guard let player = keepAlivePlayer, let buffer = keepAliveBuffer else { return }
        guard !player.isPlaying else { return }
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }

    private func stopKeepAlivePlayback() {
        keepAlivePlayer?.stop()
    }

    // MARK: - Schedule

    private func scheduleBuffer(_ key: String) {
        guard !isAudioDisabled else { return }
        if shouldDropCue(for: key) { return }
        ensurePrepared()
        guard !playerPool.isEmpty else { return }
        ensureEngineRunning()
        guard engine.isRunning else {
            debugLog("SoundManager: engine not running, skip \(key)")
            return
        }
        if cache[key] == nil {
            prebakeAllSounds()
        }
        guard let buffer = cache[key] ?? cache["countdown_normal"] else {
            debugLog("SoundManager: buffer missing for key \(key)")
            return
        }
        let player = playerPool[nextPlayerIndex % poolSize]
        nextPlayerIndex += 1
        player.stop()
        player.scheduleBuffer(buffer)
        player.play()
        lastScheduledAt = ProcessInfo.processInfo.systemUptime
        lastScheduledKey = key
    }

    private func ensureEngineRunning() {
        guard !isAudioDisabled else { return }
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            debugLog("SoundManager: failed to restart engine: \(error)")
        }
    }

    private func ensurePrepared() {
        guard !isAudioDisabled else { return }
        guard !isPrepared else { return }
        setupAudioSession()
        setupEngine()
        registerAudioSessionObservers()
        prebakeAllSounds()
        isPrepared = true
    }

    private func updateIdleTimerDisabled(_ disabled: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = disabled
        }
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
        guard let url = resolveSampleURL(named: name) else {
            debugLog("SoundManager: sample not found for \(name)")
            return nil
        }
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
                if let convertError {
                    debugLog("SoundManager: convert sample failed for \(name): \(convertError)")
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
            debugLog("SoundManager: failed to load sample \(name) at \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func shouldDropCue(for key: String) -> Bool {
        guard shouldThrottleSimulatorAudio else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastScheduledAt
        if elapsed < 0.02 { return true }
        if key == lastScheduledKey && elapsed < 0.10 { return true }
        return false
    }

    private func debugLog(_ message: @autoclosure () -> String) {
        guard isDebugLoggingEnabled else { return }
        print(message())
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
                } else {
                    if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                        return url
                    }
                }
            }
        }

        // Fallback: recursively scan bundle resources for a matching base filename.
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
        guard blasts > 0, let sample = loadWhistleSample(candidates: sampleCandidates, target: 0.98, driveMultiplier: driveMultiplier),
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

    // MARK: - Whistle synthesis
    // Realistic whistle = FM-modulated fundamental + 2nd harmonic + shimmer

    private struct WhistleTone {
        let baseFreq: Float; let dur: Double; let atk: Double; let rel: Double
        let fmDepth: Float; let fmRate: Float; let offset: Double
    }

    private func makeWhistle(baseFreq: Float, dur: Double,
                             atk: Double, rel: Double,
                             fmDepth: Float, fmRate: Float,
                             driveMultiplier: Float = 1.0) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frameCount
        fillWhistle(data: data, frames: Int(frameCount),
                    baseFreq: baseFreq, fmDepth: fmDepth, fmRate: fmRate,
                    atk: atk, rel: rel,
                    driveMultiplier: driveMultiplier)
        return buf
    }

    /// Core whistle fill tuned for sports referee whistle:
    /// fast chirp attack + strong FM warble + harmonic body + turbulent jet noise.
    private func fillWhistle(data: UnsafeMutablePointer<Float>, frames: Int,
                             baseFreq: Float, fmDepth: Float, fmRate: Float,
                             atk: Double, rel: Double,
                             driveMultiplier: Float = 1.0) {
        let sr = Float(sampleRate)
        let atkF = Int(sampleRate * atk)
        let relStart = frames - Int(sampleRate * rel)
        let chirpFrames = Int(sampleRate * 0.035)      // startup chirp window
        let fastAttackFrames = Int(sampleRate * 0.008) // overshoot window

        // Phase accumulators
        var phase1: Float = 0
        var h2Phase: Float = 0
        var h3Phase: Float = 0
        var h5Phase: Float = 0
        var subPhase: Float = 0
        var modulatorPhase: Float = 0
        var modulator2Phase: Float = 0
        var jitterPhase: Float = 0

        // Band-pass turbulence noise state (LP + HP = band-pass ~2400-7600 Hz)
        var noisePrev: Float = 0
        let noiseAlpha: Float = 2.0 * .pi * 7600.0 / (2.0 * .pi * 7600.0 + sr)
        var noiseHPPrev: Float = 0
        var noiseHPOut: Float = 0
        let hpAlpha: Float = 1.0 - (2.0 * .pi * 2400.0 / (2.0 * .pi * 2400.0 + sr))

        // Small amplitude shimmer
        var shimmerPhase: Float = 0
        let shimmerRate: Float = 6.4
        let shimmerDepth: Float = 0.05

        for i in 0..<frames {
            // ── 1. Instant frequency: chirp + dual FM + micro jitter ──
            let chirp = i < chirpFrames ? 140.0 * (1.0 - Float(i) / Float(max(1, chirpFrames))) : 0.0
            let fmRamp = i < atkF ? Float(i) / Float(max(1, atkF)) : 1.0

            modulatorPhase += 2.0 * .pi * fmRate / sr
            modulator2Phase += 2.0 * .pi * (fmRate * 0.47) / sr
            jitterPhase += 2.0 * .pi * 3.2 / sr

            let fm1 = sinf(modulatorPhase) * fmDepth * fmRamp
            let fm2 = sinf(modulator2Phase) * (fmDepth * 0.18) * fmRamp
            let jitter = (sinf(jitterPhase) + 0.5 * sinf(jitterPhase * 1.61)) * 18.0
            let instFreq = max(900.0, baseFreq + chirp + fm1 + fm2 + jitter)

            // ── 2. Harmonic body ──
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

            // ── 3. Filtered turbulence noise (air jet) ──
            let whiteNoise = Float.random(in: -1.0...1.0)
            let noiseLPF = noisePrev + noiseAlpha * (whiteNoise - noisePrev)
            noisePrev = noiseLPF
            noiseHPOut = hpAlpha * (noiseHPOut + noiseLPF - noiseHPPrev)
            noiseHPPrev = noiseLPF
            var noise = noiseHPOut * (0.06 + 0.05 * fmRamp)
            if i < fastAttackFrames {
                noise *= 1.35
            }

            // ── 4. Shimmer ──
            shimmerPhase += 2.0 * .pi * shimmerRate / sr
            let shimmer = 1.0 + sinf(shimmerPhase) * shimmerDepth

            // ── 5. Mix ──
            var s = (sub + fundamental + h2 + h3 + h5 + noise) * shimmer

            // ── 6. Envelope ──
            if i < atkF {
                let env = Float(i) / Float(max(1, atkF))
                s *= powf(env, 0.62)
                if i < fastAttackFrames {
                    s *= 1.08
                }
            } else if i >= relStart {
                let relF = frames - relStart
                let relEnv = 1.0 - Float(i - relStart) / Float(max(1, relF))
                s *= relEnv * relEnv
            }

            // ── 7. Saturation ──
            s = softClip(s)
            data[i] = s
        }
        normalizeToTarget(
            data: data,
            frames: frames,
            target: 0.98,
            drive: globalLoudnessDrive * whistleExtraDrive * driveMultiplier
        )
    }

    // MARK: - Whistle sequence synthesis

    /// Multiple short whistle blasts with gaps
    private func makeWhistleSequence(blasts: Int, blastDur: Double, gap: Double,
                                     baseFreq: Float, fmDepth: Float, fmRate: Float,
                                     driveMultiplier: Float = 1.0) -> AVAudioPCMBuffer? {
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
                        atk: atkSec, rel: relSec,
                        driveMultiplier: driveMultiplier)
            for i in 0..<blastFrames {
                let g = offset + i
                guard g < Int(totalFrames) else { break }
                data[g] = tempBuf[i]
            }
            tempBuf.deallocate()
        }
        normalizeToTarget(
            data: data,
            frames: Int(totalFrames),
            target: 0.98,
            drive: globalLoudnessDrive * whistleExtraDrive * driveMultiplier
        )
        return buf
    }

    // MARK: - Air horn synthesis

    /// Stadium air horn: low frequency with rich harmonics, slight upward sweep, wobble
    private func makeAirHorn() -> AVAudioPCMBuffer? {
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
            // Frequency sweep: 270 → 310 Hz over attack, then hold
            let sweepFrac = min(1.0, t / 0.15)
            let freq: Float = 270 + 40 * sweepFrac

            // Wobble for realism
            wobblePhase += 2 * .pi * 5.5 / sr
            let wobble: Float = 1.0 + sinf(wobblePhase) * 0.06

            phase1 += 2 * .pi * freq / sr
            phase2 += 2 * .pi * (freq * 2) / sr
            phase3 += 2 * .pi * (freq * 3) / sr
            phase4 += 2 * .pi * (freq * 4) / sr
            phase5 += 2 * .pi * (freq * 5) / sr

            var s = sinf(phase1)
                  + sinf(phase2) * 0.75
                  + sinf(phase3) * 0.55
                  + sinf(phase4) * 0.30
                  + sinf(phase5) * 0.15
            s *= wobble

            // Envelope
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

    // MARK: - Buzzer synthesis

    /// Gym/stadium buzzer: harsh square-wave-like tone with amplitude modulation
    private func makeBuzzer() -> AVAudioPCMBuffer? {
        let dur = 0.9
        let frameCount = AVAudioFrameCount(sampleRate * dur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frameCount
        let sr = Float(sampleRate)
        let frames = Int(frameCount)
        let atkFrames = Int(sampleRate * 0.005)
        let relStart = frames - Int(sampleRate * 0.12)

        var phase1: Float = 0, phase3: Float = 0, phase5: Float = 0
        var phase7: Float = 0, phase9: Float = 0, amPhase: Float = 0
        let freq: Float = 370

        for i in 0..<frames {
            phase1 += 2 * .pi * freq / sr
            phase3 += 2 * .pi * (freq * 3) / sr
            phase5 += 2 * .pi * (freq * 5) / sr
            phase7 += 2 * .pi * (freq * 7) / sr
            phase9 += 2 * .pi * (freq * 9) / sr

            // Odd harmonics → square-wave-like harsh timbre
            var s = sinf(phase1)
                  + sinf(phase3) * 0.33
                  + sinf(phase5) * 0.20
                  + sinf(phase7) * 0.14
                  + sinf(phase9) * 0.11

            // Amplitude modulation for buzzing character
            amPhase += 2 * .pi * 15 / sr
            s *= 1.0 + sinf(amPhase) * 0.25

            // Envelope
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

    // MARK: - Beep synthesis (internal, for countdown ticks only)

    private struct BeepTone {
        let freq: Float; let dur: Double; let atk: Double; let rel: Double; let offset: Double
    }

    private func makeBeep(freq: Float, dur: Double, atk: Double, rel: Double) -> AVAudioPCMBuffer? {
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

    private func makeBeepSequence(_ tones: [BeepTone], totalDur: Double) -> AVAudioPCMBuffer? {
        let totalFrames = AVAudioFrameCount(sampleRate * totalDur)
        guard let buf = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: totalFrames),
              let data = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = totalFrames
        for i in 0..<Int(totalFrames) { data[i] = 0 }
        for tone in tones {
            let startFrame = Int(sampleRate * tone.offset)
            let toneFrames = Int(sampleRate * tone.dur)
            let atkF = Int(sampleRate * tone.atk)
            let relStart = toneFrames - Int(sampleRate * tone.rel)
            for i in 0..<toneFrames {
                let g = startFrame + i
                guard g < Int(totalFrames) else { break }
                let t = Float(i) / Float(sampleRate)
                let fundamental = sinf(2 * .pi * tone.freq * t)
                let h3 = sinf(2 * .pi * tone.freq * 3.0 * t) * 0.25
                let h5 = sinf(2 * .pi * tone.freq * 5.0 * t) * 0.12
                var s = fundamental + h3 + h5
                if i < atkF { s *= Float(i) / Float(max(1, atkF)) }
                else if i >= relStart {
                    let relF = toneFrames - relStart
                    s *= 1 - Float(i - relStart) / Float(max(1, relF))
                }
                data[g] += softClip(s)
            }
        }
        normalizeToTarget(data: data, frames: Int(totalFrames), target: 0.85, drive: globalLoudnessDrive)
        return buf
    }

    // MARK: - Helpers

    /// Soft clipping via tanh — adds harmonic saturation, increases perceived loudness
    /// Two-stage: gentle drive + hard limit for realistic high-pressure distortion
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
        for i in 0..<frames {
            data[i] = softClip(data[i] * drive)
        }
        var postPeak: Float = 0
        for i in 0..<frames { postPeak = max(postPeak, abs(data[i])) }
        guard postPeak > 0 else { return }
        let postScale = target / postPeak
        for i in 0..<frames { data[i] *= postScale }
    }

    private func vibrate() {
        guard !isAudioDisabled else { return }
        guard vibrationEnabled else { return }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}
