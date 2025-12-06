//
//  ARISEModels.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//

import Foundation

// MARK: - Enums

enum Timeframe: String, Codable, CaseIterable {
    case annual
    case quarterly
    case monthly
    case weekly
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum GoalStatus: String, Codable {
    case active
    case completed
    case archived
}

enum NodeStatus: String, Codable {
    case locked
    case available
    case inProgress = "in_progress"
    case completed
}

enum ContextType: String, Codable {
    case conversation
    case note
    case document
    case manual
}

// MARK: - Core Models

struct Goal: Identifiable, Codable {
    var id: UUID
    var title: String
    var description: String
    var timeframe: Timeframe
    var targetDate: Date?
    var status: GoalStatus
    var createdAt: Date
    var treeId: UUID?
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        timeframe: Timeframe = .quarterly,
        targetDate: Date? = nil,
        status: GoalStatus = .active,
        createdAt: Date = Date(),
        treeId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.timeframe = timeframe
        self.targetDate = targetDate
        self.status = status
        self.createdAt = createdAt
        self.treeId = treeId
    }
}

struct SkillTree: Identifiable, Codable {
    var id: UUID
    var goalId: UUID
    var title: String
    var branches: [Branch]
    var generatedAt: Date
    var lastUpdated: Date
    
    init(
        id: UUID = UUID(),
        goalId: UUID,
        title: String,
        branches: [Branch] = [],
        generatedAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.goalId = goalId
        self.title = title
        self.branches = branches
        self.generatedAt = generatedAt
        self.lastUpdated = lastUpdated
    }
    
    var allNodes: [SkillNode] {
        branches.flatMap { $0.nodes }
    }
    
    var completedNodes: [SkillNode] {
        allNodes.filter { $0.status == .completed }
    }
    
    var availableNodes: [SkillNode] {
        allNodes.filter { $0.status == .available }
    }
    
    var progressPercentage: Double {
        guard !allNodes.isEmpty else { return 0 }
        return Double(completedNodes.count) / Double(allNodes.count) * 100
    }
}

struct Branch: Identifiable, Codable {
    var id: UUID
    var name: String
    var nodes: [SkillNode]
    
    init(id: UUID = UUID(), name: String, nodes: [SkillNode] = []) {
        self.id = id
        self.name = name
        self.nodes = nodes
    }
    
    var completedCount: Int {
        nodes.filter { $0.status == .completed }.count
    }
    
    var progressPercentage: Double {
        guard !nodes.isEmpty else { return 0 }
        return Double(completedCount) / Double(nodes.count) * 100
    }
}

struct SkillNode: Identifiable, Codable {
    var id: UUID
    var title: String
    var description: String
    var tier: Int
    var prerequisites: [UUID]
    var completionCriteria: [String]
    var estimatedHours: Double
    var xpValue: Int
    var status: NodeStatus
    var completedAt: Date?
    var completionNotes: String?
    var linkedStats: [String]
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        tier: Int = 1,
        prerequisites: [UUID] = [],
        completionCriteria: [String] = [],
        estimatedHours: Double = 2.0,
        xpValue: Int = 100,
        status: NodeStatus = .locked,
        completedAt: Date? = nil,
        completionNotes: String? = nil,
        linkedStats: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.tier = tier
        self.prerequisites = prerequisites
        self.completionCriteria = completionCriteria
        self.estimatedHours = estimatedHours
        self.xpValue = xpValue
        self.status = status
        self.completedAt = completedAt
        self.completionNotes = completionNotes
        self.linkedStats = linkedStats
    }
}

struct UserStats: Codable {
    var level: Int
    var totalXP: Int
    var currentStreak: Int
    var longestStreak: Int
    var nodesCompleted: Int
    var treesCompleted: Int
    var str: Int
    var int: Int
    var wis: Int
    var dex: Int
    var cha: Int
    var vit: Int
    var lastActiveDate: Date?
    
    init(
        level: Int = 1,
        totalXP: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        nodesCompleted: Int = 0,
        treesCompleted: Int = 0,
        str: Int = 10,
        int: Int = 10,
        wis: Int = 10,
        dex: Int = 10,
        cha: Int = 10,
        vit: Int = 10,
        lastActiveDate: Date? = nil
    ) {
        self.level = level
        self.totalXP = totalXP
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.nodesCompleted = nodesCompleted
        self.treesCompleted = treesCompleted
        self.str = str
        self.int = int
        self.wis = wis
        self.dex = dex
        self.cha = cha
        self.vit = vit
        self.lastActiveDate = lastActiveDate
    }
    
    var xpForNextLevel: Int {
        level * 1000
    }
    
    var xpProgress: Double {
        let xpInCurrentLevel = totalXP % 1000
        return Double(xpInCurrentLevel) / Double(xpForNextLevel) * 100
    }
    
    mutating func addXP(_ amount: Int, linkedStats: [String] = []) {
        totalXP += amount
        nodesCompleted += 1
        
        while totalXP >= level * 1000 {
            level += 1
        }
        
        for stat in linkedStats {
            switch stat.uppercased() {
            case "STR": str += 1
            case "INT": int += 1
            case "WIS": wis += 1
            case "DEX": dex += 1
            case "CHA": cha += 1
            case "VIT": vit += 1
            default: break
            }
        }
        
        updateStreak()
    }
    
    mutating func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastActive = lastActiveDate {
            let lastActiveDay = calendar.startOfDay(for: lastActive)
            let daysDiff = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0
            
            if daysDiff == 1 {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else if daysDiff > 1 {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        
        lastActiveDate = Date()
    }
}

struct ContextSource: Identifiable, Codable {
    var id: UUID
    var sourceType: ContextType
    var title: String
    var content: String
    var ingestedAt: Date
    
    init(
        id: UUID = UUID(),
        sourceType: ContextType,
        title: String = "",
        content: String,
        ingestedAt: Date = Date()
    ) {
        self.id = id
        self.sourceType = sourceType
        self.title = title
        self.content = content
        self.ingestedAt = ingestedAt
    }
}

// MARK: - ARISE Manager

@MainActor
class ARISEManager: ObservableObject {
    @Published var goals: [Goal] = []
    @Published var trees: [SkillTree] = []
    @Published var contextSources: [ContextSource] = []
    @Published var stats: UserStats = UserStats()
    @Published var isLoading: Bool = false
    @Published var isGeneratingTree: Bool = false
    
    private let goalsKey = "arise_goals"
    private let treesKey = "arise_trees"
    private let contextKey = "arise_context"
    private let statsKey = "arise_stats"
    
    init() {
        loadData()
    }
    
    // MARK: - Goals
    
    func addGoal(_ goal: Goal) {
        goals.insert(goal, at: 0)
        saveGoals()
    }
    
    func updateGoal(_ goal: Goal) {
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            saveGoals()
        }
    }
    
    func deleteGoal(_ goal: Goal) {
        if let treeId = goal.treeId {
            trees.removeAll { $0.id == treeId }
            saveTrees()
        }
        goals.removeAll { $0.id == goal.id }
        saveGoals()
    }
    
    var activeGoals: [Goal] {
        goals.filter { $0.status == .active }
    }
    
    // MARK: - Trees
    
    func tree(for goalId: UUID) -> SkillTree? {
        trees.first { $0.goalId == goalId }
    }
    
    func addTree(_ tree: SkillTree) {
        trees.append(tree)
        if let index = goals.firstIndex(where: { $0.id == tree.goalId }) {
            goals[index].treeId = tree.id
            saveGoals()
        }
        saveTrees()
    }
    
    func updateTree(_ tree: SkillTree) {
        if let index = trees.firstIndex(where: { $0.id == tree.id }) {
            var updatedTree = tree
            updatedTree.lastUpdated = Date()
            trees[index] = updatedTree
            saveTrees()
        }
    }
    
    // MARK: - Nodes
    
    func completeNode(nodeId: UUID, in treeId: UUID, notes: String?) {
        guard let treeIndex = trees.firstIndex(where: { $0.id == treeId }) else { return }
        
        for branchIndex in trees[treeIndex].branches.indices {
            if let nodeIndex = trees[treeIndex].branches[branchIndex].nodes.firstIndex(where: { $0.id == nodeId }) {
                let node = trees[treeIndex].branches[branchIndex].nodes[nodeIndex]
                
                trees[treeIndex].branches[branchIndex].nodes[nodeIndex].status = .completed
                trees[treeIndex].branches[branchIndex].nodes[nodeIndex].completedAt = Date()
                trees[treeIndex].branches[branchIndex].nodes[nodeIndex].completionNotes = notes
                
                stats.addXP(node.xpValue, linkedStats: node.linkedStats)
                
                unlockDependentNodes(completedNodeId: nodeId, in: treeId)
                
                saveTrees()
                saveStats()
                return
            }
        }
    }
    
    func startNode(nodeId: UUID, in treeId: UUID) {
        guard let treeIndex = trees.firstIndex(where: { $0.id == treeId }) else { return }
        
        for branchIndex in trees[treeIndex].branches.indices {
            if let nodeIndex = trees[treeIndex].branches[branchIndex].nodes.firstIndex(where: { $0.id == nodeId }) {
                if trees[treeIndex].branches[branchIndex].nodes[nodeIndex].status == .available {
                    trees[treeIndex].branches[branchIndex].nodes[nodeIndex].status = .inProgress
                    saveTrees()
                }
                return
            }
        }
    }
    
    private func unlockDependentNodes(completedNodeId: UUID, in treeId: UUID) {
        guard let treeIndex = trees.firstIndex(where: { $0.id == treeId }) else { return }
        
        for branchIndex in trees[treeIndex].branches.indices {
            for nodeIndex in trees[treeIndex].branches[branchIndex].nodes.indices {
                let node = trees[treeIndex].branches[branchIndex].nodes[nodeIndex]
                
                if node.status == .locked && node.prerequisites.contains(completedNodeId) {
                    let allPrereqsMet = node.prerequisites.allSatisfy { prereqId in
                        trees[treeIndex].allNodes.first { $0.id == prereqId }?.status == .completed
                    }
                    
                    if allPrereqsMet {
                        trees[treeIndex].branches[branchIndex].nodes[nodeIndex].status = .available
                    }
                }
            }
        }
    }
    
    var allAvailableNodes: [(node: SkillNode, tree: SkillTree)] {
        var result: [(SkillNode, SkillTree)] = []
        for tree in trees {
            for node in tree.availableNodes {
                result.append((node, tree))
            }
        }
        return result
    }
    
    // MARK: - Context
    
    func addContext(_ context: ContextSource) {
        contextSources.insert(context, at: 0)
        saveContext()
    }
    
    func deleteContext(_ context: ContextSource) {
        contextSources.removeAll { $0.id == context.id }
        saveContext()
    }
    
    // MARK: - Persistence
    
    private func saveGoals() {
        if let encoded = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(encoded, forKey: goalsKey)
        }
    }
    
    private func saveTrees() {
        if let encoded = try? JSONEncoder().encode(trees) {
            UserDefaults.standard.set(encoded, forKey: treesKey)
        }
    }
    
    private func saveContext() {
        if let encoded = try? JSONEncoder().encode(contextSources) {
            UserDefaults.standard.set(encoded, forKey: contextKey)
        }
    }
    
    private func saveStats() {
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: goalsKey),
           let decoded = try? JSONDecoder().decode([Goal].self, from: data) {
            goals = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: treesKey),
           let decoded = try? JSONDecoder().decode([SkillTree].self, from: data) {
            trees = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: contextKey),
           let decoded = try? JSONDecoder().decode([ContextSource].self, from: data) {
            contextSources = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let decoded = try? JSONDecoder().decode(UserStats.self, from: data) {
            stats = decoded
        }
    }
    
    // MARK: - Demo Data (for testing without backend)
    
    func createDemoTree(for goal: Goal) {
        let tier1Nodes = [
            SkillNode(
                title: "Research & Planning",
                description: "Define scope and research requirements",
                tier: 1,
                completionCriteria: ["Document requirements", "Create initial roadmap"],
                estimatedHours: 3,
                xpValue: 100,
                status: .available,
                linkedStats: ["INT", "WIS"]
            ),
            SkillNode(
                title: "Setup Development Environment",
                description: "Configure tools and dependencies",
                tier: 1,
                completionCriteria: ["Install dependencies", "Configure project"],
                estimatedHours: 2,
                xpValue: 75,
                status: .available,
                linkedStats: ["DEX"]
            )
        ]
        
        let tier2Nodes = [
            SkillNode(
                title: "Core Implementation",
                description: "Build the main functionality",
                tier: 2,
                prerequisites: [tier1Nodes[0].id, tier1Nodes[1].id],
                completionCriteria: ["Implement core features", "Write unit tests"],
                estimatedHours: 8,
                xpValue: 250,
                status: .locked,
                linkedStats: ["INT", "DEX"]
            )
        ]
        
        let tier3Nodes = [
            SkillNode(
                title: "Polish & Ship",
                description: "Final refinements and deployment",
                tier: 3,
                prerequisites: [tier2Nodes[0].id],
                completionCriteria: ["Fix remaining bugs", "Deploy to production"],
                estimatedHours: 4,
                xpValue: 300,
                status: .locked,
                linkedStats: ["WIS", "CHA"]
            )
        ]
        
        let branch = Branch(
            name: goal.title,
            nodes: tier1Nodes + tier2Nodes + tier3Nodes
        )
        
        let tree = SkillTree(
            goalId: goal.id,
            title: goal.title,
            branches: [branch]
        )
        
        addTree(tree)
    }
}
