//
//  LevelUpProgressionTests.swift
//  byollm-assistantOSTests
//
//  Tests for Level Up progression mechanics (points, levels, streaks).
//

import Foundation
import Testing
@testable import byollm_assistantOS

struct LevelUpProgressionTests {
    
    // MARK: - Points for Level
    
    @Test func pointsForLevel_level1_returns100() {
        let points = LevelUpProgression.pointsForLevel(1)
        #expect(points == 100)
    }
    
    @Test func pointsForLevel_level2_returns400() {
        let points = LevelUpProgression.pointsForLevel(2)
        #expect(points == 400)
    }
    
    @Test func pointsForLevel_level5_returns2500() {
        let points = LevelUpProgression.pointsForLevel(5)
        #expect(points == 2500)
    }
    
    @Test func pointsForLevel_level10_returns10000() {
        let points = LevelUpProgression.pointsForLevel(10)
        #expect(points == 10000)
    }
    
    @Test func pointsForLevel_zeroOrNegative_clampsTo1() {
        let pointsZero = LevelUpProgression.pointsForLevel(0)
        let pointsNeg = LevelUpProgression.pointsForLevel(-5)
        #expect(pointsZero == 100)
        #expect(pointsNeg == 100)
    }
    
    // MARK: - Level for Total Points
    
    @Test func levelForPoints_0_returns1() {
        let level = LevelUpProgression.level(forTotalPoints: 0)
        #expect(level == 1)
    }
    
    @Test func levelForPoints_99_returns1() {
        let level = LevelUpProgression.level(forTotalPoints: 99)
        #expect(level == 1) // Not yet at 100
    }
    
    @Test func levelForPoints_100_returns1() {
        let level = LevelUpProgression.level(forTotalPoints: 100)
        #expect(level == 1)
    }
    
    @Test func levelForPoints_399_returns1() {
        let level = LevelUpProgression.level(forTotalPoints: 399)
        #expect(level == 1)
    }
    
    @Test func levelForPoints_400_returns2() {
        let level = LevelUpProgression.level(forTotalPoints: 400)
        #expect(level == 2)
    }
    
    @Test func levelForPoints_2500_returns5() {
        let level = LevelUpProgression.level(forTotalPoints: 2500)
        #expect(level == 5)
    }
    
    @Test func levelForPoints_negative_returns1() {
        let level = LevelUpProgression.level(forTotalPoints: -100)
        #expect(level == 1)
    }
    
    // MARK: - Points to Next Level
    
    @Test func pointsToNextLevel_level1_0points_returns400() {
        // Level 2 starts at 400, so 400 - 0 = 400
        let toNext = LevelUpProgression.pointsToNextLevel(level: 1, totalPoints: 0)
        #expect(toNext == 400)
    }
    
    @Test func pointsToNextLevel_level1_200points_returns200() {
        let toNext = LevelUpProgression.pointsToNextLevel(level: 1, totalPoints: 200)
        #expect(toNext == 200)
    }
    
    @Test func pointsToNextLevel_level2_400points_returns500() {
        // Level 3 starts at 900, so 900 - 400 = 500
        let toNext = LevelUpProgression.pointsToNextLevel(level: 2, totalPoints: 400)
        #expect(toNext == 500)
    }
    
    // MARK: - Streak Updates
    
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }
    
    private func fixedDate() -> Date {
        // 2025-12-13T12:00:00Z
        Date(timeIntervalSince1970: 1_765_645_200)
    }
    
    @Test func updateStreak_noLastActivity_startsAt1() {
        let result = LevelUpProgression.updateStreak(
            currentStreak: 0,
            longestStreak: 0,
            lastActivityDate: nil,
            now: fixedDate(),
            calendar: utcCalendar()
        )
        
        #expect(result.current == 1)
        #expect(result.longest == 1)
        #expect(result.lastActivityDate == fixedDate())
    }
    
    @Test func updateStreak_sameDay_noChange() {
        let now = fixedDate()
        let earlier = now.addingTimeInterval(-3600) // 1 hour ago
        
        let result = LevelUpProgression.updateStreak(
            currentStreak: 5,
            longestStreak: 10,
            lastActivityDate: earlier,
            now: now,
            calendar: utcCalendar()
        )
        
        #expect(result.current == 5)
        #expect(result.longest == 10)
    }
    
    @Test func updateStreak_consecutiveDay_incrementsStreak() {
        let cal = utcCalendar()
        let now = fixedDate()
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        
        let result = LevelUpProgression.updateStreak(
            currentStreak: 5,
            longestStreak: 10,
            lastActivityDate: yesterday,
            now: now,
            calendar: cal
        )
        
        #expect(result.current == 6)
        #expect(result.longest == 10) // Didn't beat longest
    }
    
    @Test func updateStreak_consecutiveDay_updatesLongestIfBeaten() {
        let cal = utcCalendar()
        let now = fixedDate()
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        
        let result = LevelUpProgression.updateStreak(
            currentStreak: 10,
            longestStreak: 10,
            lastActivityDate: yesterday,
            now: now,
            calendar: cal
        )
        
        #expect(result.current == 11)
        #expect(result.longest == 11)
    }
    
    @Test func updateStreak_brokenStreak_resetsTo1() {
        let cal = utcCalendar()
        let now = fixedDate()
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: now)!
        
        let result = LevelUpProgression.updateStreak(
            currentStreak: 7,
            longestStreak: 10,
            lastActivityDate: twoDaysAgo,
            now: now,
            calendar: cal
        )
        
        #expect(result.current == 1)
        #expect(result.longest == 10) // Longest preserved
    }
    
    @Test func updateStreak_longGap_resetsButPreservesLongest() {
        let cal = utcCalendar()
        let now = fixedDate()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!
        
        let result = LevelUpProgression.updateStreak(
            currentStreak: 20,
            longestStreak: 20,
            lastActivityDate: weekAgo,
            now: now,
            calendar: cal
        )
        
        #expect(result.current == 1)
        #expect(result.longest == 20)
    }
}

// MARK: - Objective Grouping Tests

struct LevelUpObjectiveGroupingTests {
    
    @Test func formattedEstimate_lessThan1Hour() {
        // 0.5 hours = 30 minutes
        let objective = createMockObjective(estimatedHours: 0.5)
        #expect(objective.formattedEstimate == "30m")
    }
    
    @Test func formattedEstimate_exactHours() {
        let objective = createMockObjective(estimatedHours: 2.0)
        #expect(objective.formattedEstimate == "2h")
    }
    
    @Test func formattedEstimate_hoursAndMinutes() {
        let objective = createMockObjective(estimatedHours: 1.5)
        #expect(objective.formattedEstimate == "1h 30m")
    }
    
    @Test func formattedEstimate_zeroHours() {
        let objective = createMockObjective(estimatedHours: 0)
        #expect(objective.formattedEstimate == "0m")
    }
    
    private func createMockObjective(estimatedHours: Double) -> LevelUpObjective {
        LevelUpObjective(
            title: "Test",
            objectiveDescription: "Test description",
            estimatedHours: estimatedHours,
            pointsValue: 100,
            tier: "Foundation",
            position: 0
        )
    }
}

// MARK: - Goal Progress Tests

struct LevelUpGoalProgressTests {
    
    @Test func progressPercentage_noObjectives_returns0() {
        let goal = LevelUpGoal(title: "Test Goal")
        #expect(goal.progressPercentage == 0)
    }
    
    @Test func progressPercentage_allComplete_returns1() {
        let goal = LevelUpGoal(title: "Test Goal")
        
        let obj1 = LevelUpObjective(
            title: "Obj 1",
            objectiveDescription: "",
            estimatedHours: 1,
            pointsValue: 100,
            tier: "Foundation",
            position: 0,
            status: .completed
        )
        let obj2 = LevelUpObjective(
            title: "Obj 2",
            objectiveDescription: "",
            estimatedHours: 1,
            pointsValue: 100,
            tier: "Foundation",
            position: 1,
            status: .completed
        )
        
        goal.objectives = [obj1, obj2]
        
        #expect(goal.progressPercentage == 1.0)
    }
    
    @Test func progressPercentage_halfComplete_returns0_5() {
        let goal = LevelUpGoal(title: "Test Goal")
        
        let obj1 = LevelUpObjective(
            title: "Obj 1",
            objectiveDescription: "",
            estimatedHours: 1,
            pointsValue: 100,
            tier: "Foundation",
            position: 0,
            status: .completed
        )
        let obj2 = LevelUpObjective(
            title: "Obj 2",
            objectiveDescription: "",
            estimatedHours: 1,
            pointsValue: 100,
            tier: "Foundation",
            position: 1,
            status: .available
        )
        
        goal.objectives = [obj1, obj2]
        
        #expect(goal.progressPercentage == 0.5)
    }
}
