import AVFoundation
import XCTest

@testable import NewsBlur

/// ListenAudioMixTests.swift: the audio session and Music / Voice balance ListenAudioMix.swift picks for Listen's
/// voice, and the boost ListenVoiceBoost.swift applies past 100%.
final class Test_ListenAudioMix: XCTestCase {
    private var savedValues: [String: Any] = [:]
    private let keys = [ListenAudioMix.playOverOtherAudioKey, ListenAudioMix.lowersMusicKey, ListenAudioMix.voiceVolumeKey,
                        ListenAudioMix.musicSectionCollapsedKey]

    override func setUp() {
        super.setUp()
        for key in keys {
            savedValues[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            if let value = savedValues[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func test_listen_owns_the_lock_screen_unless_it_plays_over_other_audio() {
        XCTAssertFalse(ListenAudioMix.playsOverOtherAudio, "Playing over other audio is off by default")
        let alone = ListenAudioMix.sessionConfiguration(mixes: false, lowersMusic: true)
        XCTAssertEqual(alone.policy, .longFormAudio)
        XCTAssertEqual(alone.options, [])
    }

    func test_podcasts_keep_an_exclusive_session_after_narration_mixing_is_enabled() {
        // ListenAudioMixTests.swift checks the real podcast session entry point after the narration preference changes.
        UserDefaults.standard.set(true, forKey: ListenAudioMix.playOverOtherAudioKey)
        UserDefaults.standard.set(true, forKey: ListenAudioMix.lowersMusicKey)
        ListenMediaPlayer.Environment.app.activateAudioSession()
        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.routeSharingPolicy, .longFormAudio)
        XCTAssertFalse(session.categoryOptions.contains(.duckOthers))
        XCTAssertFalse(session.categoryOptions.contains(.mixWithOthers))
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    func test_playing_over_other_audio_lowers_it_under_the_voice_only_when_asked() {
        XCTAssertTrue(ListenAudioMix.lowersMusicWhileSpeaking, "Lowering the music is on by default")
        let lowering = ListenAudioMix.sessionConfiguration(mixes: true, lowersMusic: true)
        XCTAssertEqual(lowering.policy, .default)
        XCTAssertEqual(lowering.options, [.mixWithOthers, .duckOthers])
        let level = ListenAudioMix.sessionConfiguration(mixes: true, lowersMusic: false)
        XCTAssertEqual(level.options, [.mixWithOthers])
    }

    func test_the_balance_only_changes_the_voice_while_playing_over_other_audio() {
        ListenAudioMix.voiceVolume = 0.2
        XCTAssertEqual(ListenAudioMix.effectiveVoiceVolume, 1, "A hidden slider can't leave the voice quiet")
        ListenAudioMix.playsOverOtherAudio = true
        XCTAssertEqual(ListenAudioMix.effectiveVoiceVolume, ListenAudioMix.isAvailable ? 0.2 : 1, accuracy: 0.0001,
                       "ListenAudioMix.swift keeps the voice unmodified on Mac, where mixing controls are unavailable")
    }

    func test_the_music_section_starts_expanded_and_remembers_collapsing() {
        XCTAssertFalse(ListenAudioMix.isMusicSectionCollapsed)
        ListenAudioMix.isMusicSectionCollapsed = true
        XCTAssertTrue(ListenAudioMix.isMusicSectionCollapsed)
    }

    func test_voice_volume_reaches_minus_forty_and_plus_twenty_decibels_but_never_off() {
        XCTAssertEqual(ListenAudioMix.voiceVolume, 1)
        ListenAudioMix.voiceVolume = 0
        XCTAssertEqual(ListenAudioMix.voiceVolume, ListenAudioMix.minimumVoiceVolume)
        XCTAssertEqual(20 * log10(ListenAudioMix.minimumVoiceVolume), -40, accuracy: 0.0001)
        ListenAudioMix.voiceVolume = 500
        XCTAssertEqual(ListenAudioMix.voiceVolume, ListenAudioMix.maximumVoiceVolume)
        XCTAssertEqual(20 * log10(ListenAudioMix.maximumVoiceVolume), 20, accuracy: 0.0001)
    }

    func test_balance_middle_is_today_and_the_ends_reach_the_limits() {
        XCTAssertEqual(ListenAudioMix.voiceVolume(forBalance: 0), 1, accuracy: 0.0001)
        XCTAssertEqual(ListenAudioMix.voiceVolume(forBalance: 1), ListenAudioMix.maximumVoiceVolume, accuracy: 0.0001)
        XCTAssertEqual(ListenAudioMix.voiceVolume(forBalance: -1), ListenAudioMix.minimumVoiceVolume, accuracy: 0.0001)
        // ListenAudioMixTests.swift: halfway toward Voice is +10 dB, halfway toward Music is -20 dB.
        XCTAssertEqual(20 * log10(ListenAudioMix.voiceVolume(forBalance: 0.5)), 10, accuracy: 0.0001)
        XCTAssertEqual(20 * log10(ListenAudioMix.voiceVolume(forBalance: -0.5)), -20, accuracy: 0.0001)
    }

    func test_balance_round_trips_so_the_slider_reopens_where_it_was_left() {
        for balance in stride(from: -1.0, through: 1.0, by: 0.25) {
            let volume = ListenAudioMix.voiceVolume(forBalance: balance)
            XCTAssertEqual(ListenAudioMix.balance(forVoiceVolume: volume), balance, accuracy: 0.0001)
        }
    }
}

final class Test_ListenVoiceLimiter: XCTestCase {
    private let sampleRate = 44100.0

    /// Runs `input` through a fresh limiter in 512-sample buffers, like the tap does, and returns the output with the
    /// lookahead delay removed, so output[i] lines up with input[i].
    private func limited(_ input: [Float], gain: Float) -> [Float] {
        var limiter = ListenVoiceLimiter(sampleRate: sampleRate)
        var samples = input + Array(repeating: 0, count: limiter.latency)
        var offset = 0
        while offset < samples.count {
            let end = min(offset + 512, samples.count)
            samples[offset..<end].withUnsafeMutableBufferPointer { buffer in
                limiter.process(buffer, gain: gain)
            }
            offset = end
        }
        return Array(samples[limiter.latency...])
    }

    private func sine(amplitude: Float, count: Int = 44100) -> [Float] {
        (0..<count).map { amplitude * sin(Float($0) * 2 * .pi * 220 / 44100) }
    }

    func test_quiet_speech_gets_the_whole_boost() {
        let quiet = sine(amplitude: 0.05)
        let output = limited(quiet, gain: 10)
        for (input, sample) in zip(quiet, output) {
            XCTAssertEqual(sample, input * 10, accuracy: 0.0001)
        }
    }

    func test_loud_speech_at_full_boost_is_limited_instead_of_clipping() {
        let loud = sine(amplitude: 0.95)
        let output = limited(loud, gain: Float(ListenAudioMix.maximumVoiceVolume))
        XCTAssertLessThanOrEqual(output.map(abs).max() ?? 0, ListenVoiceLimiter.ceiling)
        // ListenAudioMixTests.swift: after the first syllable, the lookahead has turned the gain down before each peak
        // arrives, so the whole wave is scaled evenly. Clamping would flatten the peaks and shrink their ratio.
        let settled = (4410..<loud.count).filter { abs(loud[$0]) > 0.1 }
        let ratios = settled.map { output[$0] / loud[$0] }
        let largest = ratios.max() ?? 0
        let smallest = ratios.min() ?? 0
        XCTAssertGreaterThan(output[4410...].map(abs).max() ?? 0, 0.8, "Limited speech should still be loud")
        XCTAssertLessThan((largest - smallest) / largest, 0.02, "Peaks should be eased down, not flattened")
        for (input, sample) in zip(loud, output) where abs(input) > 0.01 {
            XCTAssertEqual(sample.sign, input.sign, "The limiter turns samples down, never flips them")
        }
    }

    func test_the_voice_at_100_percent_passes_through_unchanged() {
        let speech = sine(amplitude: 0.7)
        let output = limited(speech, gain: 1)
        for (input, sample) in zip(speech, output) {
            XCTAssertEqual(sample, input, accuracy: 0.0001)
        }
    }
}

final class Test_ListenVoiceBoostTap: XCTestCase {
    private var savedPlayOver: Any?

    override func setUp() {
        super.setUp()
        savedPlayOver = UserDefaults.standard.object(forKey: ListenAudioMix.playOverOtherAudioKey)
    }

    override func tearDown() {
        if let savedPlayOver {
            UserDefaults.standard.set(savedPlayOver, forKey: ListenAudioMix.playOverOtherAudioKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ListenAudioMix.playOverOtherAudioKey)
        }
        super.tearDown()
    }

    /// A tenth of a second of silence, standing in for a downloaded Listen segment.
    private func segmentFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("listen-boost-\(UUID().uuidString).caf")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410))
        buffer.frameLength = 4410
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    private func waitUntil(_ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        wait(for: [expectation], timeout: SimulatorTestTiming.realWorkTimeout)
    }

    func test_the_voice_plays_untouched_unless_listen_plays_over_other_audio() throws {
        let file = try segmentFile()
        defer { try? FileManager.default.removeItem(at: file) }

        ListenAudioMix.playsOverOtherAudio = false
        let untouched = AVPlayerItem(url: file)
        ListenVoiceBoost.update(untouched)
        // ListenAudioMixTests.swift: give an attach that shouldn't happen the same chance as one that should.
        let boosted = AVPlayerItem(url: file)
        ListenAudioMix.playsOverOtherAudio = true
        ListenVoiceBoost.update(boosted)
        if !ListenAudioMix.isAvailable {
            // ListenAudioMixTests.swift: Mac mixes apps itself, so the iOS boost must never attach there.
            XCTAssertNil(untouched.audioMix)
            XCTAssertNil(boosted.audioMix)
            return
        }
        waitUntil { boosted.audioMix != nil }
        XCTAssertNil(untouched.audioMix, "Without Play over other audio, no tap or limiter touches the voice")

        ListenAudioMix.playsOverOtherAudio = false
        ListenVoiceBoost.update(boosted)
        XCTAssertNil(boosted.audioMix, "Turning Play over off takes the tap off queued segments")
    }
}
