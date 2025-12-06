//
//  SkillTreeView.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//

import SwiftUI

struct SkillTreeView: View {
    @ObservedObject var manager: ARISEManager
    let tree: SkillTree
    let goal: Goal
    @State private var selectedNode: SkillNode?
    @State private var selectedBranchIndex: Int = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    progressBar
                    
                    if tree.branches.count > 1 {
                        branchTabs
                    }
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            if selectedBranchIndex < tree.branches.count {
                                branchView(tree.branches[selectedBranchIndex])
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .sheet(item: $selectedNode) { node in
                NodeDetailView(
                    manager: manager,
                    node: node,
                    tree: tree
                )
            }
            .navigationBarHidden(true)
        }
    }
    
    private var headerView: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            
            HStack {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Back")
                    }
                    .foregroundColor(.purple)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(tree.completedNodes.count)/\(tree.allNodes.count) completed")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 60)
    }
    
    private var progressBar: some View {
        VStack(spacing: 8) {
            ProgressView(value: tree.progressPercentage, total: 100)
                .tint(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            HStack {
                Text("\(Int(tree.progressPercentage))% Complete")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(tree.availableNodes.count) available")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
    }
    
    private var branchTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(tree.branches.enumerated()), id: \.element.id) { index, branch in
                    Button(action: { selectedBranchIndex = index }) {
                        VStack(spacing: 4) {
                            Text(branch.name)
                                .font(.subheadline)
                                .foregroundColor(selectedBranchIndex == index ? .white : .gray)
                            
                            Text("\(branch.completedCount)/\(branch.nodes.count)")
                                .font(.caption)
                                .foregroundColor(selectedBranchIndex == index ? .purple : .gray.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedBranchIndex == index ? Color.purple.opacity(0.2) : Color.clear)
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
    
    private func branchView(_ branch: Branch) -> some View {
        let nodesByTier = Dictionary(grouping: branch.nodes) { $0.tier }
        let sortedTiers = nodesByTier.keys.sorted()
        
        return VStack(spacing: 0) {
            ForEach(sortedTiers, id: \.self) { tier in
                VStack(spacing: 16) {
                    HStack {
                        Text("Tier \(tier)")
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                        
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.bottom, 8)
                    
                    let nodes = nodesByTier[tier] ?? []
                    ForEach(nodes) { node in
                        nodeCard(node)
                    }
                }
                .padding(.bottom, 32)
                
                if tier < sortedTiers.last ?? 0 {
                    tierConnector
                }
            }
        }
    }
    
    private var tierConnector: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .purple.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 40)
            
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.purple.opacity(0.5))
        }
        .padding(.bottom, 16)
    }
    
    private func nodeCard(_ node: SkillNode) -> some View {
        Button(action: { selectedNode = node }) {
            HStack(spacing: 16) {
                nodeStatusIcon(node.status)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(node.title)
                        .font(.subheadline.bold())
                        .foregroundColor(nodeTextColor(node.status))
                        .lineLimit(2)
                    
                    if !node.description.isEmpty {
                        Text(node.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(Int(node.estimatedHours))h", systemImage: "clock")
                        Label("\(node.xpValue) XP", systemImage: "sparkle")
                        
                        if !node.linkedStats.isEmpty {
                            Text(node.linkedStats.joined(separator: ", "))
                                .foregroundColor(.cyan)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(16)
            .background(nodeBackground(node.status))
            .overlay(nodeOverlay(node.status))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .opacity(node.status == .locked ? 0.6 : 1.0)
    }
    
    private func nodeStatusIcon(_ status: NodeStatus) -> some View {
        ZStack {
            Circle()
                .fill(nodeIconBackground(status))
                .frame(width: 44, height: 44)
            
            Image(systemName: nodeIconName(status))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(nodeIconColor(status))
        }
    }
    
    private func nodeIconName(_ status: NodeStatus) -> String {
        switch status {
        case .locked: return "lock.fill"
        case .available: return "star.fill"
        case .inProgress: return "play.fill"
        case .completed: return "checkmark"
        }
    }
    
    private func nodeIconColor(_ status: NodeStatus) -> Color {
        switch status {
        case .locked: return .gray
        case .available: return .yellow
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
    
    private func nodeIconBackground(_ status: NodeStatus) -> Color {
        switch status {
        case .locked: return .gray.opacity(0.2)
        case .available: return .yellow.opacity(0.2)
        case .inProgress: return .blue.opacity(0.2)
        case .completed: return .green.opacity(0.2)
        }
    }
    
    private func nodeTextColor(_ status: NodeStatus) -> Color {
        switch status {
        case .locked: return .gray
        case .available, .inProgress, .completed: return .white
        }
    }
    
    private func nodeBackground(_ status: NodeStatus) -> some ShapeStyle {
        Color.white.opacity(0.05)
    }
    
    @ViewBuilder
    private func nodeOverlay(_ status: NodeStatus) -> some View {
        switch status {
        case .available:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        case .inProgress:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
        case .completed:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        case .locked:
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
        }
    }
}

#Preview {
    let manager = ARISEManager()
    let goal = Goal(title: "Test Goal", description: "A test goal")
    manager.addGoal(goal)
    manager.createDemoTree(for: goal)
    
    return SkillTreeView(
        manager: manager,
        tree: manager.trees.first!,
        goal: goal
    )
}
