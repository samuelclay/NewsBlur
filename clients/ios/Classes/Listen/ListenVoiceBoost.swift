//
//  ListenVoiceBoost.swift
//  NewsBlur
//
//  Created by Claude on 2026-11-02.
//  Copyright © 2026 NewsBlur. All rights reserved.
//

import AVFoundation
import CoreAudio
import MediaToolbox

/// ListenVoiceBoost.swift makes Listen's voice louder than 100% when the Music / Voice balance (ListenMusicCard.swift)
/// leans toward the voice. AVPlayer's volume stops at 1, and NewsBlur can't turn another app's music down, so each
/// segment's audio passes through a processing tap that multiplies it by the boost and runs it through a lookahead
/// limiter (ListenVoiceLimiter), which keeps the louder voice from clipping.
enum ListenVoiceBoost {
    /// The boost the audio thread reads on every buffer. A single aligned Float, written on the main thread and
    /// read in the tap, so a buffer sees either the old or the new boost.
    private static let gainStorage: UnsafeMutablePointer<Float> = {
        let pointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        pointer.initialize(to: 1)
        return pointer
    }()

    static var gain: Float {
        get { gainStorage.pointee }
        set { gainStorage.pointee = max(1, newValue.isFinite ? newValue : 1) }
    }

    /// Gives a segment's player item the boosting tap while Listen plays over other audio, the only time the balance
    /// applies, and takes it off otherwise so the voice plays untouched. ListenPlayer.swift calls this for each new
    /// segment and for the queued ones when the setting changes. Segments are local files, so the track loads at once.
    static func update(_ item: AVPlayerItem) {
        guard ListenAudioMix.playsOverOtherAudio else {
            item.audioMix = nil
            return
        }
        guard item.audioMix == nil else { return }
        let asset = item.asset
        Task { @MainActor in
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first,
                  ListenAudioMix.playsOverOtherAudio, item.audioMix == nil, let tap = makeTap() else { return }
            let parameters = AVMutableAudioMixInputParameters(track: track)
            parameters.audioTapProcessor = tap
            let mix = AVMutableAudioMix()
            mix.inputParameters = [parameters]
            item.audioMix = mix
        }
    }

    // MARK: - Processing tap

    /// Per-tap state, owned by the tap from init to finalize: one limiter for each buffer the audio arrives in.
    private final class TapState {
        var isFloat = false
        var limiters: [ListenVoiceLimiter] = []
    }

    private static func makeTap() -> MTAudioProcessingTap? {
        let state = Unmanaged.passRetained(TapState()).toOpaque()
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: state,
            init: { _, clientInfo, tapStorageOut in
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                Unmanaged<TapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
            },
            prepare: { tap, _, format in
                let state = Unmanaged<TapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                let description = format.pointee
                state.isFloat = description.mFormatID == kAudioFormatLinearPCM
                    && description.mFormatFlags & kAudioFormatFlagIsFloat != 0
                    && description.mBitsPerChannel == 32
                // ListenVoiceBoost.swift allocates here, never on the audio thread in process. Non-interleaved audio
                // arrives one channel per buffer; interleaved audio in one buffer, where the channels share a limiter.
                let isInterleaved = description.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
                let channels = max(1, Int(description.mChannelsPerFrame))
                state.limiters = (0..<(isInterleaved ? 1 : channels)).map { _ in
                    ListenVoiceLimiter(sampleRate: description.mSampleRate)
                }
            },
            unprepare: nil,
            process: { tap, numberFrames, _, bufferList, numberFramesOut, flagsOut in
                let status = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferList, flagsOut, nil, numberFramesOut)
                guard status == noErr else { return }
                let state = Unmanaged<TapState>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
                guard state.isFloat, !state.limiters.isEmpty else { return }
                // ListenVoiceBoost.swift limits even at 100%, so the lookahead delay never jumps as the boost changes.
                let gain = ListenVoiceBoost.gain
                let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
                for (index, buffer) in buffers.enumerated() {
                    guard let data = buffer.mData else { continue }
                    let count = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                    let samples = UnsafeMutableBufferPointer(start: data.assumingMemoryBound(to: Float.self), count: count)
                    state.limiters[min(index, state.limiters.count - 1)].process(samples, gain: gain)
                }
            })
        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(kCFAllocatorDefault, &callbacks, kMTAudioProcessingTapCreationFlag_PostEffects, &tap)
        guard status == noErr, let tap else {
            // ListenVoiceBoost.swift: with no tap there's no finalize callback to free the state, so it's freed here.
            Unmanaged<TapState>.fromOpaque(state).release()
            NSLog("Listen couldn't create the voice boost tap: %d", status)
            return nil
        }
        return tap
    }
}

/// A lookahead peak limiter for the boosted voice (ListenVoiceBoost.swift). Each boosted sample is held back by the
/// lookahead while the limiter tracks the loudest sample still waiting to play, and the gain eases toward what that
/// sample needs, so a loud syllable is already turned down when it reaches the output instead of being clamped there.
/// The envelope releases slowly after the loudest sample has played, so the gain doesn't pump between syllables, and
/// a final clamp catches anything the easing missed, so no output sample exceeds the ceiling.
struct ListenVoiceLimiter {
    /// The loudest a sample may get after the boost, just under full scale (about -1 dBFS).
    static let ceiling: Float = 0.89
    static let lookahead: Double = 0.005
    static let releaseTime: Double = 0.12

    private var delay: [Float]
    private var position = 0
    /// The levels still waiting to play, kept as a queue of falling levels so its front is always the loudest
    /// (a sliding-window maximum). Fixed-size ring buffers, so the audio thread never allocates.
    private var peakLevels: [Float]
    private var peakTimes: [Int]
    private var peakHead = 0
    private var peakCount = 0
    private var time = 0
    private var envelope: Float = 0
    private var reduction: Float = 1
    /// Gets the gain all but 0.03% of the way to its target within one lookahead.
    private let smoothing: Float
    private let release: Float

    init(sampleRate: Double) {
        let rate = sampleRate > 0 ? sampleRate : 44100
        let length = max(1, Int(rate * Self.lookahead))
        delay = Array(repeating: 0, count: length)
        peakLevels = Array(repeating: 0, count: length + 1)
        peakTimes = Array(repeating: 0, count: length + 1)
        smoothing = Float(exp(-8 / Double(length)))
        release = Float(exp(-1 / (Self.releaseTime * rate)))
    }

    /// The samples the lookahead holds back, so output sample `index + latency` is input sample `index`.
    var latency: Int { delay.count }

    mutating func process(_ samples: UnsafeMutableBufferPointer<Float>, gain: Float) {
        let ceiling = Self.ceiling
        // ListenVoiceBoost.swift: the window is every sample in the delay plus the one arriving, since the sample
        // leaving the delay this step arrived `latency` steps ago.
        let window = peakLevels.count
        for index in samples.indices {
            let boosted = samples[index] * gain
            let level = abs(boosted)
            while peakCount > 0 {
                let back = (peakHead + peakCount - 1) % window
                guard peakLevels[back] <= level else { break }
                peakCount -= 1
            }
            if peakCount > 0, peakTimes[peakHead] <= time - window {
                peakHead = (peakHead + 1) % window
                peakCount -= 1
            }
            let slot = (peakHead + peakCount) % window
            peakLevels[slot] = level
            peakTimes[slot] = time
            peakCount += 1
            time += 1
            envelope = max(peakLevels[peakHead], envelope * release)
            let needed = envelope > ceiling ? ceiling / envelope : 1
            reduction = needed + (reduction - needed) * smoothing
            let delayed = delay[position]
            delay[position] = boosted
            position = position + 1 == delay.count ? 0 : position + 1
            samples[index] = min(ceiling, max(-ceiling, delayed * reduction))
        }
    }
}
