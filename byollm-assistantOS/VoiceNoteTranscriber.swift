import AVFoundation
import Foundation
import Speech

@MainActor
final class VoiceNoteTranscriber: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }
    
    @Published private(set) var state: State = .idle
    @Published private(set) var transcript: String = ""
    @Published var finalTranscript: String?
    
    private let speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    func start() async {
        guard case .idle = state else { return }
        
        let ok = await requestPermissions()
        guard ok else {
            state = .error("Microphone or speech recognition permission denied.")
            return
        }
        
        guard let recognizer = speechRecognizer else {
            state = .error("Speech recognizer unavailable on this device.")
            return
        }
        
        guard recognizer.isAvailable else {
            state = .error("Speech recognizer is currently unavailable.")
            return
        }
        
        do {
            transcript = ""
            finalTranscript = nil
            state = .recording
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request
            
            let inputNode = audioEngine.inputNode
            inputNode.removeTap(onBus: 0)
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self else { return }
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                
                if let result {
                    Task { @MainActor in
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal {
                            self.finalTranscript = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.finish()
                        }
                    }
                }
                
                if let error {
                    Task { @MainActor in
                        self.state = .error(error.localizedDescription)
                        self.finishAudioOnly()
                    }
                }
            }
        } catch {
            state = .error(error.localizedDescription)
            finish()
        }
    }
    
    func stop() {
        guard case .recording = state else { return }
        state = .transcribing
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
    }
    
    func resetError() {
        if case .error = state {
            state = .idle
        }
    }
    
    func consumeFinalTranscript() {
        finalTranscript = nil
        if case .transcribing = state {
            state = .idle
        }
        if case .error = state {
            // leave state as-is; user can reset
        }
    }
    
    private func finish() {
        finishAudioOnly()
        if case .error = state {
            return
        }
        if case .recording = state {
            state = .idle
        }
        if case .transcribing = state {
            state = .idle
        }
    }
    
    private func finishAudioOnly() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func requestPermissions() async -> Bool {
        let micAllowed = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
        
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        return micAllowed && speechStatus == .authorized
    }
}

