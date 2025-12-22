//
//  EtherealOrb.swift
//  byollm-assistantOS
//
//  An ethereal, fluid orb representing intelligence and presence
//  Inspired by the soul-like quality of the ElevenLabs orb
//

import SwiftUI

// MARK: - Ethereal Orb
struct EtherealOrb: View {
    let agentState: AgentState
    var inputVolume: CGFloat = 0
    var outputVolume: CGFloat = 0
    var size: CGFloat = 240
    
    @State private var phase: CGFloat = 0
    @State private var breathe: CGFloat = 1.0
    @State private var innerRotation: Double = 0
    @State private var outerRotation: Double = 0
    @State private var pulse: CGFloat = 0
    
    private var activeVolume: CGFloat {
        switch agentState {
        case .listening: return inputVolume
        case .talking: return outputVolume
        default: return 0
        }
    }
    
    private var primaryColor: Color {
        switch agentState {
        case .idle: return Color(red: 0.75, green: 0.82, blue: 0.95)
        case .listening: return Color(red: 0.55, green: 0.70, blue: 1.0)
        case .thinking: return Color(red: 0.70, green: 0.55, blue: 0.95)
        case .talking: return Color(red: 0.50, green: 0.90, blue: 0.70)
        }
    }
    
    private var secondaryColor: Color {
        switch agentState {
        case .idle: return Color(red: 0.85, green: 0.88, blue: 0.98)
        case .listening: return Color(red: 0.70, green: 0.85, blue: 1.0)
        case .thinking: return Color(red: 0.85, green: 0.70, blue: 1.0)
        case .talking: return Color(red: 0.70, green: 0.95, blue: 0.80)
        }
    }
    
    private var accentColor: Color {
        switch agentState {
        case .idle: return Color(red: 0.90, green: 0.92, blue: 1.0)
        case .listening: return Color(red: 0.80, green: 0.90, blue: 1.0)
        case .thinking: return Color(red: 0.90, green: 0.80, blue: 1.0)
        case .talking: return Color(red: 0.85, green: 1.0, blue: 0.90)
        }
    }
    
    var body: some View {
        ZStack {
            // Ambient glow
            ambientGlow
            
            // Main orb layers
            orbLayers
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .onAppear { startAnimations() }
        .onChange(of: agentState) { _, _ in startAnimations() }
    }
    
    // MARK: - Ambient Glow
    private var ambientGlow: some View {
        ZStack {
            // Outer halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            primaryColor.opacity(0.15 + activeVolume * 0.1),
                            primaryColor.opacity(0.05),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.75
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 30)
                .scaleEffect(breathe + activeVolume * 0.15)
            
            // Pulsing ring
            if agentState == .listening || agentState == .talking {
                Circle()
                    .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                    .frame(width: size * (1.0 + pulse * 0.3), height: size * (1.0 + pulse * 0.3))
                    .opacity(1 - pulse)
            }
        }
    }
    
    // MARK: - Orb Layers
    private var orbLayers: some View {
        ZStack {
            // Layer 1: Deep base
            FluidBlob(
                color1: primaryColor.opacity(0.6),
                color2: secondaryColor.opacity(0.4),
                phase: phase,
                complexity: 6,
                amplitude: 0.08 + activeVolume * 0.05
            )
            .frame(width: size * 0.95, height: size * 0.95)
            .rotationEffect(.degrees(outerRotation))
            .blur(radius: 2)
            
            // Layer 2: Mid layer with more movement
            FluidBlob(
                color1: secondaryColor.opacity(0.7),
                color2: accentColor.opacity(0.5),
                phase: phase * 1.3,
                complexity: 5,
                amplitude: 0.1 + activeVolume * 0.08
            )
            .frame(width: size * 0.8, height: size * 0.8)
            .rotationEffect(.degrees(-innerRotation * 0.7))
            .blur(radius: 1)
            
            // Layer 3: Bright inner core
            FluidBlob(
                color1: accentColor.opacity(0.9),
                color2: .white.opacity(0.7),
                phase: phase * 1.6,
                complexity: 4,
                amplitude: 0.06 + activeVolume * 0.1
            )
            .frame(width: size * 0.55, height: size * 0.55)
            .rotationEffect(.degrees(innerRotation))
            
            // Layer 4: Core highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.95),
                            .white.opacity(0.6),
                            accentColor.opacity(0.3),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
                .frame(width: size * 0.4, height: size * 0.4)
                .scaleEffect(0.9 + activeVolume * 0.15)
                .blur(radius: 8)
            
            // Specular highlight
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.6), .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.25, height: size * 0.12)
                .offset(y: -size * 0.18)
                .blur(radius: 4)
        }
        .scaleEffect(breathe + activeVolume * 0.1)
    }
    
    // MARK: - Animations
    private func startAnimations() {
        let baseSpeed: Double
        let breatheDuration: Double
        
        switch agentState {
        case .idle:
            baseSpeed = 20
            breatheDuration = 4
        case .listening:
            baseSpeed = 12
            breatheDuration = 2
        case .thinking:
            baseSpeed = 8
            breatheDuration = 1.5
        case .talking:
            baseSpeed = 10
            breatheDuration = 1.8
        }
        
        // Phase animation (drives fluid movement)
        withAnimation(.linear(duration: baseSpeed).repeatForever(autoreverses: false)) {
            phase = 1
        }
        
        // Breathing animation
        withAnimation(.easeInOut(duration: breatheDuration).repeatForever(autoreverses: true)) {
            breathe = agentState == .idle ? 1.02 : 1.05
        }
        
        // Rotation animations
        withAnimation(.linear(duration: baseSpeed * 2).repeatForever(autoreverses: false)) {
            innerRotation = 360
        }
        
        withAnimation(.linear(duration: baseSpeed * 3).repeatForever(autoreverses: false)) {
            outerRotation = 360
        }
        
        // Pulse animation for active states
        if agentState == .listening || agentState == .talking {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse = 1
            }
        } else {
            pulse = 0
        }
    }
}

// MARK: - Fluid Blob Shape
struct FluidBlob: View {
    let color1: Color
    let color2: Color
    let phase: CGFloat
    let complexity: Int
    let amplitude: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            
            Canvas { context, size in
                let path = createBlobPath(center: center, radius: radius)
                
                // Create gradient
                let gradient = Gradient(colors: [color1, color2])
                let shading = GraphicsContext.Shading.radialGradient(
                    gradient,
                    center: CGPoint(x: center.x * 0.9, y: center.y * 0.9),
                    startRadius: 0,
                    endRadius: radius
                )
                
                context.fill(path, with: shading)
            }
        }
    }
    
    private func createBlobPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let points = 60
        
        for i in 0...points {
            let angle = (CGFloat(i) / CGFloat(points)) * 2 * .pi
            
            // Create organic noise using multiple sine waves
            var noise: CGFloat = 0
            for j in 1...complexity {
                let freq = CGFloat(j)
                let phaseOffset = phase * .pi * 2 * freq
                noise += sin(angle * freq + phaseOffset) / freq
            }
            noise *= amplitude
            
            let r = radius * (1 + noise)
            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 40) {
            EtherealOrb(agentState: .idle, size: 180)
            
            HStack(spacing: 20) {
                EtherealOrb(agentState: .listening, inputVolume: 0.5, size: 100)
                EtherealOrb(agentState: .thinking, size: 100)
                EtherealOrb(agentState: .talking, outputVolume: 0.6, size: 100)
            }
        }
    }
}
