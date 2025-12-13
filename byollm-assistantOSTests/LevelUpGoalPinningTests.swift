//
//  LevelUpGoalPinningTests.swift
//  byollm-assistantOSTests
//
//  Tests for LevelUp goal pinning mechanics (max 3 pinned goals).
//

import Foundation
import Testing
@testable import byollm_assistantOS

struct LevelUpGoalPinningTests {
    
    // MARK: - Helper
    
    private func createGoal(title: String, isPinned: Bool = false, pinnedAt: Date? = nil) -> LevelUpGoal {
        LevelUpGoal(
            title: title,
            isPinned: isPinned,
            pinnedAt: pinnedAt
        )
    }
    
    // MARK: - Pinning Tests
    
    @Test func pin_singleGoal_setsIsPinnedAndPinnedAt() {
        let goal = createGoal(title: "Goal 1")
        let allGoals = [goal]
        
        LevelUpGoalPinning.pin(goal, allGoals: allGoals)
        
        #expect(goal.isPinned == true)
        #expect(goal.pinnedAt != nil)
    }
    
    @Test func pin_alreadyPinned_noChange() {
        let now = Date()
        let goal = createGoal(title: "Goal 1", isPinned: true, pinnedAt: now)
        let allGoals = [goal]
        
        let unpinned = LevelUpGoalPinning.pin(goal, allGoals: allGoals)
        
        #expect(unpinned == nil)
        #expect(goal.isPinned == true)
        #expect(goal.pinnedAt == now)
    }
    
    @Test func pin_underMax_pinsWithoutUnpinning() {
        let goal1 = createGoal(title: "Goal 1", isPinned: true, pinnedAt: Date().addingTimeInterval(-100))
        let goal2 = createGoal(title: "Goal 2", isPinned: true, pinnedAt: Date().addingTimeInterval(-50))
        let goal3 = createGoal(title: "Goal 3")
        let allGoals = [goal1, goal2, goal3]
        
        let unpinned = LevelUpGoalPinning.pin(goal3, allGoals: allGoals)
        
        #expect(unpinned == nil)
        #expect(goal1.isPinned == true)
        #expect(goal2.isPinned == true)
        #expect(goal3.isPinned == true)
    }
    
    @Test func pin_atMax_unpinsOldest() {
        let oldest = createGoal(title: "Oldest", isPinned: true, pinnedAt: Date().addingTimeInterval(-300))
        let middle = createGoal(title: "Middle", isPinned: true, pinnedAt: Date().addingTimeInterval(-200))
        let recent = createGoal(title: "Recent", isPinned: true, pinnedAt: Date().addingTimeInterval(-100))
        let newGoal = createGoal(title: "New Goal")
        let allGoals = [oldest, middle, recent, newGoal]
        
        let unpinned = LevelUpGoalPinning.pin(newGoal, allGoals: allGoals)
        
        #expect(unpinned?.title == "Oldest")
        #expect(oldest.isPinned == false)
        #expect(oldest.pinnedAt == nil)
        #expect(middle.isPinned == true)
        #expect(recent.isPinned == true)
        #expect(newGoal.isPinned == true)
    }
    
    @Test func unpin_pinnedGoal_clearsFields() {
        let goal = createGoal(title: "Goal 1", isPinned: true, pinnedAt: Date())
        
        LevelUpGoalPinning.unpin(goal)
        
        #expect(goal.isPinned == false)
        #expect(goal.pinnedAt == nil)
    }
    
    @Test func unpin_unpinnedGoal_noChange() {
        let goal = createGoal(title: "Goal 1", isPinned: false, pinnedAt: nil)
        
        LevelUpGoalPinning.unpin(goal)
        
        #expect(goal.isPinned == false)
        #expect(goal.pinnedAt == nil)
    }
    
    // MARK: - pinnedGoals Tests
    
    @Test func pinnedGoals_returnsOnlyPinned() {
        let pinned1 = createGoal(title: "Pinned 1", isPinned: true, pinnedAt: Date())
        let pinned2 = createGoal(title: "Pinned 2", isPinned: true, pinnedAt: Date())
        let unpinned = createGoal(title: "Unpinned", isPinned: false)
        let allGoals = [pinned1, unpinned, pinned2]
        
        let result = LevelUpGoalPinning.pinnedGoals(from: allGoals)
        
        #expect(result.count == 2)
        #expect(result.contains { $0.title == "Pinned 1" })
        #expect(result.contains { $0.title == "Pinned 2" })
        #expect(!result.contains { $0.title == "Unpinned" })
    }
    
    @Test func pinnedGoals_sortedByMostRecentFirst() {
        let oldest = createGoal(title: "Oldest", isPinned: true, pinnedAt: Date().addingTimeInterval(-300))
        let middle = createGoal(title: "Middle", isPinned: true, pinnedAt: Date().addingTimeInterval(-200))
        let recent = createGoal(title: "Recent", isPinned: true, pinnedAt: Date().addingTimeInterval(-100))
        let allGoals = [middle, oldest, recent]
        
        let result = LevelUpGoalPinning.pinnedGoals(from: allGoals)
        
        #expect(result.count == 3)
        #expect(result[0].title == "Recent")
        #expect(result[1].title == "Middle")
        #expect(result[2].title == "Oldest")
    }
    
    // MARK: - autoPinIfNeeded Tests
    
    @Test func autoPinIfNeeded_noPinned_pinsMostRecent() {
        let older = createGoal(title: "Older")
        older.createdAt = Date().addingTimeInterval(-1000)
        
        let newer = createGoal(title: "Newer")
        newer.createdAt = Date()
        
        let allGoals = [older, newer]
        
        let didAutoPin = LevelUpGoalPinning.autoPinIfNeeded(activeGoals: allGoals)
        
        #expect(didAutoPin == true)
        #expect(newer.isPinned == true)
        #expect(older.isPinned == false)
    }
    
    @Test func autoPinIfNeeded_alreadyHasPinned_doesNothing() {
        let pinned = createGoal(title: "Already Pinned", isPinned: true, pinnedAt: Date())
        let unpinned = createGoal(title: "Unpinned")
        let allGoals = [pinned, unpinned]
        
        let didAutoPin = LevelUpGoalPinning.autoPinIfNeeded(activeGoals: allGoals)
        
        #expect(didAutoPin == false)
        #expect(unpinned.isPinned == false)
    }
    
    @Test func autoPinIfNeeded_emptyList_returnsFalse() {
        let didAutoPin = LevelUpGoalPinning.autoPinIfNeeded(activeGoals: [])
        
        #expect(didAutoPin == false)
    }
    
    // MARK: - Max Pinned Constant
    
    @Test func maxPinnedGoals_is3() {
        #expect(LevelUpGoalPinning.maxPinnedGoals == 3)
    }
}
