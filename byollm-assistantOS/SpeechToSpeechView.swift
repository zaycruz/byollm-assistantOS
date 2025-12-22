//
//  SpeechToSpeechView.swift
//  byollm-assistantOS
//
//  Voice conversation interface - similar to ChatGPT Voice
//

import SwiftUI
import AVFoundation

struct SpeechToSpeechView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isListening = false
    @State private var isSpeaking = false
    @State private var responseText = ""
    @State private var inputText = ""
    @State private var audioLevelTimer: Timer?
    @State private var waveformPhase: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Content area - transcript/response
                contentArea
                
                // Bottom input bar
                bottomBar
            }
        }
        .onAppear {
            startWaveformAnimation()
        }
        .onDisappear {
            cleanUp()
        }
        .onChange(of: speechRecognizer.isRecording) { _, isRecording in
            isListening = isRecording
        }
        .onChange(of: speechRecognizer.transcript) { _, newTranscript in
            if !newTranscript.isEmpty {
                inputText = newTranscript
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("BYOLLM")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Voice")
                .font(.headline)
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.top, 50)
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !responseText.isEmpty {
                    Text(responseText)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineSpacing(6)
                    
                    // Action buttons row
                    HStack(spacing: 16) {
                        actionButton(icon: "doc.on.doc")
                        actionButton(icon: "speaker.wave.2.fill")
                        actionButton(icon: "hand.thumbsup")
                        actionButton(icon: "hand.thumbsdown")
                        actionButton(icon: "square.and.arrow.up")
                        Spacer()
                    }
                    .padding(.top, 8)
                } else if isListening {
                    HStack {
                        ListeningIndicator()
                        Text("Listening...")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if isSpeaking {
                    HStack {
                        SpeakingIndicator()
                        Text("Speaking...")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else {
                    Text("Tap the microphone to start speaking")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func actionButton(icon: String) -> some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Bottom Bar
    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Plus button
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Text input field
            HStack {
                TextField("Type", text: $inputText)
                    .font(.body)
                    .foregroundColor(.white)
                    .accentColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(22)
            
            // Camera/video button
            Button(action: {}) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // Microphone button
            Button(action: { toggleListening() }) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isListening ? .white : .white.opacity(0.6))
                    .frame(width: 44, height: 44)
                    .background(isListening ? Color.blue : Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            
            // End/Send button
            Button(action: { endOrSend() }) {
                HStack(spacing: 6) {
                    if isListening {
                        // Animated waveform
                        WaveformIndicator(isActive: true)
                            .frame(width: 20, height: 16)
                    }
                    Text(isListening ? "End" : "Send")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(Color(red: 0.3, green: 0.75, blue: 0.95))
                .cornerRadius(22)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, 30)
    }
    
    // MARK: - Actions
    private func toggleListening() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            isListening = false
        } else {
            speechRecognizer.startRecording()
            isListening = true
            responseText = ""
        }
    }
    
    private func endOrSend() {
        if isListening {
            // End recording and process
            speechRecognizer.stopRecording()
            isListening = false
            
            if !inputText.isEmpty {
                processInput()
            }
        } else if !inputText.isEmpty {
            // Send typed text
            processInput()
        }
    }
    
    private func processInput() {
        let userInput = inputText
        inputText = ""
        isSpeaking = true
        
        // TODO: Send to LLM API and get response
        // For now, simulate a response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simulate typing effect
            let simulatedResponse = "This is a simulated response. In production, this would be the actual response from your LLM, streamed in real-time with text-to-speech audio playback."
            
            typeText(simulatedResponse)
        }
    }
    
    private func typeText(_ text: String) {
        responseText = ""
        var charIndex = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if charIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: charIndex)
                responseText += String(text[index])
                charIndex += 1
            } else {
                timer.invalidate()
                isSpeaking = false
            }
        }
    }
    
    private func startWaveformAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.linear(duration: 0.05)) {
                waveformPhase += 0.1
            }
        }
    }
    
    private func cleanUp() {
        audioLevelTimer?.invalidate()
        speechRecognizer.stopRecording()
    }
}

// MARK: - Waveform Indicator
struct WaveformIndicator: View {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 2, height: barHeight(for: index))
                    .animation(.easeInOut(duration: 0.15), value: phase)
            }
        }
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let variation = sin(phase + CGFloat(index) * 0.8) * 6
        return max(4, baseHeight + variation)
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            phase += 0.5
        }
    }
}

// MARK: - Listening Indicator
struct ListeningIndicator: View {
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.blue)
            .frame(width: 12, height: 12)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    scale = 1.3
                }
            }
    }
}

// MARK: - Speaking Indicator
struct SpeakingIndicator: View {
    @State private var opacity: Double = 0.5
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .opacity(opacity)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: opacity
                    )
            }
        }
        .onAppear {
            opacity = 1.0
        }
    }
}

#Preview {
    SpeechToSpeechView()
}
