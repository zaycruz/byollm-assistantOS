//
//  OrbView3D.swift
//  byollm-assistantOS
//
//  A 3D animated orb with audio reactivity and agent state visualization
//  Inspired by ElevenLabs UI Orb component
//

import SwiftUI
import SceneKit

// MARK: - Agent State
enum AgentState: String {
    case idle
    case listening
    case thinking
    case talking
}

// MARK: - Orb Colors
struct OrbColors {
    let primary: UIColor
    let secondary: UIColor
    
    static let defaultColors = OrbColors(
        primary: UIColor(red: 0.79, green: 0.86, blue: 0.99, alpha: 1.0),  // #CADCFC
        secondary: UIColor(red: 0.63, green: 0.73, blue: 0.82, alpha: 1.0) // #A0B9D1
    )
    
    static let listening = OrbColors(
        primary: UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0),
        secondary: UIColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
    )
    
    static let thinking = OrbColors(
        primary: UIColor(red: 0.7, green: 0.5, blue: 0.9, alpha: 1.0),
        secondary: UIColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0)
    )
    
    static let talking = OrbColors(
        primary: UIColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 1.0),
        secondary: UIColor(red: 0.2, green: 0.7, blue: 0.5, alpha: 1.0)
    )
}

// MARK: - 3D Orb SceneKit View
struct Orb3DView: UIViewRepresentable {
    let agentState: AgentState
    let inputVolume: CGFloat
    let outputVolume: CGFloat
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false
        sceneView.antialiasingMode = .multisampling4X
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 4)
        scene.rootNode.addChildNode(cameraNode)
        
        // Create the orb
        let orbNode = createOrbNode()
        orbNode.name = "orb"
        scene.rootNode.addChildNode(orbNode)
        
        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 300
        ambientLight.light?.color = UIColor.white
        scene.rootNode.addChildNode(ambientLight)
        
        // Main directional light
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800
        directionalLight.light?.color = UIColor.white
        directionalLight.position = SCNVector3(x: 2, y: 3, z: 4)
        directionalLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalLight)
        
        // Rim light for depth
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.intensity = 400
        rimLight.light?.color = UIColor(white: 0.8, alpha: 1)
        rimLight.position = SCNVector3(x: -3, y: 1, z: -2)
        rimLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(rimLight)
        
        context.coordinator.sceneView = sceneView
        context.coordinator.startAnimation()
        
        return sceneView
    }
    
    func updateUIView(_ sceneView: SCNView, context: Context) {
        context.coordinator.updateState(agentState: agentState, inputVolume: inputVolume, outputVolume: outputVolume)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func createOrbNode() -> SCNNode {
        // Create a high-detail sphere
        let sphere = SCNSphere(radius: 1.0)
        sphere.segmentCount = 128
        
        // Create material with gradient-like appearance
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = OrbColors.defaultColors.primary
        material.metalness.contents = 0.1
        material.roughness.contents = 0.3
        material.fresnelExponent = 2.0
        material.isDoubleSided = false
        
        // Add subtle transparency for glass-like effect
        material.transparency = 0.95
        material.transparencyMode = .dualLayer
        
        sphere.materials = [material]
        
        let node = SCNNode(geometry: sphere)
        
        // Add inner glow sphere
        let innerSphere = SCNSphere(radius: 0.85)
        innerSphere.segmentCount = 64
        let innerMaterial = SCNMaterial()
        innerMaterial.lightingModel = .constant
        innerMaterial.diffuse.contents = OrbColors.defaultColors.secondary
        innerMaterial.transparency = 0.6
        innerSphere.materials = [innerMaterial]
        
        let innerNode = SCNNode(geometry: innerSphere)
        innerNode.name = "innerOrb"
        node.addChildNode(innerNode)
        
        // Add core glow
        let coreNode = createGlowCore()
        coreNode.name = "core"
        node.addChildNode(coreNode)
        
        return node
    }
    
    private func createGlowCore() -> SCNNode {
        let core = SCNSphere(radius: 0.3)
        core.segmentCount = 32
        
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = UIColor.white
        material.emission.contents = UIColor.white
        material.transparency = 0.8
        core.materials = [material]
        
        return SCNNode(geometry: core)
    }
    
    // MARK: - Coordinator
    class Coordinator {
        var sceneView: SCNView?
        var displayLink: CADisplayLink?
        var time: Float = 0
        var currentState: AgentState = .idle
        var currentInputVolume: CGFloat = 0
        var currentOutputVolume: CGFloat = 0
        var targetScale: Float = 1.0
        var currentScale: Float = 1.0
        
        func startAnimation() {
            displayLink = CADisplayLink(target: self, selector: #selector(updateAnimation))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        func updateState(agentState: AgentState, inputVolume: CGFloat, outputVolume: CGFloat) {
            currentState = agentState
            currentInputVolume = inputVolume
            currentOutputVolume = outputVolume
            
            // Update colors based on state
            updateColors(for: agentState)
        }
        
        private func updateColors(for state: AgentState) {
            guard let orbNode = sceneView?.scene?.rootNode.childNode(withName: "orb", recursively: false),
                  let innerNode = orbNode.childNode(withName: "innerOrb", recursively: false) else { return }
            
            let colors: OrbColors
            switch state {
            case .idle:
                colors = .defaultColors
            case .listening:
                colors = .listening
            case .thinking:
                colors = .thinking
            case .talking:
                colors = .talking
            }
            
            // Animate color transition
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5
            
            orbNode.geometry?.firstMaterial?.diffuse.contents = colors.primary
            innerNode.geometry?.firstMaterial?.diffuse.contents = colors.secondary
            
            SCNTransaction.commit()
        }
        
        @objc func updateAnimation() {
            time += 0.016 // ~60fps
            
            guard let orbNode = sceneView?.scene?.rootNode.childNode(withName: "orb", recursively: false),
                  let innerNode = orbNode.childNode(withName: "innerOrb", recursively: false),
                  let coreNode = orbNode.childNode(withName: "core", recursively: false) else { return }
            
            // Calculate target scale based on state and volume
            let volumeInfluence: Float
            switch currentState {
            case .idle:
                volumeInfluence = 0
                targetScale = 1.0
            case .listening:
                volumeInfluence = Float(currentInputVolume) * 0.3
                targetScale = 1.0 + volumeInfluence
            case .thinking:
                volumeInfluence = 0
                // Pulsing effect for thinking
                targetScale = 1.0 + sin(time * 3) * 0.05
            case .talking:
                volumeInfluence = Float(currentOutputVolume) * 0.25
                targetScale = 1.0 + volumeInfluence
            }
            
            // Smooth scale interpolation
            currentScale += (targetScale - currentScale) * 0.15
            
            // Apply organic deformation based on state
            let deformAmount: Float
            let deformSpeed: Float
            
            switch currentState {
            case .idle:
                deformAmount = 0.02
                deformSpeed = 0.5
            case .listening:
                deformAmount = 0.05 + Float(currentInputVolume) * 0.1
                deformSpeed = 2.0
            case .thinking:
                deformAmount = 0.08
                deformSpeed = 1.5
            case .talking:
                deformAmount = 0.06 + Float(currentOutputVolume) * 0.15
                deformSpeed = 3.0
            }
            
            // Apply scale with organic wobble
            let wobbleX = 1.0 + sin(time * deformSpeed) * deformAmount
            let wobbleY = 1.0 + sin(time * deformSpeed * 1.3 + 1) * deformAmount
            let wobbleZ = 1.0 + sin(time * deformSpeed * 0.7 + 2) * deformAmount
            
            orbNode.scale = SCNVector3(
                currentScale * wobbleX,
                currentScale * wobbleY,
                currentScale * wobbleZ
            )
            
            // Subtle rotation for fluid look
            orbNode.eulerAngles.y = time * 0.1
            orbNode.eulerAngles.x = sin(time * 0.3) * 0.1
            
            // Inner orb counter-rotation
            innerNode.eulerAngles.y = -time * 0.15
            innerNode.eulerAngles.z = cos(time * 0.2) * 0.1
            
            // Core pulsing
            let corePulse = 1.0 + sin(time * 2) * 0.2
            coreNode.scale = SCNVector3(corePulse, corePulse, corePulse)
            
            // Update core brightness based on state
            let coreIntensity: CGFloat
            switch currentState {
            case .idle: coreIntensity = 0.6
            case .listening: coreIntensity = 0.8 + currentInputVolume * 0.2
            case .thinking: coreIntensity = 0.7 + CGFloat(sin(time * 4)) * 0.2
            case .talking: coreIntensity = 0.9 + currentOutputVolume * 0.1
            }
            
            coreNode.geometry?.firstMaterial?.transparency = coreIntensity
        }
        
        deinit {
            displayLink?.invalidate()
        }
    }
}

// MARK: - SwiftUI Wrapper
struct AnimatedOrb: View {
    let agentState: AgentState
    var inputVolume: CGFloat = 0
    var outputVolume: CGFloat = 0
    var size: CGFloat = 200
    
    var body: some View {
        ZStack {
            // Outer glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: size * 0.3,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .blur(radius: 20)
            
            // 3D Orb
            Orb3DView(
                agentState: agentState,
                inputVolume: inputVolume,
                outputVolume: outputVolume
            )
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
    
    private var glowColor: Color {
        switch agentState {
        case .idle: return Color(red: 0.79, green: 0.86, blue: 0.99)
        case .listening: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .thinking: return Color(red: 0.7, green: 0.5, blue: 0.9)
        case .talking: return Color(red: 0.4, green: 0.9, blue: 0.6)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AnimatedOrb(agentState: .listening, inputVolume: 0.5)
    }
}
