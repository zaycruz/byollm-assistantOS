//
//  VoiceWebSocket.swift
//  byollm-assistantOS
//
//  WebSocket-based voice conversation for real-time streaming
//

import Foundation
import AVFoundation
import Darwin

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
    private var wavAudioPlayer: AVAudioPlayer?  // For WAV fallback playback
    
    // Serialize all playback + counters to avoid races
    private let audioQueue = DispatchQueue(label: "VoiceWebSocketManager.audio")
    private let audioQueueKey = DispatchSpecificKey<Void>()
    private var playbackSampleRate: Double = 24000
    private var playbackGraphConnected: Bool = false
    private var wavIsPlaying: Bool = false
    private var pendingPCMBufferCount: Int = 0
    private var serverTurnComplete: Bool = false
    
    private var locallyInterrupted: Bool = false
    private var didNotifyTurnComplete: Bool = false
    
    // ChatGPT-style "drop stale chunks" gating by response_id
    private var activeResponseId: String?
    private var awaitingNewResponseId: Bool = true
    private var cancelledResponseIds: [String] = []
    private let cancelledResponseIdMaxCount: Int = 8
    
    // Gating for mic send + audio playback to avoid "late chunks" after stop
    private let gateQueue = DispatchQueue(label: "VoiceWebSocketManager.gate")
    private let gateQueueKey = DispatchSpecificKey<Void>()
    private var gateIsListening: Bool = false
    private var gateIsSpeaking: Bool = false
    private var gateAcceptIncomingAudio: Bool = true
    
    // Lock-free gate reads for realtime audio callbacks.
    // Avoids `gateQueue.sync` from the render/tap threads.
    private var gateBits: Int32 = 0
    private let gateBitListening: Int32 = 1 << 0
    private let gateBitSpeaking: Int32 = 1 << 1
    private let gateBitAcceptIncomingAudio: Int32 = 1 << 2

    // Client-side barge-in (interruption) fallback
    // If the server doesn't emit `interrupted`, we still stop audio immediately
    private var bargeInFrameCount: Int = 0
    private var lastBargeInTime: TimeInterval = 0
    // NOTE: Threshold is intentionally conservative to avoid false barge-in from speaker bleed.
    private let bargeInLevelThreshold: Float = 0.12 // avgLevel (0..1), pre-amplification
    private let bargeInMinFrames: Int = 3           // ~250-300ms at current tap cadence
    private let bargeInCooldownSeconds: TimeInterval = 1.0
    
    private var serverURL: URL?
    private var conversationId: String?
    private var duplexAudioSessionConfigured: Bool = false
    
    // Callbacks
    var onResponseComplete: (() -> Void)?
    var onTranscript: ((String) -> Void)?
    var onAIResponse: ((String) -> Void)?
    
    // MARK: - Init
    
    override init() {
        super.init()
        gateQueue.setSpecific(key: gateQueueKey, value: ())
        audioQueue.setSpecific(key: audioQueueKey, value: ())
        // Ensure atomic gate bits match default boolean values.
        // Defaults: listening=false, speaking=false, acceptIncomingAudio=true
        setGate(isListening: false, isSpeaking: false, acceptIncomingAudio: true, synchronously: true)
        setupPlayback()
    }
    
    // MARK: - Gate helpers (thread-safe reads from audio callback)
    
    private func setGate(
        isListening: Bool? = nil,
        isSpeaking: Bool? = nil,
        acceptIncomingAudio: Bool? = nil,
        synchronously: Bool = false
    ) {
        let apply = { [weak self] in
            guard let self else { return }
            if let isListening {
                self.gateIsListening = isListening
                self.atomicSetGateBit(self.gateBitListening, enabled: isListening)
            }
            if let isSpeaking {
                self.gateIsSpeaking = isSpeaking
                self.atomicSetGateBit(self.gateBitSpeaking, enabled: isSpeaking)
            }
            if let acceptIncomingAudio {
                self.gateAcceptIncomingAudio = acceptIncomingAudio
                self.atomicSetGateBit(self.gateBitAcceptIncomingAudio, enabled: acceptIncomingAudio)
            }
        }
        
        if DispatchQueue.getSpecific(key: gateQueueKey) != nil {
            apply()
            return
        }
        
        if synchronously {
            gateQueue.sync(execute: apply)
        } else {
            gateQueue.async(execute: apply)
        }
    }
    
    @inline(__always)
    private func atomicLoadGateBits() -> Int32 {
        // Atomic read using OSAtomic (deprecated but lock-free and available).
        // We use it to avoid any blocking on realtime audio callback threads.
        OSAtomicAdd32Barrier(0, &gateBits)
    }
    
    @inline(__always)
    private func atomicSetGateBit(_ bit: Int32, enabled: Bool) {
        while true {
            let old = atomicLoadGateBits()
            let new = enabled ? (old | bit) : (old & ~bit)
            if old == new { return }
            if OSAtomicCompareAndSwap32Barrier(old, new, &gateBits) {
                return
            }
        }
    }
    
    @inline(__always)
    private func atomicGateIsListening() -> Bool {
        (atomicLoadGateBits() & gateBitListening) != 0
    }
    
    @inline(__always)
    private func atomicGateIsSpeaking() -> Bool {
        (atomicLoadGateBits() & gateBitSpeaking) != 0
    }
    
    @inline(__always)
    private func atomicGateAcceptIncomingAudio() -> Bool {
        (atomicLoadGateBits() & gateBitAcceptIncomingAudio) != 0
    }
    
    private func canSendMicAudioToServer() -> Bool {
        // Only send mic while the server is explicitly listening and we're not speaking locally.
        // This avoids echo / self-interruption while TTS is playing.
        atomicGateIsListening() && !atomicGateIsSpeaking()
    }
    
    private func canPlayIncomingAudio() -> Bool {
        atomicGateAcceptIncomingAudio()
    }
    
    private func withAudioQueueSync(_ block: () -> Void) {
        if DispatchQueue.getSpecific(key: audioQueueKey) != nil {
            block()
        } else {
            audioQueue.sync(execute: block)
        }
    }
    
    private func withAudioQueueAsync(_ block: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: audioQueueKey) != nil {
            block()
        } else {
            audioQueue.async(execute: block)
        }
    }
    
    private func notifyTurnCompleteIfNeeded() {
        guard !didNotifyTurnComplete else { return }
        didNotifyTurnComplete = true
        onResponseComplete?()
    }
    
    private func normalizeResponseId(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let i = value as? Int { return String(i) }
        if let d = value as? Double { return String(Int(d)) }
        return nil
    }
    
    private func parseSampleRate(_ value: Any?) -> Double {
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String, let d = Double(s) { return d }
        return 24000
    }
    
    private func markResponseIdCancelled(_ responseId: String?) {
        guard let responseId, !responseId.isEmpty else { return }
        cancelledResponseIds.append(responseId)
        if cancelledResponseIds.count > cancelledResponseIdMaxCount {
            cancelledResponseIds.removeFirst(cancelledResponseIds.count - cancelledResponseIdMaxCount)
        }
    }
    
    private func isResponseIdCancelled(_ responseId: String) -> Bool {
        cancelledResponseIds.contains(responseId)
    }
    
    private func advanceActiveResponseId(toNext nextResponseId: String?) {
        if let nextResponseId, !nextResponseId.isEmpty {
            activeResponseId = nextResponseId
            awaitingNewResponseId = false
        } else {
            // We don't know the next id yet; accept the next non-cancelled response_id we see.
            awaitingNewResponseId = true
        }
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
        // Configure duplex session early to avoid mid-stream mode switches.
        configureDuplexAudioSessionIfNeeded()
    }
    
    func disconnect() {
        print("[WS] Disconnecting")
        // Best-effort stop any in-flight generation/audio server-side
        send(["type": "interrupt"])
        locallyInterrupted = true
        setGate(isListening: false, isSpeaking: false, acceptIncomingAudio: false, synchronously: true)
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
        locallyInterrupted = false
        didNotifyTurnComplete = false
        awaitingNewResponseId = true
        withAudioQueueSync {
            self.serverTurnComplete = false
            self.pendingPCMBufferCount = 0
            self.wavIsPlaying = false
        }
        // Don't accept any late audio from a previous turn while we're starting a new one.
        setGate(isListening: false, isSpeaking: false, acceptIncomingAudio: false, synchronously: true)
        
        // Configure duplex audio session (do not switch modes mid-conversation)
        configureDuplexAudioSessionIfNeeded()
        
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
        
        // Stop sending audio immediately; keep the tap installed for barge-in / levels until voice mode ends.
        setGate(isListening: false)
    }
    
    /// Immediately stops local audio playback and best-effort interrupts server generation.
    /// Voice mode stays connected; caller can decide whether to resume listening.
    func interruptCurrentTurn() {
        print("[WS] Interrupt requested -> stopping playback and ignoring further audio")
        // Cancel anything from the currently-active response id (if known)
        markResponseIdCancelled(activeResponseId)
        advanceActiveResponseId(toNext: nil)
        
        locallyInterrupted = true
        isProcessing = false
        isSpeaking = false
        setGate(isListening: false, isSpeaking: false, acceptIncomingAudio: false, synchronously: true)
        
        // Stop local playback right away
        stopAllPlayback()
        
        // Best-effort notify server (server may ignore if unsupported)
        send(["type": "interrupt"])
        
        // Allow UI to resume listening (after its own delay) if desired
        notifyTurnCompleteIfNeeded()
    }
    
    func clearHistory() {
        send(["type": "clear"])
        transcribedText = ""
        responseText = ""
    }
    
    // MARK: - Audio Session (Duplex)
    
    /// Configure a single duplex session for always-on mic + speaker playback.
    /// Avoid switching categories/modes mid-conversation (common source of dropouts/cutoffs).
    private func configureDuplexAudioSessionIfNeeded() {
        guard !duplexAudioSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            duplexAudioSessionConfigured = true
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

        // Client-side barge-in: if user speaks while AI is speaking,
        // immediately stop local playback and notify server (best-effort).
        handleLocalBargeInIfNeeded(avgLevel: avgLevel)
        
        DispatchQueue.main.async {
            self.audioLevel = min(1.0, avgLevel * 3)  // Amplify for visibility
        }
        
        // Send PCM16 bytes over WebSocket only when actively listening.
        // This avoids echo / "self-barge-in" while assistant audio is playing.
        guard canSendMicAudioToServer() else { return }
        
        let byteCount = frameLength * 2  // 2 bytes per Int16
        let data = Data(bytes: int16Data[0], count: byteCount)
        
        webSocket?.send(.data(data)) { error in
            if let error = error {
                print("[WS] Send error: \(error)")
            }
        }
    }

    private func handleLocalBargeInIfNeeded(avgLevel: Float) {
        // Use lock-free gate reads (realtime-safe) instead of queue sync on the audio thread.
        guard atomicGateIsSpeaking() else {
            bargeInFrameCount = 0
            return
        }

        let now = Date().timeIntervalSince1970
        if now - lastBargeInTime < bargeInCooldownSeconds {
            return
        }

        if avgLevel > bargeInLevelThreshold {
            bargeInFrameCount += 1
            if bargeInFrameCount >= bargeInMinFrames {
                bargeInFrameCount = 0
                lastBargeInTime = now

                print("[WS] Local barge-in detected (avgLevel=\(avgLevel)) -> stopping playback")

                // Stop audio immediately and best-effort interrupt server
                DispatchQueue.main.async { [weak self] in
                    self?.status = "Interrupted"
                    self?.interruptCurrentTurn()
                }
            }
        } else {
            // decay quickly so brief blips don't accumulate forever
            bargeInFrameCount = max(0, bargeInFrameCount - 1)
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
        playbackEngine.attach(playerNode)
    }
    
    private func startPlaybackEngineIfNeeded(sampleRate: Double) {
        // Must be called on audioQueue
        guard DispatchQueue.getSpecific(key: audioQueueKey) != nil else {
            assertionFailure("startPlaybackEngineIfNeeded(sampleRate:) must run on audioQueue")
            return
        }
        
        // Ensure graph is connected with a stable format
        if !playbackGraphConnected || playbackSampleRate != sampleRate {
            // Stop before reconnect
            if playbackEngine.isRunning {
                playbackEngine.stop()
            }
            playerNode.stop()
            playerNode.reset()
            
            playbackEngine.disconnectNodeOutput(playerNode)
            
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ) else {
                print("[WS] Failed to create playback format (Int16) @ \(sampleRate)Hz")
                return
            }
            
            playbackEngine.connect(playerNode, to: playbackEngine.mainMixerNode, format: format)
            playbackSampleRate = sampleRate
            playbackGraphConnected = true
        }
        
        if !playbackEngine.isRunning {
            do {
                try playbackEngine.start()
                print("[WS] Playback engine started")
            } catch {
                print("[WS] Playback engine error: \(error)")
            }
        }
        
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    private func stopPlayback() {
        withAudioQueueAsync { [weak self] in
            guard let self else { return }
            self.playerNode.stop()
            if self.playbackEngine.isRunning {
                self.playbackEngine.stop()
            }
            self.playbackGraphConnected = false
            self.wavIsPlaying = false
            self.pendingPCMBufferCount = 0
            self.serverTurnComplete = false
            print("[WS] Playback engine stopped")
        }
    }
    
    /// Play streaming PCM16 chunk (24kHz mono)
    private func playPCMChunk(_ data: Data, sampleRate: Double = 24000) {
        guard data.count % 2 == 0 else { return }
        
        withAudioQueueAsync { [weak self] in
            guard let self else { return }
            guard self.canPlayIncomingAudio() else { return }
            
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: false
            ) else { return }
            
            let frames = AVAudioFrameCount(data.count / 2)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
            buffer.frameLength = frames
            
            data.withUnsafeBytes { raw in
                if let base = raw.baseAddress, let dst = buffer.int16ChannelData?[0] {
                    memcpy(dst, base, data.count)
                }
            }
            
            self.startPlaybackEngineIfNeeded(sampleRate: sampleRate)
            
            self.pendingPCMBufferCount += 1
            self.playerNode.scheduleBuffer(buffer) { [weak self] in
                guard let self else { return }
                self.withAudioQueueAsync {
                    self.pendingPCMBufferCount = max(0, self.pendingPCMBufferCount - 1)
                    self.maybeFinishTurnIfReady()
                }
            }
        }
    }
    
    /// Play full WAV audio (fallback)
    private func playWAVAudio(_ data: Data) {
        withAudioQueueAsync { [weak self] in
            guard let self else { return }
            guard self.canPlayIncomingAudio() else { return }
            
            // Stop any existing WAV playback
            self.wavAudioPlayer?.stop()
            self.wavAudioPlayer = nil
            self.wavIsPlaying = false
            
            do {
                self.wavAudioPlayer = try AVAudioPlayer(data: data)
                self.wavAudioPlayer?.delegate = self
                self.wavAudioPlayer?.prepareToPlay()
                self.wavIsPlaying = true
                self.wavAudioPlayer?.play()
                
                print("[WS] WAV playback started, duration: \(self.wavAudioPlayer?.duration ?? 0)s")
            } catch {
                print("[WS] WAV playback error: \(error)")
                self.wavIsPlaying = false
                DispatchQueue.main.async { [weak self] in
                    self?.isSpeaking = false
                    self?.setGate(isSpeaking: false, synchronously: true)
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
        
        let responseId = normalizeResponseId(event["response_id"])
        let nextResponseId = normalizeResponseId(event["next_response_id"])
        
        // ChatGPT-style "drop stale chunks" rule:
        // - Maintain activeResponseId
        // - If an event has response_id != activeResponseId, ignore it (esp. audio)
        // - On "interrupted", move activeResponseId forward to next_response_id (if provided)
        // We always process "ready" + interruption/error signals, but gate content-bearing events.
        let alwaysProcessTypes: Set<String> = ["ready", "interrupted", "error", "tts_error", "llm_error", "stt_error"]
        
        if let responseId, !alwaysProcessTypes.contains(type) {
            if isResponseIdCancelled(responseId) {
                // Drop anything from cancelled responses (buffering/jitter safety)
                return
            }
            
            if awaitingNewResponseId {
                // First valid response_id we see becomes active
                activeResponseId = responseId
                awaitingNewResponseId = false
            } else if let activeResponseId, responseId != activeResponseId {
                // Stale chunk/event from a previous response; drop it.
                return
            }
        }
        
        switch type {
            
        case "ready":
            conversationId = event["conversation_id"] as? String
            status = "Ready"
            isConnected = true
            print("[WS] Ready with conversation: \(conversationId ?? "unknown")")
            // If server provides an initial next_response_id, use it to gate immediately.
            if let nextResponseId {
                advanceActiveResponseId(toNext: nextResponseId)
            } else {
                awaitingNewResponseId = true
            }
            
        case "listening":
            isListening = true
            status = "Listening..."
            locallyInterrupted = false
            didNotifyTurnComplete = false
            withAudioQueueAsync { [weak self] in
                guard let self else { return }
                self.serverTurnComplete = false
                self.pendingPCMBufferCount = 0
                self.wavIsPlaying = false
            }
            // While listening, we don't expect any TTS audio from the server.
            setGate(isListening: true, acceptIncomingAudio: false, synchronously: true)
            
        case "stopped":
            isListening = false
            status = "Processing..."
            setGate(isListening: false, synchronously: true)
            
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
            notifyTurnCompleteIfNeeded()
            
        case "generating":
            status = "Generating..."
            responseText = ""
            isProcessing = true
            
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
            guard !locallyInterrupted else { break }
            status = "Speaking..."
            isSpeaking = true
            setGate(isSpeaking: true, acceptIncomingAudio: true, synchronously: true)
            
        case "audio_chunk":
            // Streaming PCM audio chunks
            guard !locallyInterrupted, canPlayIncomingAudio() else { break }
            if let b64 = event["data"] as? String,
               let audioData = Data(base64Encoded: b64) {
                let sampleRate = parseSampleRate(event["sample_rate"])
                playPCMChunk(audioData, sampleRate: sampleRate)
            }
            
        case "audio_phrase_end":
            // A phrase finished speaking
            break
            
        case "audio":
            // Full WAV audio (fallback)
            guard !locallyInterrupted, canPlayIncomingAudio() else { break }
            if let b64 = event["data"] as? String,
               let audioData = Data(base64Encoded: b64) {
                print("[WS] Playing WAV audio: \(audioData.count) bytes")
                playWAVAudio(audioData)
            }
            
        case "complete":
            isProcessing = false
            status = "Complete"
            print("[WS] Turn complete (server) -> waiting for playback drain")
            withAudioQueueAsync { [weak self] in
                guard let self else { return }
                self.serverTurnComplete = true
                self.maybeFinishTurnIfReady()
            }
            // Keep accepting any late-arriving audio chunks for this turn; we'll resume listening
            // only after playback drains.
            setGate(isListening: false, synchronously: true)
            // Mark this response id cancelled so late chunks can't revive audio after we drain.
            markResponseIdCancelled(responseId ?? activeResponseId)
            // If server tells us the next response id, advance immediately (drop stale chunks).
            advanceActiveResponseId(toNext: nextResponseId)
            maybeFinishTurnIfReady()
            
        case "interrupted":
            print("[WS] Interrupted - stopping audio immediately")
            isProcessing = false
            isSpeaking = false
            status = "Interrupted"
            
            // CRITICAL: Immediately stop all queued audio
            markResponseIdCancelled(responseId ?? activeResponseId)
            // Move activeResponseId forward so stale chunks from the interrupted response are dropped.
            advanceActiveResponseId(toNext: nextResponseId)
            locallyInterrupted = true
            setGate(isListening: false, isSpeaking: false, acceptIncomingAudio: false, synchronously: true)
            stopAllPlayback()
            notifyTurnCompleteIfNeeded()
            
        case "error", "tts_error", "llm_error", "stt_error":
            if let errorMsg = event["error"] as? String {
                status = "Error: \(errorMsg)"
                print("[WS] Error: \(errorMsg)")
            }
            isProcessing = false
            isSpeaking = false
            markResponseIdCancelled(responseId ?? activeResponseId)
            advanceActiveResponseId(toNext: nextResponseId)
            locallyInterrupted = true
            setGate(isListening: false, isSpeaking: false, acceptIncomingAudio: false, synchronously: true)
            stopAllPlayback()
            notifyTurnCompleteIfNeeded()
            
        default:
            print("[WS] Unknown event: \(type)")
        }
    }
    
    // MARK: - Interruption Handling
    
    private func stopAllPlayback() {
        withAudioQueueSync { [weak self] in
            guard let self else { return }
            
            // Stop PCM streaming playback (AVAudioPlayerNode) and drop queued buffers.
            self.playerNode.stop()
            self.playerNode.reset()
            self.pendingPCMBufferCount = 0
            
            // Stop WAV playback (AVAudioPlayer)
            self.wavAudioPlayer?.stop()
            self.wavAudioPlayer = nil
            self.wavIsPlaying = false
            
            // Keep engine running for low latency; ensure player is armed for next turn.
            if self.playbackEngine.isRunning, !self.playerNode.isPlaying {
                self.playerNode.play()
            }
            
            print("[WS] All audio playback stopped")
        }
    }
    
    private func maybeFinishTurnIfReady() {
        // Must be evaluated on audioQueue to avoid races with scheduleBuffer completions.
        guard DispatchQueue.getSpecific(key: audioQueueKey) != nil else {
            withAudioQueueAsync { [weak self] in
                self?.maybeFinishTurnIfReady()
            }
            return
        }
        
        guard serverTurnComplete else { return }
        guard pendingPCMBufferCount == 0, !wavIsPlaying else { return }
        
        // Playback is drained for this turn
        serverTurnComplete = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            // Prevent any late chunks from scheduling audio before we re-enter listening state.
            self.setGate(isSpeaking: false, acceptIncomingAudio: false, synchronously: true)
            self.notifyTurnCompleteIfNeeded()
        }
    }
}

extension VoiceWebSocketManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        withAudioQueueAsync { [weak self] in
            guard let self else { return }
            self.wavIsPlaying = false
            self.maybeFinishTurnIfReady()
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        withAudioQueueAsync { [weak self] in
            guard let self else { return }
            self.wavIsPlaying = false
            self.serverTurnComplete = true
            self.maybeFinishTurnIfReady()
        }
    }
}
