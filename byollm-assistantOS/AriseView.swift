import SwiftUI
import SwiftData
import UIKit

// NOTE:
// This file hosts the Level Up feature views within the Arise tab.
// Uses the unified DesignSystem for visual consistency with the rest of the app.

// MARK: - Root Entry Point

struct AriseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [LevelUpGoal]
    @Query private var userProgressList: [LevelUpUserProgress]
    
    private var activeGoals: [LevelUpGoal] {
        allGoals.filter { $0.status == .active }
    }
    
    private var pinnedGoals: [LevelUpGoal] {
        LevelUpGoalPinning.pinnedGoals(from: activeGoals)
    }
    
    @State private var selectedPinnedIndex: Int = 0
    @State private var showGoalCreation = false
    @State private var showAddContext = false
    @State private var showProgress = false
    @State private var showSettings = false
    @State private var selectedObjective: LevelUpObjective?
    @State private var isSyncing = false
    @State private var syncError: String?
    
    private var userProgress: LevelUpUserProgress? { userProgressList.first }
    
    private var currentGoal: LevelUpGoal? {
        guard !pinnedGoals.isEmpty else { return nil }
        let safeIndex = min(selectedPinnedIndex, pinnedGoals.count - 1)
        return pinnedGoals[max(0, safeIndex)]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bg.ignoresSafeArea()
                
                if pinnedGoals.isEmpty && activeGoals.isEmpty {
                    AriseEmptyStateView(onCreateGoal: { showGoalCreation = true })
                } else if let goal = currentGoal {
                    VStack(spacing: 0) {
                        // Goal switcher when multiple pinned
                        if pinnedGoals.count > 1 {
                            AriseGoalSwitcher(
                                goals: pinnedGoals,
                                selectedIndex: $selectedPinnedIndex
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        
                        ArisePathView(
                            goal: goal,
                            userProgress: userProgress,
                            onObjectiveTapped: { selectedObjective = $0 },
                            onAddContext: { showAddContext = true },
                            onShowProgress: { showProgress = true },
                            onShowSettings: { showSettings = true }
                        )
                    }
                } else {
                    // Have active goals but none pinned - auto-pin
                    AriseEmptyStateView(onCreateGoal: { showGoalCreation = true })
                        .onAppear {
                            autoPinIfNeeded()
                        }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showGoalCreation) {
                AriseGoalCreationView(onDismiss: { showGoalCreation = false })
            }
            .sheet(isPresented: $showAddContext) {
                AriseContextSheet(onDismiss: { showAddContext = false })
            }
            .sheet(isPresented: $showProgress) {
                AriseProgressSheet(onDismiss: { showProgress = false })
            }
            .sheet(isPresented: $showSettings) {
                AriseSettingsSheet(onDismiss: { showSettings = false })
            }
            .sheet(item: $selectedObjective) { objective in
                AriseObjectiveDetailView(objective: objective, onDismiss: { selectedObjective = nil })
            }
            .onAppear {
                ensureUserProgressExists()
                syncGoalsFromServer()
                autoPinIfNeeded()
            }
            .refreshable {
                await syncGoalsFromServerAsync()
            }
        }
    }
    
    private func ensureUserProgressExists() {
        if userProgressList.isEmpty {
            let progress = LevelUpUserProgress()
            modelContext.insert(progress)
            try? modelContext.save()
        }
    }
    
    private func autoPinIfNeeded() {
        if LevelUpGoalPinning.autoPinIfNeeded(activeGoals: activeGoals) {
            try? modelContext.save()
        }
    }
    
    private func syncGoalsFromServer() {
        Task {
            await syncGoalsFromServerAsync()
        }
    }
    
    @MainActor
    private func syncGoalsFromServerAsync() async {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil
        
        do {
            let api = LevelUpAPIFactory.makeClient()
            let serverGoals = try await api.listGoals(status: "active")
            
            for serverGoal in serverGoals {
                // Check if goal already exists locally (by serverID)
                if let existing = allGoals.first(where: { $0.serverID == serverGoal.id }) {
                    // Update existing goal
                    existing.title = serverGoal.title
                    existing.goalDescription = serverGoal.description
                    existing.status = LevelUpGoalStatus.fromAPI(serverGoal.status)
                    existing.createdAt = serverGoal.createdAt
                    existing.targetDate = serverGoal.targetDate
                    existing.lastSyncedAt = Date()
                } else {
                    // Insert new goal
                    let newGoal = LevelUpGoal(
                        title: serverGoal.title,
                        goalDescription: serverGoal.description,
                        createdAt: serverGoal.createdAt,
                        targetDate: serverGoal.targetDate,
                        status: LevelUpGoalStatus.fromAPI(serverGoal.status),
                        serverID: serverGoal.id,
                        lastSyncedAt: Date()
                    )
                    modelContext.insert(newGoal)
                }
            }
            
            try modelContext.save()
            
            // Auto-pin if no goals are pinned yet
            autoPinIfNeeded()
            
        } catch {
            syncError = error.localizedDescription
            print("Goal sync failed: \(error)")
        }
        
        isSyncing = false
    }
}

// MARK: - Goal Switcher (horizontal pills)

struct AriseGoalSwitcher: View {
    let goals: [LevelUpGoal]
    @Binding var selectedIndex: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedIndex = index
                        }
                    } label: {
                        Text(goal.title)
                            .font(DesignSystem.Typography.caption())
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                    .fill(selectedIndex == index ? DesignSystem.Colors.accent : DesignSystem.Colors.surface2)
                            )
                            .foregroundStyle(selectedIndex == index ? DesignSystem.Colors.onAccent : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("LevelUp.GoalSwitcher.\(index)")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Empty State (No Active Goal)

struct AriseEmptyStateView: View {
    let onCreateGoal: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(DesignSystem.Colors.accent)
                
                Text("No active goal")
                    .font(DesignSystem.Typography.title())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("Create a goal to start building your path")
                    .font(DesignSystem.Typography.body())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: onCreateGoal) {
                Text("Create Goal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .accessibilityIdentifier("LevelUp.EmptyState.CreateGoal")
        }
    }
}

// MARK: - Path View (Main Screen)

struct ArisePathView: View {
    let goal: LevelUpGoal
    let userProgress: LevelUpUserProgress?
    let onObjectiveTapped: (LevelUpObjective) -> Void
    let onAddContext: () -> Void
    var onShowProgress: (() -> Void)? = nil
    var onShowSettings: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    
    private var objectivesByTier: [(tier: String, objectives: [LevelUpObjective])] {
        let tiers = ["Foundation", "Core", "Advanced"]
        return tiers.compactMap { tier in
            let objs = goal.objectives.filter { $0.tier == tier }.sorted { $0.position < $1.position }
            return objs.isEmpty ? nil : (tier, objs)
        }
    }
    
    private var availableObjectives: [LevelUpObjective] {
        goal.objectives.filter { $0.status == .available }
    }
    
    private var nextObjective: LevelUpObjective? {
        availableObjectives.first
    }
    
    private var completedObjectives: [LevelUpObjective] {
        goal.objectives.filter { $0.status == .completed }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    
    @State private var showCompletedSection = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                goalHeader
                
                if let next = nextObjective {
                    nextObjectiveSection(next)
                }
                
                ForEach(objectivesByTier, id: \.tier) { tier, objectives in
                    tierSection(tier: tier, objectives: objectives)
                }
                
                if !completedObjectives.isEmpty {
                    completedSection
                }
                
                Spacer(minLength: 80)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .refreshable {
            // Future: sync with backend
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Arise")
                    .font(DesignSystem.Typography.title())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if let onShowSettings {
                    Button(action: onShowSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            
            HStack(spacing: 16) {
                Button(action: { onShowProgress?() }) {
                    AriseProgressRing(
                        progress: userProgress?.levelProgress ?? 0,
                        level: userProgress?.currentLevel ?? 1
                    )
                    .frame(width: 72, height: 72)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View progress details")

                VStack(alignment: .leading, spacing: 8) {
                    AriseStreakIndicator(
                        last7States: streakStates(),
                        streakCount: userProgress?.currentStreak ?? 0
                    )

                    Text("\(userProgress?.pointsToNextLevel ?? 100) points to Level \((userProgress?.currentLevel ?? 1) + 1)")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .glassPanel()
        }
    }
    
    private var goalHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(DesignSystem.Typography.header())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("\(goal.completedObjectives) of \(goal.totalObjectives) objectives complete")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: onAddContext) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
            .accessibilityLabel("Add context")
            .accessibilityIdentifier("LevelUp.Path.AddContext")
        }
    }
    
    private func nextObjectiveSection(_ objective: LevelUpObjective) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DSSectionHeader(title: "Next Objective")
            
            AriseObjectiveCard(
                status: .available,
                title: objective.title,
                estimateText: objective.formattedEstimate,
                pointsText: "+\(objective.pointsValue) points",
                dependencyText: nil,
                completionText: nil,
                onTap: { onObjectiveTapped(objective) },
                onQuickComplete: { quickComplete(objective) },
                onUndoComplete: nil
            )
            .accessibilityIdentifier("LevelUp.Path.NextObjective")
        }
    }
    
    private func tierSection(tier: String, objectives: [LevelUpObjective]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            DSSectionHeader(title: tier)
            
            ForEach(objectives) { objective in
                objectiveRow(objective)
            }
        }
    }
    
    private func objectiveRow(_ objective: LevelUpObjective) -> some View {
        let status: AriseObjectiveCard.Status = {
            switch objective.status {
            case .locked: return .locked
            case .available: return .available
            case .inProgress: return .inProgress
            case .completed: return .completed
            case .skipped: return .completed
            }
        }()
        
        return AriseObjectiveCard(
            status: status,
            title: objective.title,
            estimateText: objective.formattedEstimate,
            pointsText: "+\(objective.pointsValue) points",
            dependencyText: objective.status == .locked ? "Requires: \(objective.dependencies.first?.title ?? "previous objective")" : nil,
            completionText: objective.completedAt.map { "Completed \(relativeTime($0))" },
            onTap: status != .locked ? { onObjectiveTapped(objective) } : nil,
            onQuickComplete: status == .available ? { quickComplete(objective) } : nil,
            onUndoComplete: status == .completed ? { undoComplete(objective) } : nil
        )
        .accessibilityIdentifier("LevelUp.Path.Objective.\(objective.id.uuidString)")
    }
    
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showCompletedSection.toggle()
                }
            } label: {
                HStack {
                    Text("Completed (\(completedObjectives.count))")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    
                    Spacer()
                    
                    Image(systemName: showCompletedSection ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            if showCompletedSection {
                ForEach(completedObjectives) { objective in
                    objectiveRow(objective)
                }
            }
        }
    }
    
    private func quickComplete(_ objective: LevelUpObjective) {
        Task {
            do {
                guard let serverID = objective.serverID else {
                    await MainActor.run { localCompleteObjective(objective, notes: nil, pointsEarned: objective.pointsValue, unlockedServerIDs: []) }
                    return
                }
                
                let api = LevelUpAPIFactory.makeClient()
                let completion = try await api.completeObjective(objectiveID: serverID, notes: nil)
                
                await MainActor.run {
                    localCompleteObjective(
                        objective,
                        notes: nil,
                        pointsEarned: completion.pointsEarned,
                        unlockedServerIDs: completion.unlockedObjectives,
                        serverTotalPoints: completion.newTotalPoints,
                        serverNewLevel: completion.newLevel,
                        serverCurrentStreak: completion.currentStreak
                    )
                }
            } catch {
                await MainActor.run { localCompleteObjective(objective, notes: nil, pointsEarned: objective.pointsValue, unlockedServerIDs: []) }
            }
        }
    }
    
    private func localCompleteObjective(
        _ objective: LevelUpObjective,
        notes: String?,
        pointsEarned: Int,
        unlockedServerIDs: [String],
        serverTotalPoints: Int? = nil,
        serverNewLevel: Int? = nil,
        serverCurrentStreak: Int? = nil
    ) {
        objective.status = .completed
        objective.completedAt = Date()
        objective.completionNotes = notes
        
        if let progress = userProgress {
            if let serverTotalPoints {
                progress.totalPoints = max(0, serverTotalPoints)
            } else {
                progress.totalPoints += max(0, pointsEarned)
            }
            
            if let serverNewLevel {
                progress.currentLevel = max(1, serverNewLevel)
            } else {
                let newLevel = LevelUpProgression.level(forTotalPoints: progress.totalPoints)
                progress.currentLevel = max(progress.currentLevel, newLevel)
            }
            
            progress.pointsToNextLevel = LevelUpProgression.pointsToNextLevel(level: progress.currentLevel, totalPoints: progress.totalPoints)
            
            if let serverCurrentStreak {
                progress.currentStreak = max(0, serverCurrentStreak)
                progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
                progress.lastActivityDate = Date()
            } else {
                let streakUpdate = LevelUpProgression.updateStreak(
                    currentStreak: progress.currentStreak,
                    longestStreak: progress.longestStreak,
                    lastActivityDate: progress.lastActivityDate,
                    now: Date()
                )
                progress.currentStreak = streakUpdate.current
                progress.longestStreak = streakUpdate.longest
                progress.lastActivityDate = streakUpdate.lastActivityDate
            }
        }
        
        // Unlock dependents by dependency graph
        for dependent in objective.dependents {
            let allDepsComplete = dependent.dependencies.allSatisfy { $0.status == .completed }
            if allDepsComplete && dependent.status == .locked {
                dependent.status = .available
                dependent.availableAt = Date()
            }
        }
        
        // Unlock objectives by explicit server response list (if provided)
        if let goal = objective.goal, !unlockedServerIDs.isEmpty {
            for obj in goal.objectives where unlockedServerIDs.contains(obj.serverID ?? "") {
                if obj.status == .locked {
                    obj.status = .available
                    obj.availableAt = Date()
                }
            }
        }
        
        try? modelContext.save()
    }
    
    private func undoComplete(_ objective: LevelUpObjective) {
        if let progress = userProgress {
            progress.totalPoints = max(0, progress.totalPoints - objective.pointsValue)
            progress.currentLevel = LevelUpProgression.level(forTotalPoints: progress.totalPoints)
            progress.pointsToNextLevel = LevelUpProgression.pointsToNextLevel(level: progress.currentLevel, totalPoints: progress.totalPoints)
        }
        
        objective.status = .available
        objective.completedAt = nil
        objective.completionNotes = nil
        
        for dependent in objective.dependents {
            if dependent.status == .available {
                dependent.status = .locked
                dependent.availableAt = nil
            }
        }
        
        try? modelContext.save()
    }
    
    private func streakStates() -> [AriseStreakIndicator.DayState] {
        let streak = userProgress?.currentStreak ?? 0
        return (0..<7).map { i in
            if i < streak { return .completed }
            if i == streak { return .active }
            return .future
        }
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Goal Creation

struct AriseGoalCreationView: View {
    let onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var description = ""
    @State private var hasDeadline = false
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var isGenerating = false
    @State private var generationStage: GenerationStage = .idle
    @State private var error: String?
    
    enum GenerationStage: Equatable {
        case idle
        case analyzing
        case decomposing
        case calculating
        case complete
        case failed(String)
    }
    
    private var isValid: Bool {
        title.trimmingCharacters(in: .whitespaces).count >= 5
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bg.ignoresSafeArea()
                
                if isGenerating {
                    generatingView
                } else {
                    formView
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
    
    private var formView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        DSSectionHeader(title: "What are you working toward?")
                        
                        TextField("Launch my product", text: $title)
                            .font(DesignSystem.Typography.body())
                            .padding(12)
                            .background(DesignSystem.Colors.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                    .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Layout.borderWidth)
                            )
                            .accessibilityIdentifier("LevelUp.GoalCreation.Title")
                        
                        Text("\(title.count) / 100")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(title.count > 100 ? DesignSystem.Colors.error : DesignSystem.Colors.textTertiary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        DSSectionHeader(title: "Additional context (optional)")
                        
                        TextEditor(text: $description)
                            .font(DesignSystem.Typography.body())
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(12)
                            .background(DesignSystem.Colors.surface1)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                    .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Layout.borderWidth)
                            )
                            .accessibilityIdentifier("LevelUp.GoalCreation.Description")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        DSSectionHeader(title: "Timeframe")
                        
                        Toggle("Set a deadline", isOn: $hasDeadline)
                            .tint(DesignSystem.Colors.accent)
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        if hasDeadline {
                            DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .font(DesignSystem.Typography.body())
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                    }
                    
                    if let error {
                        Text(error)
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.error)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                    .fill(DesignSystem.Colors.error.opacity(0.1))
                            )
                    }
                }
                .padding(16)
            }
            
            VStack(spacing: 8) {
                Button(action: generatePath) {
                    Text("Generate Path")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!isValid)
                .opacity(isValid ? 1.0 : 0.5)
                .accessibilityIdentifier("LevelUp.GoalCreation.Generate")
                
                Text("This may take 20-30 seconds")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(16)
            .background(DesignSystem.Colors.bg)
        }
    }
    
    private var generatingView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .tint(DesignSystem.Colors.accent)
            
            VStack(spacing: 16) {
                generationStep(stage: .analyzing, label: "Analyzing goal", current: generationStage)
                generationStep(stage: .decomposing, label: "Breaking down objectives", current: generationStage)
                generationStep(stage: .calculating, label: "Calculating dependencies", current: generationStage)
            }
            
            if case .failed(let message) = generationStage {
                VStack(spacing: 16) {
                    Text(message)
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.error)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        generatePath()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.top, 24)
            }
            
            Spacer()
            
            Button("Cancel") {
                isGenerating = false
                generationStage = .idle
            }
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .padding(.bottom, 24)
        }
        .padding(16)
    }
    
    private func generationStep(stage: GenerationStage, label: String, current: GenerationStage) -> some View {
        let isComplete = stageOrder(current) > stageOrder(stage)
        let isCurrent = current == stage
        
        return HStack(spacing: 12) {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignSystem.Colors.success)
            } else if isCurrent {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(DesignSystem.Colors.accent)
            } else {
                Circle()
                    .stroke(DesignSystem.Colors.textTertiary, lineWidth: 1)
                    .frame(width: 20, height: 20)
            }
            
            Text(label)
                .font(DesignSystem.Typography.body())
                .foregroundStyle(isComplete || isCurrent ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
            
            Spacer()
        }
    }
    
    private func stageOrder(_ stage: GenerationStage) -> Int {
        switch stage {
        case .idle: return 0
        case .analyzing: return 1
        case .decomposing: return 2
        case .calculating: return 3
        case .complete: return 4
        case .failed: return -1
        }
    }
    
    private func generatePath() {
        isGenerating = true
        error = nil
        
        Task {
            do {
                generationStage = .analyzing
                try await Task.sleep(nanoseconds: 300_000_000)
                
                generationStage = .decomposing
                
                let api = LevelUpAPIFactory.makeClient()
                
                _ = try await api.authenticate(deviceID: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)
                
                let goalRequest = LevelUpCreateGoalRequest(
                    title: title.trimmingCharacters(in: .whitespaces),
                    description: description.isEmpty ? nil : description,
                    targetDate: hasDeadline ? targetDate : nil
                )
                let goalResponse = try await api.createGoal(goalRequest)
                
                generationStage = .calculating
                
                let planJob = try await api.startPlanGeneration(goalID: goalResponse.id)
                
                // Poll job status for up to ~2 minutes (60 * 2s)
                var lastStatus: String = planJob.status
                for _ in 0..<60 {
                    let status = try await api.getJob(jobID: planJob.jobID)
                    lastStatus = status.status
                    
                    await MainActor.run {
                        // Map async job status into our "stepper" UI.
                        switch status.status.lowercased() {
                        case "queued":
                            generationStage = .decomposing
                        case "running":
                            generationStage = .calculating
                        case "failed":
                            generationStage = .failed(status.error ?? "Plan generation failed.")
                        default:
                            break
                        }
                    }
                    
                    if status.status.lowercased() == "succeeded" {
                        break
                    }
                    if status.status.lowercased() == "failed" {
                        throw LevelUpError.pathGenerationFailed(status.error ?? "Plan generation failed.")
                    }
                    
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                }
                
                guard lastStatus.lowercased() == "succeeded" else {
                    throw LevelUpError.pathGenerationFailed("Timed out generating plan.")
                }
                
                let planResponse = try await api.getPlan(planID: planJob.planID)
                
                await MainActor.run {
                    let goal = LevelUpGoal(
                        title: goalResponse.title,
                        goalDescription: goalResponse.description,
                        targetDate: goalResponse.targetDate,
                        serverID: goalResponse.id
                    )
                    modelContext.insert(goal)
                    
                    var objectiveMap: [String: LevelUpObjective] = [:]
                    for objResponse in planResponse.objectives {
                        let objective = LevelUpObjective(
                            serverID: objResponse.id,
                            title: objResponse.title,
                            objectiveDescription: objResponse.description ?? "",
                            estimatedHours: objResponse.estimatedHours ?? 0,
                            pointsValue: objResponse.pointsValue,
                            tier: objResponse.tier,
                            position: objResponse.position,
                            status: LevelUpObjectiveStatus.fromAPI(objResponse.status),
                            purpose: objResponse.purpose,
                            unlocks: objResponse.unlocks ?? "",
                            goal: goal
                        )
                        modelContext.insert(objective)
                        objectiveMap[objResponse.id] = objective
                        goal.objectives.append(objective)
                    }
                    
                    for dep in planResponse.dependencies {
                        if let from = objectiveMap[dep.from], let to = objectiveMap[dep.to] {
                            to.dependencies.append(from)
                            from.dependents.append(to)
                        }
                    }
                    
                    try? modelContext.save()
                    
                    generationStage = .complete
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    generationStage = .failed(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Objective Detail

struct AriseObjectiveDetailView: View {
    let objective: LevelUpObjective
    let onDismiss: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @Query private var userProgressList: [LevelUpUserProgress]
    
    @State private var showCompletionSheet = false
    
    private var userProgress: LevelUpUserProgress? { userProgressList.first }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        descriptionSection
                        
                        if !objective.purpose.isEmpty {
                            purposeSection
                        }
                        
                        if !objective.contextSources.isEmpty {
                            contextSection
                        }
                        
                        if !objective.dependencies.isEmpty && objective.status == .locked {
                            dependenciesSection
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(16)
                }
                
                VStack {
                    Spacer()
                    bottomCTA
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Skip This", role: .destructive) {
                            skipObjective()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showCompletionSheet) {
                AriseCompletionSheet(objective: objective, onComplete: { notes in
                    completeObjective(notes: notes)
                    showCompletionSheet = false
                    onDismiss()
                }, onCancel: {
                    showCompletionSheet = false
                })
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                statusBadge
                Spacer()
            }
            
            Text(objective.title)
                .font(DesignSystem.Typography.title())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: 16) {
                Label(objective.formattedEstimate, systemImage: "clock")
                Label("+\(objective.pointsValue) points", systemImage: "star")
            }
            .font(DesignSystem.Typography.caption())
            .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
    
    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch objective.status {
            case .locked: return ("Locked", DesignSystem.Colors.textTertiary)
            case .available: return ("Available", DesignSystem.Colors.accent)
            case .inProgress: return ("In Progress", DesignSystem.Colors.warning)
            case .completed: return ("Completed", DesignSystem.Colors.success)
            case .skipped: return ("Skipped", DesignSystem.Colors.textTertiary)
            }
        }()
        
        return DSChip(text: text, isActive: objective.status == .available || objective.status == .inProgress)
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSSectionHeader(title: "What to do")
            
            Text(objective.objectiveDescription)
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }
    
    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSSectionHeader(title: "Purpose")
            
            Text(objective.purpose)
                .font(DesignSystem.Typography.body())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            
            if !objective.unlocks.isEmpty {
                Text("Unlocks: \(objective.unlocks)")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.accent)
            }
        }
    }
    
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSSectionHeader(title: "Context used")
            
            ForEach(objective.contextSources.prefix(3)) { context in
                AriseContextSnippetCard(
                    sourceLabel: context.source ?? "Context",
                    snippet: context.content
                )
            }
        }
    }
    
    private var dependenciesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DSSectionHeader(title: "Requires first")
            
            ForEach(objective.dependencies) { dep in
                HStack(spacing: 12) {
                    Image(systemName: dep.status == .completed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(dep.status == .completed ? DesignSystem.Colors.success : DesignSystem.Colors.textTertiary)
                    
                    Text(dep.title)
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .strikethrough(dep.status == .completed)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mattePanel()
            }
        }
    }
    
    private var bottomCTA: some View {
        VStack(spacing: 0) {
            Divider()
                .background(DesignSystem.Colors.separator)
            
            Group {
                switch objective.status {
                case .available, .inProgress:
                    Button(action: { showCompletionSheet = true }) {
                        Text("Mark as Complete")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("LevelUp.ObjectiveDetail.Complete")
                    
                case .locked:
                    Button(action: {}) {
                        Text("Complete prerequisites first")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(true)
                    .opacity(0.5)
                    
                case .completed:
                    VStack(spacing: 8) {
                        if let completedAt = objective.completedAt {
                            Text("Completed \(relativeTime(completedAt))")
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                        
                        Button(action: { undoCompletion() }) {
                            Text("Undo Completion")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                    
                case .skipped:
                    Text("This objective was skipped")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(16)
        }
        .background(DesignSystem.Colors.bg)
    }
    
    private func completeObjective(notes: String?) {
        objective.status = .completed
        objective.completedAt = Date()
        objective.completionNotes = notes
        
        if let progress = userProgress {
            progress.totalPoints += objective.pointsValue
            progress.pointsToNextLevel = LevelUpProgression.pointsToNextLevel(level: progress.currentLevel, totalPoints: progress.totalPoints)
            
            let newLevel = LevelUpProgression.level(forTotalPoints: progress.totalPoints)
            if newLevel > progress.currentLevel {
                progress.currentLevel = newLevel
            }
            
            let streakUpdate = LevelUpProgression.updateStreak(
                currentStreak: progress.currentStreak,
                longestStreak: progress.longestStreak,
                lastActivityDate: progress.lastActivityDate,
                now: Date()
            )
            progress.currentStreak = streakUpdate.current
            progress.longestStreak = streakUpdate.longest
            progress.lastActivityDate = streakUpdate.lastActivityDate
        }
        
        for dependent in objective.dependents {
            let allDepsComplete = dependent.dependencies.allSatisfy { $0.status == .completed }
            if allDepsComplete && dependent.status == .locked {
                dependent.status = .available
                dependent.availableAt = Date()
            }
        }
        
        try? modelContext.save()
    }
    
    private func undoCompletion() {
        if let progress = userProgress {
            progress.totalPoints = max(0, progress.totalPoints - objective.pointsValue)
            progress.currentLevel = LevelUpProgression.level(forTotalPoints: progress.totalPoints)
            progress.pointsToNextLevel = LevelUpProgression.pointsToNextLevel(level: progress.currentLevel, totalPoints: progress.totalPoints)
        }
        
        objective.status = .available
        objective.completedAt = nil
        objective.completionNotes = nil
        
        for dependent in objective.dependents {
            if dependent.status == .available {
                dependent.status = .locked
                dependent.availableAt = nil
            }
        }
        
        try? modelContext.save()
        onDismiss()
    }
    
    private func skipObjective() {
        objective.status = .skipped
        objective.completedAt = Date()
        
        for dependent in objective.dependents {
            let allDepsHandled = dependent.dependencies.allSatisfy { $0.status == .completed || $0.status == .skipped }
            if allDepsHandled && dependent.status == .locked {
                dependent.status = .available
                dependent.availableAt = Date()
            }
        }
        
        try? modelContext.save()
        onDismiss()
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Completion Sheet

struct AriseCompletionSheet: View {
    let objective: LevelUpObjective
    let onComplete: (String?) -> Void
    let onCancel: () -> Void
    
    @State private var notes = ""
    @State private var tookLonger = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.bg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Complete Objective")
                                    .font(DesignSystem.Typography.header())
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                
                                Text(objective.title)
                                    .font(DesignSystem.Typography.body())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                DSSectionHeader(title: "Completion notes (optional)")
                                
                                TextEditor(text: $notes)
                                    .font(DesignSystem.Typography.body())
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 100)
                                    .padding(12)
                                    .background(DesignSystem.Colors.surface1)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                            .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Layout.borderWidth)
                                    )
                                    .accessibilityIdentifier("LevelUp.Completion.Notes")
                                
                                Text("\(notes.count) / 300")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(notes.count > 300 ? DesignSystem.Colors.error : DesignSystem.Colors.textTertiary)
                            }
                            
                            Toggle("This took longer than estimated", isOn: $tookLonger)
                                .tint(DesignSystem.Colors.accent)
                                .font(DesignSystem.Typography.body())
                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                        }
                        .padding(16)
                    }
                    
                    VStack(spacing: 8) {
                        Button(action: { onComplete(notes.isEmpty ? nil : notes) }) {
                            Text("Complete & Continue")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .accessibilityIdentifier("LevelUp.Completion.Submit")
                        
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(16)
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Context Root View

struct AriseContextRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [LevelUpGoal]
    
    private var activeGoals: [LevelUpGoal] {
        allGoals.filter { $0.status == .active }
    }
    
    @State private var newContext = ""
    @State private var source = ""
    @State private var isSaving = false
    
    private var activeGoal: LevelUpGoal? { activeGoals.first }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.bg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Text("Context")
                        .font(DesignSystem.Typography.title())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            DSSectionHeader(title: "Paste notes, conversations, or ideas")
                            
                            TextEditor(text: $newContext)
                                .font(DesignSystem.Typography.body())
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                                .padding(12)
                                .background(DesignSystem.Colors.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                        .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Layout.borderWidth)
                                )
                                .accessibilityIdentifier("LevelUp.Context.Input")
                            
                            HStack {
                                Text("\(newContext.count) / 5000")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(newContext.count > 5000 ? DesignSystem.Colors.error : DesignSystem.Colors.textTertiary)
                                
                                Spacer()
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            DSSectionHeader(title: "Where is this from? (optional)")
                            
                            TextField("e.g., Client meeting, research", text: $source)
                                .font(DesignSystem.Typography.body())
                                .padding(12)
                                .background(DesignSystem.Colors.surface1)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadiusSmall, style: .continuous)
                                        .stroke(DesignSystem.Colors.border, lineWidth: DesignSystem.Layout.borderWidth)
                                )
                        }
                        
                        Text("More context = better objectives. This helps the AI understand your situation.")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        if let goal = activeGoal, !goal.contexts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                DSSectionHeader(title: "Existing context")
                                
                                ForEach(goal.contexts.sorted { $0.createdAt > $1.createdAt }) { context in
                                    AriseContextSnippetCard(
                                        sourceLabel: context.source ?? "Added \(relativeTime(context.createdAt))",
                                        snippet: context.content
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Button(action: addContext) {
                    if isSaving {
                        ProgressView()
                            .tint(DesignSystem.Colors.onAccent)
                    } else {
                        Text("Add Context")
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(newContext.trimmingCharacters(in: .whitespaces).isEmpty || isSaving || activeGoal == nil)
                .opacity(newContext.trimmingCharacters(in: .whitespaces).isEmpty || activeGoal == nil ? 0.5 : 1.0)
                .padding(16)
                .accessibilityIdentifier("LevelUp.Context.Add")
            }
        }
    }
    
    private func addContext() {
        guard let goal = activeGoal else { return }
        
        isSaving = true
        let trimmed = newContext.trimmingCharacters(in: .whitespacesAndNewlines)
        let src = source.isEmpty ? nil : source
        
        Task {
            defer {
                Task { @MainActor in
                    newContext = ""
                    source = ""
                    isSaving = false
                }
            }
            
            do {
                if let serverGoalID = goal.serverID {
                    let api = LevelUpAPIFactory.makeClient()
                    let created = try await api.addContext(goalID: serverGoalID, request: .init(content: trimmed, source: src))
                    
                    await MainActor.run {
                        let context = LevelUpContext(
                            serverID: created.id,
                            content: created.content,
                            source: created.source,
                            createdAt: created.createdAt,
                            goal: goal
                        )
                        modelContext.insert(context)
                        goal.contexts.append(context)
                        try? modelContext.save()
                    }
                } else {
                    // Offline/local-only fallback.
                    await MainActor.run {
                        let context = LevelUpContext(content: trimmed, source: src, goal: goal)
                        modelContext.insert(context)
                        goal.contexts.append(context)
                        try? modelContext.save()
                    }
                }
            } catch {
                // Keep UX simple: fall back to local save if network fails.
                await MainActor.run {
                    let context = LevelUpContext(content: trimmed, source: src, goal: goal)
                    modelContext.insert(context)
                    goal.contexts.append(context)
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Progress Root View

struct AriseProgressRootView: View {
    @Query private var userProgressList: [LevelUpUserProgress]
    @Query private var allGoals: [LevelUpGoal]
    @Query private var allObjectives: [LevelUpObjective]
    
    private var activeGoals: [LevelUpGoal] {
        allGoals.filter { $0.status == .active }
    }
    
    private var completedObjectives: [LevelUpObjective] {
        allObjectives.filter { $0.status == .completed }
    }
    
    private var userProgress: LevelUpUserProgress? { userProgressList.first }
    private var activeGoal: LevelUpGoal? { activeGoals.first }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.bg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("Progress")
                            .font(DesignSystem.Typography.title())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    
                    VStack(spacing: 16) {
                        AriseProgressRing(
                            progress: userProgress?.levelProgress ?? 0,
                            level: userProgress?.currentLevel ?? 1
                        )
                        .frame(width: 140, height: 140)
                        
                        Text("\(userProgress?.totalPoints ?? 0) / \((userProgress?.totalPoints ?? 0) + (userProgress?.pointsToNextLevel ?? 100)) points to Level \((userProgress?.currentLevel ?? 1) + 1)")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 24)
                    
                    if let goal = activeGoal {
                        VStack(alignment: .leading, spacing: 12) {
                            DSSectionHeader(title: "Current goal")
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(goal.title)
                                    .font(DesignSystem.Typography.header())
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                
                                ProgressView(value: goal.progressPercentage)
                                    .tint(DesignSystem.Colors.accent)
                                
                                Text("\(goal.completedObjectives) of \(goal.totalObjectives) objectives complete")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            .padding(16)
                            .glassPanel()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        DSSectionHeader(title: "Streak")
                        
                        HStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(userProgress?.currentStreak ?? 0)")
                                    .font(DesignSystem.Typography.title())
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text("Current")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(userProgress?.longestStreak ?? 0)")
                                    .font(DesignSystem.Typography.title())
                                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                                Text("Longest")
                                    .font(DesignSystem.Typography.caption())
                                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .glassPanel()
                    }
                    
                    if !completedObjectives.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            DSSectionHeader(title: "Recent completions")
                            
                            VStack(spacing: 0) {
                                ForEach(completedObjectives.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }.prefix(5)) { objective in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(objective.title)
                                                .font(DesignSystem.Typography.body())
                                                .foregroundStyle(DesignSystem.Colors.textPrimary)
                                                .lineLimit(1)
                                            
                                            if let completedAt = objective.completedAt {
                                                Text(relativeTime(completedAt))
                                                    .font(DesignSystem.Typography.caption())
                                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text("+\(objective.pointsValue)")
                                            .font(DesignSystem.Typography.caption())
                                            .foregroundStyle(DesignSystem.Colors.accent)
                                    }
                                    .padding(12)
                                }
                            }
                            .glassPanel()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Settings Root View

struct AriseSettingsRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allGoals: [LevelUpGoal]
    @Query private var userProgressList: [LevelUpUserProgress]
    @AppStorage("appAppearance") private var appAppearanceRaw: String = AppAppearance.system.rawValue

    private var activeGoals: [LevelUpGoal] {
        allGoals.filter { $0.status == .active }.sorted { $0.createdAt > $1.createdAt }
    }
    
    private var pinnedGoals: [LevelUpGoal] {
        LevelUpGoalPinning.pinnedGoals(from: activeGoals)
    }
    
    private var pinnedCount: Int { pinnedGoals.count }

    @State private var showNewGoalSheet = false
    @State private var showDeleteConfirmation = false

    private var userProgress: LevelUpUserProgress? { userProgressList.first }

    var body: some View {
        ZStack {
            DesignSystem.Colors.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Text("Settings")
                            .font(DesignSystem.Typography.title())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    
                    // MARK: - Goals Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            DSSectionHeader(title: "Goals")
                            Spacer()
                            Text("Pinned \(pinnedCount)/\(LevelUpGoalPinning.maxPinnedGoals)")
                                .font(DesignSystem.Typography.caption())
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                        
                        if activeGoals.isEmpty {
                            Text("No goals yet")
                                .font(DesignSystem.Typography.body())
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassPanel()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(activeGoals.enumerated()), id: \.element.id) { index, goal in
                                    if index > 0 {
                                        Divider()
                                            .background(DesignSystem.Colors.separator)
                                    }
                                    
                                    AriseGoalRow(
                                        goal: goal,
                                        isPinned: goal.isPinned,
                                        canPin: pinnedCount < LevelUpGoalPinning.maxPinnedGoals || goal.isPinned,
                                        onTogglePin: {
                                            togglePin(goal)
                                        }
                                    )
                                    .accessibilityIdentifier("LevelUp.Settings.Goal.\(goal.id.uuidString)")
                                }
                            }
                            .glassPanel()
                        }
                        
                        Button(action: { showNewGoalSheet = true }) {
                            Label("New Goal", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .accessibilityIdentifier("LevelUp.Settings.NewGoal")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        DSSectionHeader(title: "Preferences")

                        VStack(spacing: 0) {
                            Toggle("Streak Reminders", isOn: .init(
                                get: { userProgress?.dailyReminderEnabled ?? false },
                                set: { newValue in
                                    userProgress?.dailyReminderEnabled = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .tint(DesignSystem.Colors.accent)
                            .padding(16)

                            Divider()
                                .background(DesignSystem.Colors.separator)

                            Toggle("Notifications", isOn: .init(
                                get: { userProgress?.notificationsEnabled ?? false },
                                set: { newValue in
                                    userProgress?.notificationsEnabled = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .tint(DesignSystem.Colors.accent)
                            .padding(16)
                        }
                        .font(DesignSystem.Typography.body())
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .glassPanel()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        DSSectionHeader(title: "Appearance")

                        Picker("", selection: $appAppearanceRaw) {
                            ForEach(AppAppearance.allCases) { option in
                                Text(option.title).tag(option.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        DSSectionHeader(title: "Data")

                        Button(action: { showDeleteConfirmation = true }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundStyle(DesignSystem.Colors.error)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Clear Completed Objectives")
                                        .font(DesignSystem.Typography.body())
                                        .foregroundStyle(DesignSystem.Colors.textPrimary)

                                    Text("Removes completed objectives from all goals")
                                        .font(DesignSystem.Typography.caption())
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                }

                                Spacer()
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassPanel()
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 4) {
                        Text("Arise")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)

                        Text("Version 1.0.0")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .sheet(isPresented: $showNewGoalSheet) {
            AriseGoalCreationView(onDismiss: { showNewGoalSheet = false })
        }
        .alert("Clear Completed?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCompletedObjectives()
            }
        } message: {
            Text("This will remove all completed objectives from your history. This cannot be undone.")
        }
    }
    
    private func togglePin(_ goal: LevelUpGoal) {
        if goal.isPinned {
            LevelUpGoalPinning.unpin(goal)
        } else {
            LevelUpGoalPinning.pin(goal, allGoals: activeGoals)
        }
        try? modelContext.save()
    }
    
    private func clearCompletedObjectives() {
        for goal in activeGoals {
            let completed = goal.objectives.filter { $0.status == .completed }
            for obj in completed {
                modelContext.delete(obj)
            }
        }
        try? modelContext.save()
    }
}

// MARK: - Goal Row for Settings

struct AriseGoalRow: View {
    let goal: LevelUpGoal
    let isPinned: Bool
    let canPin: Bool
    let onTogglePin: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(DesignSystem.Typography.body())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Text("\(goal.totalObjectives) objectives")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    
                    if goal.completedObjectives > 0 {
                        Text("\(goal.completedObjectives) done")
                            .font(DesignSystem.Typography.caption())
                            .foregroundStyle(DesignSystem.Colors.success)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onTogglePin) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isPinned ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canPin && !isPinned)
            .opacity(!canPin && !isPinned ? 0.4 : 1.0)
            .accessibilityIdentifier("LevelUp.Settings.Goal.Pin.\(goal.id.uuidString)")
            .accessibilityLabel(isPinned ? "Unpin goal" : "Pin goal")
        }
        .padding(16)
    }
}

// MARK: - Core Components

struct AriseProgressRing: View {
    let progress: Double
    let level: Int
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.Colors.separator, lineWidth: 10)
            
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    DesignSystem.Colors.accent,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: progress)
            
            VStack(spacing: 0) {
                Text("\(level)")
                    .font(DesignSystem.Typography.title())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                
                Text("LEVEL")
                    .font(DesignSystem.Typography.caption())
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level)")
        .accessibilityValue("\(Int(progress * 100)) percent to next level")
    }
}

struct AriseStreakIndicator: View {
    let last7States: [DayState]
    let streakCount: Int
    
    enum DayState {
        case active
        case completed
        case future
        case atRisk
    }
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(last7States.enumerated()), id: \.offset) { _, state in
                    Circle()
                        .strokeBorder(strokeColor(for: state), lineWidth: state == .future ? 1 : 0)
                        .background(Circle().fill(fillColor(for: state)))
                        .frame(width: 8, height: 8)
                        .opacity(state == .atRisk && !reduceMotion ? (pulse ? 1.0 : 0.6) : 1.0)
                }
            }
            
            Text("\(streakCount) day streak")
                .font(DesignSystem.Typography.caption())
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
        .onAppear {
            guard !reduceMotion else { return }
            pulse = false
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Streak")
        .accessibilityValue("\(streakCount) days")
    }
    
    private func fillColor(for state: DayState) -> Color {
        switch state {
        case .active: return DesignSystem.Colors.accent
        case .completed: return DesignSystem.Colors.success
        case .future: return Color.clear
        case .atRisk: return DesignSystem.Colors.warning
        }
    }
    
    private func strokeColor(for state: DayState) -> Color {
        switch state {
        case .future: return DesignSystem.Colors.separator
        default: return Color.clear
        }
    }
}

struct AriseContextSnippetCard: View {
    let sourceLabel: String
    let snippet: String
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Text(sourceLabel)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    Spacer()
                }
                
                Text(snippet)
                    .font(DesignSystem.Typography.body())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .lineLimit(isExpanded ? nil : 2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .glassPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Context snippet")
        .accessibilityHint(isExpanded ? "Collapses snippet" : "Expands snippet")
    }
}

struct AriseObjectiveCard: View {
    enum Status {
        case locked
        case available
        case inProgress
        case completed
    }
    
    let status: Status
    let title: String
    let estimateText: String?
    let pointsText: String?
    let dependencyText: String?
    let completionText: String?
    let onTap: (() -> Void)?
    let onQuickComplete: (() -> Void)?
    let onUndoComplete: (() -> Void)?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: Bool = false
    
    var body: some View {
        let isTappable = (status != .locked) && (onTap != nil)
        
        Group {
            if isTappable {
                Button(action: { onTap?() }) {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if status == .available, let onQuickComplete {
                Button {
                    onQuickComplete()
                } label: {
                    Label("Complete", systemImage: "checkmark")
                }
                .tint(DesignSystem.Colors.success)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if status == .completed, let onUndoComplete {
                Button(role: .destructive) {
                    onUndoComplete()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .tint(DesignSystem.Colors.error)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            if status == .available {
                pulse = false
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
    
    private var content: some View {
        HStack(spacing: 16) {
            leadingIcon
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(status == .available || status == .inProgress ? DesignSystem.Typography.header() : DesignSystem.Typography.body())
                    .foregroundStyle(titleColor)
                    .strikethrough(status == .completed, color: titleColor)
                    .lineLimit(2)
                
                if let estimateText, status != .locked {
                    Label(estimateText, systemImage: "clock")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
                
                if let pointsText, status == .available || status == .inProgress || status == .completed {
                    Label(pointsText, systemImage: "star")
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(pointsColor)
                }
                
                if let dependencyText {
                    Text(dependencyText)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                if let completionText, status == .completed {
                    Text(completionText)
                        .font(DesignSystem.Typography.caption())
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            
            Spacer(minLength: 0)
            
            if status == .available || status == .inProgress || status == .completed {
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: borderWidth)
                .opacity(status == .available && !reduceMotion ? (pulse ? 1.0 : 0.7) : 1.0)
        )
        .opacity(status == .completed ? 0.7 : 1.0)
    }
    
    private var minHeight: CGFloat {
        switch status {
        case .available, .inProgress: return 88
        case .locked: return 80
        case .completed: return 72
        }
    }
    
    private var leadingIcon: some View {
        Group {
            switch status {
            case .locked:
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .frame(width: 24, height: 24)
            case .available:
                Image(systemName: "circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.accent)
                    .frame(width: 24, height: 24)
            case .inProgress:
                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.warning)
                    .frame(width: 24, height: 24)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.success)
                    .frame(width: 24, height: 24)
            }
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .locked: return DesignSystem.Colors.surface2
        case .available, .inProgress, .completed: return DesignSystem.Colors.surface1
        }
    }
    
    private var titleColor: Color {
        switch status {
        case .locked: return DesignSystem.Colors.textTertiary
        case .completed: return DesignSystem.Colors.textSecondary
        case .available, .inProgress: return DesignSystem.Colors.textPrimary
        }
    }
    
    private var pointsColor: Color {
        switch status {
        case .completed: return DesignSystem.Colors.success
        case .available: return DesignSystem.Colors.accent
        case .inProgress: return DesignSystem.Colors.warning
        case .locked: return DesignSystem.Colors.textTertiary
        }
    }
    
    private var borderColor: Color {
        switch status {
        case .available: return DesignSystem.Colors.accent
        case .inProgress: return DesignSystem.Colors.warning
        case .completed: return DesignSystem.Colors.success
        case .locked: return DesignSystem.Colors.border
        }
    }
    
    private var borderWidth: CGFloat {
        switch status {
        case .available: return 2
        default: return DesignSystem.Layout.borderWidth
        }
    }
}

// MARK: - Sheet Wrappers

struct AriseContextSheet: View {
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            AriseContextRootView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { onDismiss() }
                    }
                }
        }
    }
}

struct AriseProgressSheet: View {
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            AriseProgressRootView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { onDismiss() }
                    }
                }
        }
    }
}

struct AriseSettingsSheet: View {
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            AriseSettingsRootView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { onDismiss() }
                    }
                }
        }
    }
}

// MARK: - Legacy aliases for compatibility

typealias LevelUpOnboardingView = AriseEmptyStateView
typealias LevelUpPathRootView = ArisePathView
typealias LevelUpContextRootView = AriseContextRootView
typealias LevelUpProgressRootView = AriseProgressRootView
typealias LevelUpSettingsRootView = AriseSettingsRootView
typealias LevelUpGoalCreationView = AriseGoalCreationView

#Preview {
    AriseView()
}
