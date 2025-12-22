//
//  VoiceService.swift
//  byollm-assistantOS
//
//  Voice API integration for STT and TTS
//

import Foundation
import AVFoundation

enum VoiceError: Error, LocalizedError {
    case invalidURL
    case transcriptionFailed(String)
    case synthesisFailed(String)
    case audioPlaybackFailed
    case serviceNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .synthesisFailed(let message):
            return "Speech synthesis failed: \(message)"
        case .audioPlaybackFailed:
            return "Audio playback failed"
        case .serviceNotAvailable:
            return "Voice service not available"
        }
    }
}

// MARK: - Response Models

struct TranscriptionResponse: Decodable {
    let text: String
}

struct VoiceStatusResponse: Decodable {
    let stt: STTStatus?
    let tts: TTSStatus?
    
    struct STTStatus: Decodable {
        let enabled: Bool
        let loaded: Bool
        let model: String?
        let device: String?
    }
    
    struct TTSStatus: Decodable {
        let enabled: Bool
        let loaded: Bool
        let voice: String?
        let sample_rate: Int?
    }
}

// MARK: - Voice Service

class VoiceService: ObservableObject {
    @Published var isSTTAvailable = false
    @Published var isTTSAvailable = false
    @Published var isSpeaking = false
    @Published var currentVoice: String = "af_heart"
    @Published var speechSpeed: Float = 1.0
    
    private var audioPlayer: AVAudioPlayer?
    private var baseURL: URL?
    
    // Available voices
    static let availableVoices = [
        ("af_heart", "Heart (Female)"),
        ("af_bella", "Bella (Female)"),
        ("af_nicole", "Nicole (Female)"),
        ("af_sarah", "Sarah (Female)"),
        ("af_sky", "Sky (Female)"),
        ("am_adam", "Adam (Male)"),
        ("am_michael", "Michael (Male)"),
        ("bf_emma", "Emma (British Female)"),
        ("bf_isabella", "Isabella (British Female)"),
        ("bm_george", "George (British Male)"),
        ("bm_lewis", "Lewis (British Male)")
    ]
    
    init() {
        setupAudioSession()
    }
    
    func configure(serverAddress: String) {
        var address = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.hasPrefix("http://") && !address.hasPrefix("https://") {
            address = "http://\(address)"
        }
        self.baseURL = URL(string: address)
        
        // Check service status
        Task {
            await checkStatus()
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Status Check
    
    func checkStatus() async {
        guard let url = baseURL?.appendingPathComponent("/v1/audio/status") else { 
            print("[Voice] No base URL for status check")
            return 
        }
        
        print("[Voice] Checking status at: \(url)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let status = try JSONDecoder().decode(VoiceStatusResponse.self, from: data)
            
            await MainActor.run {
                self.isSTTAvailable = status.stt?.enabled ?? false
                self.isTTSAvailable = status.tts?.enabled ?? false
                print("[Voice] Status - STT: \(self.isSTTAvailable), TTS: \(self.isTTSAvailable)")
            }
        } catch {
            print("[Voice] Failed to check status: \(error)")
            // Assume services are available if we can't check (server might not have status endpoint)
            await MainActor.run {
                self.isSTTAvailable = true
                self.isTTSAvailable = true
                print("[Voice] Assuming services available (status check failed)")
            }
        }
    }
    
    // MARK: - Speech-to-Text (Transcription)
    
    func transcribe(audioData: Data, filename: String = "audio.wav") async throws -> String {
        guard let url = baseURL?.appendingPathComponent("/v1/audio/transcriptions") else {
            throw VoiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceError.transcriptionFailed("Invalid response")
        }
        
        if httpResponse.statusCode == 503 {
            throw VoiceError.serviceNotAvailable
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw VoiceError.transcriptionFailed(detail)
            }
            throw VoiceError.transcriptionFailed("Status \(httpResponse.statusCode)")
        }
        
        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }
    
    // MARK: - Text-to-Speech (Synthesis)
    
    func synthesize(text: String, voice: String? = nil, speed: Float? = nil) async throws -> Data {
        guard let url = baseURL?.appendingPathComponent("/v1/audio/speech") else {
            throw VoiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["input": text]
        body["voice"] = voice ?? currentVoice
        body["speed"] = speed ?? speechSpeed
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoiceError.synthesisFailed("Invalid response")
        }
        
        if httpResponse.statusCode == 503 {
            throw VoiceError.serviceNotAvailable
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw VoiceError.synthesisFailed(detail)
            }
            throw VoiceError.synthesisFailed("Status \(httpResponse.statusCode)")
        }
        
        return data
    }
    
    // MARK: - Audio Playback
    
    func speak(text: String, completion: (() -> Void)? = nil) async {
        guard !text.isEmpty else { 
            print("[TTS] Empty text, skipping")
            completion?()
            return 
        }
        
        print("[TTS] Speaking: \(text.prefix(50))...")
        print("[TTS] Server URL: \(baseURL?.absoluteString ?? "nil")")
        print("[TTS] TTS Available: \(isTTSAvailable)")
        
        await MainActor.run { isSpeaking = true }
        
        do {
            print("[TTS] Requesting synthesis...")
            let audioData = try await synthesize(text: text)
            print("[TTS] Got audio data: \(audioData.count) bytes")
            try await playAudio(data: audioData)
            print("[TTS] Playback complete")
        } catch {
            print("[TTS] Error: \(error)")
        }
        
        await MainActor.run { 
            isSpeaking = false
            print("[TTS] Calling onSpeakingFinished callback")
            onSpeakingFinished?()
        }
        completion?()
    }
    
    private var audioPlayerDelegate: AudioPlayerDelegateHandler?
    private var currentPlaybackContinuation: CheckedContinuation<Void, Error>?
    var onSpeakingFinished: (() -> Void)?
    
    func playAudio(data: Data) async throws {
        // Ensure we're on main thread and audio session is configured
        await MainActor.run {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
                try session.setActive(true)
            } catch {
                print("[TTS] Audio session error: \(error)")
            }
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.main.async {
                do {
                    // Store continuation for delegate callback
                    self.currentPlaybackContinuation = continuation
                    
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    self.audioPlayer?.volume = 1.0
                    
                    self.audioPlayerDelegate = AudioPlayerDelegateHandler { [weak self] in
                        print("[TTS] Playback finished callback")
                        self?.audioPlayer = nil
                        self?.audioPlayerDelegate = nil
                        if let cont = self?.currentPlaybackContinuation {
                            self?.currentPlaybackContinuation = nil
                            cont.resume()
                        }
                    }
                    self.audioPlayer?.delegate = self.audioPlayerDelegate
                    self.audioPlayer?.prepareToPlay()
                    
                    print("[TTS] Starting playback, duration: \(self.audioPlayer?.duration ?? 0)s")
                    
                    if self.audioPlayer?.play() != true {
                        print("[TTS] play() returned false")
                        self.currentPlaybackContinuation = nil
                        continuation.resume(throwing: VoiceError.audioPlaybackFailed)
                    }
                } catch {
                    print("[TTS] AVAudioPlayer init error: \(error)")
                    self.currentPlaybackContinuation = nil
                    continuation.resume(throwing: VoiceError.audioPlaybackFailed)
                }
            }
        }
    }
    
    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        audioPlayerDelegate = nil
        if let cont = currentPlaybackContinuation {
            currentPlaybackContinuation = nil
            cont.resume()
        }
        isSpeaking = false
    }
}

// MARK: - Audio Player Delegate Helper

private class AudioPlayerDelegateHandler: NSObject, AVAudioPlayerDelegate {
    private var completion: (() -> Void)?
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        completion?()
        completion = nil
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        completion?()
        completion = nil
    }
}

// MARK: - Audio Recorder for Voice Mode with Silence Detection

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioData: Data?
    @Published var audioLevel: Float = 0
    @Published var detectedSilence = false
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?
    
    // Silence detection settings
    private let silenceThreshold: Float = -35.0  // dB threshold for silence (raised for better detection)
    private let silenceDuration: TimeInterval = 1.2  // Seconds of silence before auto-stop
    private var silenceStartTime: Date?
    private var hasDetectedSpeech = false  // Track if we've heard speech at all
    
    // Callback for when silence is detected
    var onSilenceDetected: (() -> Void)?
    
    override init() {
        super.init()
        setupRecordingURL()
    }
    
    private func setupRecordingURL() {
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("voice_recording.wav")
    }
    
    func startRecording() {
        print("[Recorder] Starting recording...")
        
        // Configure audio session for recording
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            print("[Recorder] Audio session configured")
        } catch {
            print("[Recorder] Audio session error: \(error)")
        }
        
        guard let url = recordingURL else { 
            print("[Recorder] No recording URL")
            return 
        }
        
        // Delete old file
        try? FileManager.default.removeItem(at: url)
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            if audioRecorder?.record() == true {
                isRecording = true
                detectedSilence = false
                silenceStartTime = nil
                hasDetectedSpeech = false
                
                // Start monitoring audio levels
                startLevelMonitoring()
                print("[Recorder] Recording started successfully")
            } else {
                print("[Recorder] record() returned false")
            }
        } catch {
            print("[Recorder] Failed to start recording: \(error)")
        }
    }
    
    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAudioLevel()
        }
    }
    
    private func updateAudioLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        
        DispatchQueue.main.async {
            // Normalize to 0-1 range for UI
            self.audioLevel = max(0, min(1, (level + 60) / 60))
        }
        
        // Log levels periodically for debugging
        // print("[Recorder] Level: \(level) dB")
        
        // Check for silence (only after we've detected speech)
        if level < silenceThreshold {
            if hasDetectedSpeech {
                if silenceStartTime == nil {
                    silenceStartTime = Date()
                    print("[Recorder] Silence started...")
                } else if let startTime = silenceStartTime,
                          Date().timeIntervalSince(startTime) >= silenceDuration {
                    // Silence detected for long enough
                    print("[Recorder] Silence duration reached, triggering callback")
                    DispatchQueue.main.async {
                        self.detectedSilence = true
                        self.onSilenceDetected?()
                    }
                }
            }
        } else {
            // Sound detected
            if !hasDetectedSpeech {
                print("[Recorder] Speech detected!")
                hasDetectedSpeech = true
            }
            silenceStartTime = nil
        }
    }
    
    func stopRecording() -> Data? {
        print("[Recorder] Stopping recording...")
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0
        
        guard let url = recordingURL else { 
            print("[Recorder] No recording URL")
            return nil 
        }
        
        do {
            let data = try Data(contentsOf: url)
            audioData = data
            print("[Recorder] Recording saved: \(data.count) bytes")
            return data
        } catch {
            print("[Recorder] Failed to read recording: \(error)")
            return nil
        }
    }
    
    func cancelRecording() {
        print("[Recorder] Cancelling recording")
        levelTimer?.invalidate()
        levelTimer = nil
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0
        detectedSilence = false
        hasDetectedSpeech = false
    }
}
