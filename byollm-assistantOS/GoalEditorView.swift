//
//  GoalEditorView.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//

import SwiftUI

struct GoalEditorView: View {
    @ObservedObject var manager: ARISEManager
    @State private var title: String
    @State private var description: String
    @State private var timeframe: Timeframe
    @State private var targetDate: Date
    @State private var hasTargetDate: Bool
    @State private var showingDeleteAlert = false
    @State private var isGenerating = false
    @Environment(\.dismiss) var dismiss
    
    private let goal: Goal?
    private let isNewGoal: Bool
    
    init(manager: ARISEManager, goal: Goal?) {
        self.manager = manager
        self.goal = goal
        self.isNewGoal = goal == nil
        
        _title = State(initialValue: goal?.title ?? "")
        _description = State(initialValue: goal?.description ?? "")
        _timeframe = State(initialValue: goal?.timeframe ?? .quarterly)
        _targetDate = State(initialValue: goal?.targetDate ?? Date().addingTimeInterval(90 * 24 * 60 * 60))
        _hasTargetDate = State(initialValue: goal?.targetDate != nil)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        titleSection
                        descriptionSection
                        timeframeSection
                        targetDateSection
                        
                        if !isNewGoal {
                            if goal?.treeId == nil {
                                generateTreeButton
                            }
                            deleteButton
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .principal) {
                    Text(isNewGoal ? "New Goal" : "Edit Goal")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                    }
                    .foregroundColor(.purple)
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete Goal", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let goal = goal {
                        manager.deleteGoal(goal)
                    }
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this goal? This will also delete its skill tree.")
            }
        }
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goal Title")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            TextField("What do you want to achieve?", text: $title)
                .font(.body)
                .foregroundColor(.white)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            TextEditor(text: $description)
                .font(.body)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }
    
    private var timeframeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeframe")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack(spacing: 12) {
                ForEach(Timeframe.allCases, id: \.self) { tf in
                    Button(action: { timeframe = tf }) {
                        Text(tf.displayName)
                            .font(.subheadline)
                            .foregroundColor(timeframe == tf ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(timeframe == tf ? Color.purple : Color.white.opacity(0.05))
                            )
                    }
                }
            }
        }
    }
    
    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $hasTargetDate) {
                Text("Target Date")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .tint(.purple)
            
            if hasTargetDate {
                DatePicker(
                    "Target Date",
                    selection: $targetDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .colorScheme(.dark)
                .tint(.purple)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }
    
    private var generateTreeButton: some View {
        Button(action: generateTree) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(isGenerating ? "Generating..." : "Generate Skill Tree")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isGenerating)
    }
    
    private var deleteButton: some View {
        Button(action: { showingDeleteAlert = true }) {
            HStack {
                Image(systemName: "trash")
                Text("Delete Goal")
            }
            .font(.subheadline)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
            )
        }
    }
    
    private func saveGoal() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        if let existingGoal = goal {
            var updatedGoal = existingGoal
            updatedGoal.title = trimmedTitle
            updatedGoal.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedGoal.timeframe = timeframe
            updatedGoal.targetDate = hasTargetDate ? targetDate : nil
            manager.updateGoal(updatedGoal)
        } else {
            let newGoal = Goal(
                title: trimmedTitle,
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                timeframe: timeframe,
                targetDate: hasTargetDate ? targetDate : nil
            )
            manager.addGoal(newGoal)
            
            manager.createDemoTree(for: newGoal)
        }
        
        dismiss()
    }
    
    private func generateTree() {
        guard let goal = goal else { return }
        
        isGenerating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            manager.createDemoTree(for: goal)
            isGenerating = false
            dismiss()
        }
    }
}

#Preview {
    GoalEditorView(manager: ARISEManager(), goal: nil)
}
