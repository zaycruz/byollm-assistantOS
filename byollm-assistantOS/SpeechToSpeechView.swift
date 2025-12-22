//
//  SpeechToSpeechView.swift
//  byollm-assistantOS
//
//  Speech-to-Speech conversation view with 3D animated orb
//

import SwiftUI
import AVFoundation

struct SpeechToSpeechView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var agentState: AgentState = .idle
    @State private var inputVolume: CGFloat = 0
    @State private var outputVolume: CGFloat = 0
    @State private var statusText: String = "Tap to speak"
    @State private var audioLevelTimer: Timer?
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Spacer()
                
                // 3D Orb
                orbContainer
                
                // Status
                statusView
                
                Spacer()
                
                // Transcript
                transcriptView
                
                // Controls
                controlsView
            }
        }
        .onAppear {
            setupAudioLevelMonitoring()
        }
        .onDisappear {
            cleanUp()
        }
        .onChange(of: speechRecognizer.isRecording) { _, isRecording in
            handleRecordingStateChange(isRecording)
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.1),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Button(action: {
                cleanUp()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Voice Mode")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            // Invisible spacer for centering
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }
    
    // MARK: - Orb Container
    private var orbContainer: some View {
        AnimatedOrb(
            agentState: agentState,
            inputVolume: inputVolume,
            outputVolume: outputVolume,
            size: 240
        )
        .frame(width: 280, height: 280)
        .contentShape(Circle())
        .onTapGesture {
            toggleListening()
        }
    }
    
    // MARK: - Status View
    private var statusView: some View {
        VStack(spacing: 8) {
            Text(statusText)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
            
            if agentState == .listening {
                Text("Tap orb to stop")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.top, 24)
        .animation(.easeInOut(duration: 0.3), value: statusText)
    }
    
    // MARK: - Transcript View
    private var transcriptView: some View {
        Group {
            if !speechRecognizer.transcript.isEmpty {
                VStack(spacing: 8) {
                    Text("You said:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(speechRecognizer.transcript)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 40)
                }
                .padding(.vertical, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: speechRecognizer.transcript)
    }
    
    // MARK: - Controls View
    private var controlsView: some View {
        HStack(spacing: 60) {
            // Mute button (placeholder)
            Button(action: {
                // Toggle mute
            }) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // End call button
            Button(action: {
                cleanUp()
                dismiss()
            }) {
                Image(systemName: "phone.down.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            
            // Settings button (placeholder)
            Button(action: {
                // Open settings
            }) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 50, height: 50)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Actions
    private func toggleListening() {
        if speechRecognizer.isRecording {
            stopListeningAndProcess()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        speechRecognizer.startRecording()
        agentState = .listening
        statusText = "Listening..."
    }
    
    private func stopListeningAndProcess() {
        speechRecognizer.stopRecording()
        
        if !speechRecognizer.transcript.isEmpty {
            agentState = .thinking
            statusText = "Thinking..."
            inputVolume = 0
            
            // TODO: Send transcript to LLM and get audio response
            // Simulating processing time
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.agentState = .talking
                self.statusText = "Speaking..."
                
                // Simulate speaking with random volume changes
                self.simulateSpeaking()
            }
        } else {
            agentState = .idle
            statusText = "Tap to speak"
        }
    }
    
    private func simulateSpeaking() {
        // Simulate output volume changes while "speaking"
        var speakingTime: Double = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            speakingTime += 0.1
            
            // Random volume fluctuation
            withAnimation(.easeOut(duration: 0.1)) {
                self.outputVolume = CGFloat.random(in: 0.3...0.8)
            }
            
            // Stop after 3 seconds
            if speakingTime >= 3.0 {
                timer.invalidate()
                withAnimation {
                    self.outputVolume = 0
                    self.agentState = .idle
                    self.statusText = "Tap to speak"
                }
            }
        }
    }
    
    private func handleRecordingStateChange(_ isRecording: Bool) {
        if isRecording {
            agentState = .listening
            statusText = "Listening..."
        }
    }
    
    private func setupAudioLevelMonitoring() {
        // Monitor audio levels when recording
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // Check if we're in listening state (UI state reflects recording)
            guard agentState == .listening else { return }
            // Simulate volume based on transcript changes
            // In production, you'd get actual audio levels from AVAudioEngine
            withAnimation(.easeOut(duration: 0.05)) {
                inputVolume = CGFloat.random(in: 0.2...0.9)
            }
        }
    }
    
    private func cleanUp() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        speechRecognizer.stopRecording()
    }
}

#Preview {
    SpeechToSpeechView()
}
