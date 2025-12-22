//
//  VoiceWebSocket.swift
//  byollm-assistantOS
//
//  WebSocket-based voice conversation for real-time streaming
//

import Foundation
import AVFoundation

class VoiceWebSocketManager: NSObject, ObservableObject {
    
    // MARK: - Published State
    @Published var isConnected = false
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var responseText = ""
    @Published var status = "Disconnected"
    @Published var audioLevel: Float = 0
    
    // MARK: - Private Properties
    private var webSocket: URLSessionWebSocketTask?
    private var audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode { audioEngine.inputNode }
    private var hasTapInstalled = false
    
    // Playback
    private var playbackEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var playbackFormat: AVAudioFormat?
    
    private var serverURL: URL?
    private var conversationId: String?
    
    // Callbacks
    var onResponseComplete: (() -> Void)?
    var onTranscript: ((String) -> Void)?
    var onAIResponse: ((String) -> Void)?
    
    // MARK: - Init
    
    override init() {
        super.init()
        setupPlayback()
    }
    
    func configure(serverAddress: String) {
        var address = serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.hasPrefix("http://") && !address.hasPrefix("https://") {
            address = "http://\(address)"
        }
        serverURL = URL(string: address)
        print("[WS] Configured with URL: \(serverURL?.absoluteString ?? "nil")")
    }
    
    // MARK: - Connection
    
    func connect() {
        guard let baseURL = serverURL else {
            print("[WS] No server URL configured")
            status = "No server URL"
            return
        }
        
        let wsURL = baseURL.appendingPathComponent("v1/voice/ws")
        
        // Convert http(s) to ws(s)
        var components = URLComponents(url: wsURL, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        
        guard let url = components.url else {
            print("[WS] Failed to create WebSocket URL")
            return
        }
        
        print("[WS] Connecting to: \(url)")
        
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()
        
        receiveMessage()
        isConnected = true
        status = "Connecting..."
    }
    
    func disconnect() {
        print("[WS] Disconnecting")
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        isListening = false
        stopAudioCapture()
        stopPlayback()
        status = "Disconnected"
    }
    
    // MARK: - Voice Control
    
    func startListening() {
        guard isConnected else {
            print("[WS] Not connected, connecting first...")
            connect()
            // Wait a moment for connection then start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startListening()
            }
            return
        }
        
        print("[WS] Starting listening")
        transcribedText = ""
        responseText = ""
        
        // Configure audio session
        configureAudioSession(forRecording: true)
        
        // Start capturing audio
        startAudioCapture()
        
        // Tell server to start listening
        send(["type": "start"])
    }
    
    func stopListening() {
        guard isListening else { return }
        
        print("[WS] Stopping listening")
        
        // Tell server to stop
        send(["type": "stop"])
        
        // Stop capturing
        stopAudioCapture()
    }
    
    func clearHistory() {
        send(["type": "clear"])
        transcribedText = ""
        responseText = ""
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession(forRecording: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            if forRecording {
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            }
            try session.setActive(true)
        } catch {
            print("[WS] Audio session error: \(error)")
        }
    }
    
    // MARK: - Audio Capture (PCM16 mono 16kHz)
    
    private func startAudioCapture() {
        // Don't install if already capturing
        guard !hasTapInstalled else {
            print("[WS] Tap already installed, skipping")
            return
        }
        
        // Get the native format
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        
        // Target format: PCM16, mono, 16kHz
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16000,
            channels: 1,
            interleaved: true
        ) else {
            print("[WS] Failed to create target format")
            return
        }
        
        // Create converter
        guard let converter = AVAudioConverter(from: nativeFormat, to: targetFormat) else {
            print("[WS] Failed to create audio converter")
            return
        }
        
        // Install tap on input
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nativeFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, targetFormat: targetFormat)
        }
        hasTapInstalled = true
        
        do {
            try audioEngine.start()
            print("[WS] Audio capture started")
        } catch {
            print("[WS] Audio engine start error: \(error)")
        }
    }
    
    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        targetFormat: AVAudioFormat
    ) {
        // Calculate output frame count
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCapacity
        ) else { return }
        
        var error: NSError?
        var inputConsumed = false
        
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return buffer
        }
        
        guard status != .error, let int16Data = outputBuffer.int16ChannelData else { return }
        
        // Calculate audio level for UI
        let frameLength = Int(outputBuffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(Float(int16Data[0][i]))
        }
        let avgLevel = sum / Float(max(frameLength, 1)) / 32768.0
        
        DispatchQueue.main.async {
            self.audioLevel = min(1.0, avgLevel * 3)  // Amplify for visibility
        }
        
        // Send PCM16 bytes over WebSocket
        let byteCount = frameLength * 2  // 2 bytes per Int16
        let data = Data(bytes: int16Data[0], count: byteCount)
        
        webSocket?.send(.data(data)) { error in
            if let error = error {
                print("[WS] Send error: \(error)")
            }
        }
    }
    
    private func stopAudioCapture() {
        guard hasTapInstalled else {
            print("[WS] No tap to remove")
            return
        }
        
        // Stop engine first
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap
        inputNode.removeTap(onBus: 0)
        hasTapInstalled = false
        
        audioLevel = 0
        print("[WS] Audio capture stopped")
    }
    
    // MARK: - Audio Playback (Low-Latency Streaming)
    
    private func setupPlayback() {
        // 24kHz mono for Kokoro TTS output
        playbackFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 24000,
            channels: 1,
            interleaved: false
        )
        
        playbackEngine.attach(playerNode)
        if let format = playbackFormat {
            playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: format)
        }
    }
    
    private func startPlaybackEngine() {
        guard !playbackEngine.isRunning else { return }
        
        configureAudioSession(forRecording: false)
        
        do {
            try playbackEngine.start()
            playerNode.play()
            print("[WS] Playback engine started")
        } catch {
            print("[WS] Playback engine error: \(error)")
        }
    }
    
    private func stopPlayback() {
        // Stop all audio
        playerNode.stop()
        if playbackEngine.isRunning {
            playbackEngine.stop()
        }
        print("[WS] Playback engine stopped")
    }
    
    /// Play streaming PCM16 chunk (24kHz mono)
    private func playPCMChunk(_ data: Data, sampleRate: Double = 24000) {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        
        // Convert Data (Int16) to Float32 buffer
        let int16Count = data.count / 2
        let frameCount = AVAudioFrameCount(int16Count)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        
        let floatData = buffer.floatChannelData![0]
        data.withUnsafeBytes { rawBuffer in
            let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<int16Count {
                floatData[i] = Float(int16Buffer[i]) / 32768.0
            }
        }
        
        // Start engine if needed
        startPlaybackEngine()
        
        // Schedule for seamless playback
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }
    
    /// Play full WAV audio (fallback)
    private func playWAVAudio(_ data: Data) {
        DispatchQueue.global().async { [weak self] in
            do {
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay()
                player.play()
                
                // Wait for playback to complete
                while player.isPlaying {
                    Thread.sleep(forTimeInterval: 0.1)
                }
                
                DispatchQueue.main.async {
                    self?.isSpeaking = false
                    self?.onResponseComplete?()
                }
            } catch {
                print("[WS] WAV playback error: \(error)")
                DispatchQueue.main.async {
                    self?.isSpeaking = false
                }
            }
        }
    }
    
    // MARK: - WebSocket Communication
    
    private func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        
        webSocket?.send(.string(text)) { error in
            if let error = error {
                print("[WS] Send error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(.string(let text)):
                self?.handleEvent(text)
                self?.receiveMessage()  // Continue receiving
                
            case .success(.data(_)):
                self?.receiveMessage()
                
            case .failure(let error):
                print("[WS] Receive error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.status = "Disconnected"
                }
            }
        }
    }
    
    private func handleEvent(_ json: String) {
        guard let data = json.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = event["type"] as? String else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.processEvent(type: type, event: event)
        }
    }
    
    private func processEvent(type: String, event: [String: Any]) {
        print("[WS] Event: \(type)")
        
        switch type {
            
        case "ready":
            conversationId = event["conversation_id"] as? String
            status = "Ready"
            isConnected = true
            print("[WS] Ready with conversation: \(conversationId ?? "unknown")")
            
        case "listening":
            isListening = true
            status = "Listening..."
            
        case "stopped":
            isListening = false
            status = "Processing..."
            
        case "transcribing":
            isProcessing = true
            status = "Transcribing..."
            
        case "transcript":
            if let text = event["text"] as? String {
                transcribedText = text
                print("[WS] Transcript: \(text)")
                // Notify callback to add to chat
                onTranscript?(text)
            }
            
        case "transcript_empty":
            status = "No speech detected"
            isProcessing = false
            // Resume listening
            onResponseComplete?()
            
        case "generating":
            status = "Generating..."
            responseText = ""
            
        case "text_delta":
            // Streaming text from LLM
            if let text = event["text"] as? String {
                responseText += text
            }
            
        case "text_complete":
            if let text = event["text"] as? String {
                responseText = text
                print("[WS] Response complete: \(text.prefix(50))...")
                // Notify callback to add to chat
                onAIResponse?(text)
            }
            
        case "synthesizing":
            status = "Speaking..."
            isSpeaking = true
            
        case "audio_chunk":
            // Streaming PCM audio chunks
            if let b64 = event["data"] as? String,
               let audioData = Data(base64Encoded: b64) {
                let sampleRate = (event["sample_rate"] as? Double) ?? 24000
                playPCMChunk(audioData, sampleRate: sampleRate)
            }
            
        case "audio_phrase_end":
            // A phrase finished speaking
            break
            
        case "audio":
            // Full WAV audio (fallback)
            if let b64 = event["data"] as? String,
               let audioData = Data(base64Encoded: b64) {
                print("[WS] Playing WAV audio: \(audioData.count) bytes")
                playWAVAudio(audioData)
            }
            
        case "complete":
            isProcessing = false
            isSpeaking = false
            status = "Complete"
            print("[WS] Turn complete")
            onResponseComplete?()
            
        case "interrupted":
            print("[WS] Interrupted - stopping audio immediately")
            isProcessing = false
            isSpeaking = false
            status = "Interrupted"
            
            // CRITICAL: Immediately stop all queued audio
            stopAllPlayback()
            
        case "error", "tts_error", "llm_error", "stt_error":
            if let errorMsg = event["error"] as? String {
                status = "Error: \(errorMsg)"
                print("[WS] Error: \(errorMsg)")
            }
            isProcessing = false
            isSpeaking = false
            stopAllPlayback()
            onResponseComplete?()
            
        default:
            print("[WS] Unknown event: \(type)")
        }
    }
    
    // MARK: - Interruption Handling
    
    private func stopAllPlayback() {
        // Stop the player node - this immediately halts all scheduled buffers
        playerNode.stop()
        
        // Restart the player for next response
        if playbackEngine.isRunning {
            playerNode.play()
        }
        
        print("[WS] Audio playback stopped")
    }
}
