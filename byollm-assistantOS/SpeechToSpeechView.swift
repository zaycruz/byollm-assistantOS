//
//  SpeechToSpeechView.swift
//  byollm-assistantOS
//
//  Created by master on 12/22/25.
//

import SwiftUI

enum S2SState {
    case idle
    case listening
    case processing
    case speaking
}

struct SpeechToSpeechView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var s2sState: S2SState = .idle
    @State private var audioLevel: CGFloat = 0.3
    @State private var statusText: String = "Tap to speak"
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Close button
                HStack {
                    Button(action: { 
                        speechRecognizer.stopRecording()
                        dismiss() 
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // Orb
                OrbView(state: $s2sState, audioLevel: $audioLevel)
                    .frame(width: 280, height: 280)
                    .onTapGesture {
                        toggleListening()
                    }
                
                // Status text
                Text(statusText)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.7))
                    .animation(.easeInOut, value: statusText)
                
                Spacer()
                
                // Transcript preview (if listening)
                if s2sState == .listening && !speechRecognizer.transcript.isEmpty {
                    Text(speechRecognizer.transcript)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .lineLimit(3)
                        .transition(.opacity)
                }
                
                // Bottom controls
                HStack(spacing: 60) {
                    // End call button
                    Button(action: { 
                        speechRecognizer.stopRecording()
                        dismiss() 
                    }) {
                        Image(systemName: "phone.down.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onChange(of: speechRecognizer.isRecording) { _, isRecording in
            if isRecording {
                s2sState = .listening
                statusText = "Listening..."
            } else if s2sState == .listening {
                s2sState = .idle
                statusText = "Tap to speak"
            }
        }
        .onChange(of: speechRecognizer.transcript) { _, newTranscript in
            // Simulate audio level based on transcript changes
            if !newTranscript.isEmpty {
                withAnimation(.easeInOut(duration: 0.1)) {
                    audioLevel = CGFloat.random(in: 0.4...0.9)
                }
            }
        }
    }
    
    private func toggleListening() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            
            // Process the transcript
            if !speechRecognizer.transcript.isEmpty {
                s2sState = .processing
                statusText = "Processing..."
                
                // TODO: Send to LLM and get audio response
                // For now, simulate processing then speaking
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    s2sState = .speaking
                    statusText = "Speaking..."
                    
                    // Simulate speaking duration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        s2sState = .idle
                        statusText = "Tap to speak"
                    }
                }
            } else {
                s2sState = .idle
                statusText = "Tap to speak"
            }
        } else {
            speechRecognizer.startRecording()
        }
    }
}

// MARK: - Orb View
struct OrbView: View {
    @Binding var state: S2SState
    @Binding var audioLevel: CGFloat
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var innerGlow: CGFloat = 0.5
    
    private var orbColor: Color {
        switch state {
        case .idle: return .white
        case .listening: return .blue
        case .processing: return .purple
        case .speaking: return .green
        }
    }
    
    private var glowIntensity: CGFloat {
        switch state {
        case .idle: return 0.3
        case .listening: return 0.5 + (audioLevel * 0.3)
        case .processing: return 0.6
        case .speaking: return 0.7
        }
    }
    
    var body: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(orbColor.opacity(0.1 - Double(index) * 0.03), lineWidth: 2)
                    .scaleEffect(pulseScale + CGFloat(index) * 0.15)
                    .animation(
                        Animation
                            .easeInOut(duration: state == .idle ? 2.0 : 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: pulseScale
                    )
            }
            
            // Audio reactive rings (only when listening)
            if state == .listening {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(orbColor.opacity(0.15), lineWidth: 1.5)
                        .scaleEffect(1.0 + (audioLevel * CGFloat(index + 1) * 0.15))
                        .animation(.easeOut(duration: 0.15), value: audioLevel)
                }
            }
            
            // Processing rotation ring
            if state == .processing {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(
                            colors: [orbColor.opacity(0), orbColor],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotation))
                    .scaleEffect(1.1)
            }
            
            // Main orb gradient
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            orbColor.opacity(innerGlow),
                            orbColor.opacity(0.3),
                            orbColor.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .scaleEffect(state == .listening ? (0.95 + audioLevel * 0.15) : 1.0)
                .animation(.easeOut(duration: 0.1), value: audioLevel)
            
            // Inner core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.9),
                            orbColor.opacity(0.8),
                            orbColor.opacity(0.4)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(state == .listening ? (0.9 + audioLevel * 0.2) : 1.0)
                .animation(.easeOut(duration: 0.1), value: audioLevel)
                .shadow(color: orbColor.opacity(0.5), radius: 30, x: 0, y: 0)
            
            // Speaking waves
            if state == .speaking {
                ForEach(0..<6, id: \.self) { index in
                    SpeakingWave(index: index, color: orbColor)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: state) { _, _ in
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Pulse animation
        withAnimation(.easeInOut(duration: state == .idle ? 2.0 : 0.8).repeatForever(autoreverses: true)) {
            pulseScale = state == .idle ? 1.05 : 1.1
        }
        
        // Inner glow animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            innerGlow = state == .idle ? 0.6 : 0.8
        }
        
        // Rotation for processing
        if state == .processing {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        } else {
            rotation = 0
        }
    }
}

// MARK: - Speaking Wave
struct SpeakingWave: View {
    let index: Int
    let color: Color
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Circle()
            .stroke(color.opacity(opacity), lineWidth: 2)
            .scaleEffect(scale)
            .onAppear {
                let delay = Double(index) * 0.15
                withAnimation(
                    Animation
                        .easeOut(duration: 1.2)
                        .repeatForever(autoreverses: false)
                        .delay(delay)
                ) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}

#Preview {
    SpeechToSpeechView()
}
