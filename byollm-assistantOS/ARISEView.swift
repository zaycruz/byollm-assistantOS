//
//  ARISEView.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//

import SwiftUI

struct ARISEView: View {
    @StateObject private var manager = ARISEManager()
    @State private var showingGoalEditor = false
    @State private var showingContextImport = false
    @State private var showingStats = false
    @State private var selectedGoal: Goal?
    @State private var selectedTree: SkillTree?
    @Environment(\.dismiss) var dismiss
    
    var isInSidePanel: Bool = false
    var onBack: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        statsCard
                        
                        if !manager.allAvailableNodes.isEmpty {
                            availableNodesSection
                        }
                        
                        goalsSection
                        
                        if !manager.contextSources.isEmpty {
                            contextSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 100)
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addButton
                }
            }
        }
        .sheet(isPresented: $showingGoalEditor) {
            GoalEditorView(manager: manager, goal: nil)
        }
        .sheet(isPresented: $showingContextImport) {
            ContextImportView(manager: manager)
        }
        .sheet(isPresented: $showingStats) {
            ARISEStatsView(stats: manager.stats)
        }
        .sheet(item: $selectedGoal) { goal in
            if let tree = manager.tree(for: goal.id) {
                SkillTreeView(manager: manager, tree: tree, goal: goal)
            } else {
                GoalEditorView(manager: manager, goal: goal)
            }
        }
    }
    
    private var headerView: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.2), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            HStack(spacing: 16) {
                if isInSidePanel {
                    Button(action: { onBack?() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Back")
                        }
                        .foregroundStyle(.purple)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("ARISE")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Level \(manager.stats.level) - \(manager.stats.totalXP) XP")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: {
                    if isInSidePanel {
                        onDismiss?()
                    } else {
                        dismiss()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(height: 80)
    }
    
    private var statsCard: some View {
        Button(action: { showingStats = true }) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(manager.stats.level)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    ProgressView(value: manager.stats.xpProgress, total: 100)
                        .tint(.purple)
                    
                    Text("\(Int(manager.stats.xpProgress))% to Level \(manager.stats.level + 1)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    HStack(spacing: 16) {
                        statBadge("STR", value: manager.stats.str)
                        statBadge("INT", value: manager.stats.int)
                        statBadge("WIS", value: manager.stats.wis)
                    }
                    HStack(spacing: 16) {
                        statBadge("DEX", value: manager.stats.dex)
                        statBadge("CHA", value: manager.stats.cha)
                        statBadge("VIT", value: manager.stats.vit)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.purple.opacity(0.5), .pink.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func statBadge(_ name: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.caption.bold())
                .foregroundColor(.white)
            Text(name)
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .frame(width: 32)
    }
    
    private var availableNodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("Available Quests")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            ForEach(manager.allAvailableNodes.prefix(3), id: \.node.id) { item in
                availableNodeCard(node: item.node, tree: item.tree)
            }
        }
    }
    
    private func availableNodeCard(node: SkillNode, tree: SkillTree) -> some View {
        Button(action: {
            if let goal = manager.goals.first(where: { $0.id == tree.goalId }) {
                selectedGoal = goal
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.3), .yellow.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Label("\(Int(node.estimatedHours))h", systemImage: "clock")
                        Label("\(node.xpValue) XP", systemImage: "sparkle")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.purple)
                Text("Goals")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Button(action: { showingGoalEditor = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                }
            }
            
            if manager.activeGoals.isEmpty {
                emptyGoalsCard
            } else {
                ForEach(manager.activeGoals) { goal in
                    goalCard(goal)
                }
            }
        }
    }
    
    private var emptyGoalsCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .pink.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("No Goals Yet")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Create your first goal to generate a skill tree")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button(action: { showingGoalEditor = true }) {
                Text("Create Goal")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    private func goalCard(_ goal: Goal) -> some View {
        Button(action: { selectedGoal = goal }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(goal.timeframe.displayName)
                        .font(.caption)
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(6)
                }
                
                if !goal.description.isEmpty {
                    Text(goal.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                if let tree = manager.tree(for: goal.id) {
                    HStack {
                        ProgressView(value: tree.progressPercentage, total: 100)
                            .tint(.purple)
                        
                        Text("\(Int(tree.progressPercentage))%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(tree.completedNodes.count)/\(tree.allNodes.count)", systemImage: "checkmark.circle")
                        Label("\(tree.availableNodes.count) available", systemImage: "sparkles")
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                } else {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Tap to generate skill tree")
                    }
                    .font(.caption)
                    .foregroundColor(.purple)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.cyan)
                Text("Context Sources")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Button(action: { showingContextImport = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.cyan)
                }
            }
            
            Text("\(manager.contextSources.count) sources ingested")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var addButton: some View {
        Menu {
            Button(action: { showingGoalEditor = true }) {
                Label("New Goal", systemImage: "target")
            }
            
            Button(action: { showingContextImport = true }) {
                Label("Add Context", systemImage: "brain.head.profile")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.purple.opacity(0.6), .purple.opacity(0)],
                            center: .center,
                            startRadius: 28,
                            endRadius: 45
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: .purple.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 28)
        .padding(.bottom, 28)
    }
}

#Preview {
    ARISEView()
}
