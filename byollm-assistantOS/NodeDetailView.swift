//
//  NodeDetailView.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//

import SwiftUI

struct NodeDetailView: View {
    @ObservedObject var manager: ARISEManager
    let node: SkillNode
    let tree: SkillTree
    @State private var completionNotes: String = ""
    @State private var checkedCriteria: Set<Int> = []
    @State private var showingCompletionAlert = false
    @State private var showingXPAnimation = false
    @Environment(\.dismiss) var dismiss
    
    private var allCriteriaChecked: Bool {
        checkedCriteria.count == node.completionCriteria.count && !node.completionCriteria.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        statusHeader
                        detailsSection
                        
                        if !node.completionCriteria.isEmpty {
                            criteriaSection
                        }
                        
                        if node.status == .available || node.status == .inProgress {
                            actionButtons
                        }
                        
                        if node.status == .inProgress || (node.status == .available && allCriteriaChecked) {
                            notesSection
                        }
                        
                        if node.status == .completed {
                            completedSection
                        }
                    }
                    .padding(20)
                }
                
                if showingXPAnimation {
                    xpAnimationOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Quest Details")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var statusHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(statusGradient)
                    .frame(width: 80, height: 80)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(node.title)
                .font(.title2.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Label("\(Int(node.estimatedHours))h", systemImage: "clock")
                Label("\(node.xpValue) XP", systemImage: "sparkle")
                Text("Tier \(node.tier)")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .cornerRadius(6)
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            if !node.linkedStats.isEmpty {
                HStack(spacing: 8) {
                    Text("Stats:")
                        .foregroundColor(.gray)
                    ForEach(node.linkedStats, id: \.self) { stat in
                        Text(stat)
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(6)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var statusGradient: LinearGradient {
        switch node.status {
        case .locked:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .available:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .inProgress:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .completed:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var statusIcon: String {
        switch node.status {
        case .locked: return "lock.fill"
        case .available: return "star.fill"
        case .inProgress: return "play.fill"
        case .completed: return "checkmark"
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .foregroundColor(.white)
            
            Text(node.description.isEmpty ? "Complete this quest to progress in your skill tree." : node.description)
                .font(.body)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var criteriaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Completion Criteria")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(checkedCriteria.count)/\(node.completionCriteria.count)")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
            
            ForEach(Array(node.completionCriteria.enumerated()), id: \.offset) { index, criterion in
                Button(action: {
                    if node.status != .completed && node.status != .locked {
                        if checkedCriteria.contains(index) {
                            checkedCriteria.remove(index)
                        } else {
                            checkedCriteria.insert(index)
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: checkedCriteria.contains(index) || node.status == .completed ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(checkedCriteria.contains(index) || node.status == .completed ? .green : .gray)
                            .font(.title3)
                        
                        Text(criterion)
                            .font(.subheadline)
                            .foregroundColor(checkedCriteria.contains(index) || node.status == .completed ? .white : .gray)
                            .strikethrough(checkedCriteria.contains(index) || node.status == .completed)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(node.status == .completed || node.status == .locked)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if node.status == .available {
                Button(action: startQuest) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Quest")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            
            if node.status == .inProgress || allCriteriaChecked {
                Button(action: { showingCompletionAlert = true }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Quest")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .alert("Complete Quest?", isPresented: $showingCompletionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Complete") {
                completeQuest()
            }
        } message: {
            Text("You will earn \(node.xpValue) XP for completing this quest.")
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completion Notes (Optional)")
                .font(.headline)
                .foregroundColor(.white)
            
            TextEditor(text: $completionNotes)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            
            Text("Notes help the AI generate better follow-up quests")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("Quest Completed")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            if let completedAt = node.completedAt {
                Text("Completed on \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            if let notes = node.completionNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var xpAnimationOverlay: some View {
        VStack {
            Text("+\(node.xpValue) XP")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .yellow.opacity(0.5), radius: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
        .transition(.opacity)
    }
    
    private func startQuest() {
        manager.startNode(nodeId: node.id, in: tree.id)
        dismiss()
    }
    
    private func completeQuest() {
        showingXPAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            manager.completeNode(
                nodeId: node.id,
                in: tree.id,
                notes: completionNotes.isEmpty ? nil : completionNotes
            )
            showingXPAnimation = false
            dismiss()
        }
    }
}

#Preview {
    let node = SkillNode(
        title: "Research & Planning",
        description: "Define scope and research requirements for the project",
        tier: 1,
        completionCriteria: ["Document requirements", "Create initial roadmap", "Review with stakeholders"],
        estimatedHours: 3,
        xpValue: 100,
        status: .available,
        linkedStats: ["INT", "WIS"]
    )
    
    return NodeDetailView(
        manager: ARISEManager(),
        node: node,
        tree: SkillTree(goalId: UUID(), title: "Test")
    )
}
