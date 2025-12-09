//
//  VoiceRecorder.swift
//  NewsBlur
//
//  Created by Claude on 2024-12-06.
//  Copyright © 2024 NewsBlur. All rights reserved.
//

import Foundation
import AVFoundation
import Speech

class VoiceRecorder: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var error: String?

    // MARK: - Callbacks

    var onTranscriptionComplete: ((String) -> Void)?
    var onTranscriptionError: ((String) -> Void)?
    var onRecordingStateChange: ((Bool) -> Void)?

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var hasCompletedTranscription = false

    // MARK: - Permission Handling

    func requestPermissions() async -> Bool {
        // Request microphone permission
        let audioStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard audioStatus else {
            await MainActor.run {
                self.error = "Microphone permission denied"
                self.onTranscriptionError?("Microphone permission denied")
            }
            return false
        }

        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        if !speechStatus {
            await MainActor.run {
                self.error = "Speech recognition permission denied"
                self.onTranscriptionError?("Speech recognition permission denied")
            }
            return false
        }

        return true
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }

        // Reset state
        error = nil
        transcribedText = ""
        hasCompletedTranscription = false

        // Try live transcription first, fall back to file-based
        if speechRecognizer?.isAvailable == true {
            startLiveTranscription()
        } else {
            startFileRecording()
        }
    }

    func stopRecording() {
        if recognitionTask != nil {
            stopLiveTranscription()
        } else if audioRecorder != nil {
            stopFileRecording()
        }
    }

    // MARK: - Live Transcription (Real-time)

    private func startLiveTranscription() {
        audioEngine = AVAudioEngine()

        guard let audioEngine = audioEngine else {
            handleError("Failed to create audio engine")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            handleError("Failed to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            handleError("Failed to configure audio session: \(error.localizedDescription)")
            return
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if result.isFinal {
                    self.finishLiveTranscription()
                }
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.handleError("Recognition error: \(error.localizedDescription)")
                }
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()

            DispatchQueue.main.async {
                self.isRecording = true
                self.onRecordingStateChange?(true)
            }
        } catch {
            handleError("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func stopLiveTranscription() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()

        DispatchQueue.main.async {
            self.isRecording = false
            self.isTranscribing = true
            self.onRecordingStateChange?(false)
        }

        // Wait a moment for final results
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.finishLiveTranscription()
        }
    }

    private func finishLiveTranscription() {
        guard !hasCompletedTranscription else { return }
        hasCompletedTranscription = true

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil

        DispatchQueue.main.async {
            self.isTranscribing = false
            self.onTranscriptionComplete?(self.transcribedText)
        }
    }

    // MARK: - File-based Recording (Fallback)

    private func startFileRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("voice_recording.m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true)

            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.record()

            DispatchQueue.main.async {
                self.isRecording = true
                self.onRecordingStateChange?(true)
            }
        } catch {
            handleError("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopFileRecording() {
        audioRecorder?.stop()
        audioRecorder = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.isTranscribing = true
            self.onRecordingStateChange?(false)
        }

        // Transcribe the recorded file
        guard let url = recordingURL else {
            handleError("No recording URL")
            return
        }

        transcribeFile(at: url)
    }

    private func transcribeFile(at url: URL) {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            // Fall back to server-side transcription
            transcribeOnServer(fileURL: url)
            return
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isTranscribing = false

                if let error = error {
                    self.handleError("Transcription failed: \(error.localizedDescription)")
                    return
                }

                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.hasCompletedTranscription = true
                    self.onTranscriptionComplete?(self.transcribedText)
                }
            }
        }
    }

    // MARK: - Server-side Transcription

    private func transcribeOnServer(fileURL: URL) {
        guard let appDelegate = NewsBlurAppDelegate.shared(),
              let baseURL = appDelegate.url else {
            handleError("Unable to get server URL")
            return
        }

        guard let url = URL(string: "\(baseURL)/ask-ai/transcribe") else {
            handleError("Invalid transcription URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add audio file
        guard let audioData = try? Data(contentsOf: fileURL) else {
            handleError("Failed to read audio file")
            return
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"recording.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Add cookies for authentication
        if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            let cookieHeaders = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in cookieHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.isTranscribing = false

                if let error = error {
                    self.handleError("Server transcription failed: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self.handleError("No response from server")
                    return
                }

                do {
                    let response = try JSONDecoder().decode(AskAITranscribeResponse.self, from: data)
                    if response.code == 1, let text = response.text {
                        self.transcribedText = text
                        self.hasCompletedTranscription = true
                        self.onTranscriptionComplete?(text)
                    } else {
                        self.handleError(response.message ?? "Transcription failed")
                    }
                } catch {
                    self.handleError("Failed to parse transcription response")
                }
            }
        }.resume()
    }

    // MARK: - Error Handling

    private func handleError(_ message: String) {
        DispatchQueue.main.async {
            self.error = message
            self.isRecording = false
            self.isTranscribing = false
            self.hasCompletedTranscription = true
            self.onTranscriptionError?(message)
            self.onRecordingStateChange?(false)
        }
    }
}
