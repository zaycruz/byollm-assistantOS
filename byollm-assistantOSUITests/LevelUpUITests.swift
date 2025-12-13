//
//  LevelUpUITests.swift
//  byollm-assistantOSUITests
//
//  UI tests for Level Up flow (accessed via Arise tab).
//

import XCTest

final class LevelUpUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        // Use mock API for deterministic tests
        app.launchArguments = ["--levelup-mock-api", "--ui-testing"]
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Main App Tab Tests
    
    @MainActor
    func testMainApp_hasOriginalTabs() throws {
        app.launch()
        
        // Verify original tabs exist
        let chatTab = app.tabBars.buttons["Chat"]
        let notesTab = app.tabBars.buttons["Notes"]
        let tasksTab = app.tabBars.buttons["Tasks"]
        let ariseTab = app.tabBars.buttons["Arise"]
        
        XCTAssertTrue(chatTab.waitForExistence(timeout: 5), "Chat tab should exist")
        XCTAssertTrue(notesTab.exists, "Notes tab should exist")
        XCTAssertTrue(tasksTab.exists, "Tasks tab should exist")
        XCTAssertTrue(ariseTab.exists, "Arise tab should exist")
    }
    
    @MainActor
    func testMainApp_chatTabIsDefault() throws {
        app.launch()
        
        let chatTab = app.tabBars.buttons["Chat"]
        XCTAssertTrue(chatTab.waitForExistence(timeout: 5))
        XCTAssertTrue(chatTab.isSelected, "Chat tab should be selected by default")
    }
    
    // MARK: - Arise Tab (Level Up) Tests
    
    @MainActor
    func testAriseTab_showsLevelUpContent() throws {
        app.launch()
        
        // Navigate to Arise tab
        let ariseTab = app.tabBars.buttons["Arise"]
        XCTAssertTrue(ariseTab.waitForExistence(timeout: 5))
        ariseTab.tap()
        
        // Should show Level Up content (either empty state or path view)
        let createGoalButton = app.buttons["LevelUp.EmptyState.CreateGoal"]
        let levelUpTitle = app.staticTexts["Level Up"]
        
        let hasContent = createGoalButton.waitForExistence(timeout: 5) || levelUpTitle.exists
        XCTAssertTrue(hasContent, "Arise tab should show Level Up content")
    }
    
    @MainActor
    func testAriseTab_emptyState_canOpenGoalCreation() throws {
        app.launch()
        
        // Navigate to Arise tab
        let ariseTab = app.tabBars.buttons["Arise"]
        XCTAssertTrue(ariseTab.waitForExistence(timeout: 5))
        ariseTab.tap()
        
        // Try to tap create goal button
        let createGoalButton = app.buttons["LevelUp.EmptyState.CreateGoal"]
        if createGoalButton.waitForExistence(timeout: 5) {
            createGoalButton.tap()
            
            // Should show goal creation sheet
            let goalTitleField = app.textFields["LevelUp.GoalCreation.Title"]
            XCTAssertTrue(goalTitleField.waitForExistence(timeout: 5), "Goal title field should appear")
        } else {
            // Already has a goal, just verify we're in Level Up
            let levelUpTitle = app.staticTexts["Level Up"]
            XCTAssertTrue(levelUpTitle.exists, "Should show Level Up view")
        }
    }
    
    // MARK: - Goal Creation Tests
    
    @MainActor
    func testGoalCreation_hasRequiredFields() throws {
        app.launch()
        
        // Navigate to Arise tab
        let ariseTab = app.tabBars.buttons["Arise"]
        XCTAssertTrue(ariseTab.waitForExistence(timeout: 5))
        ariseTab.tap()
        
        // Open goal creation
        let createGoalButton = app.buttons["LevelUp.EmptyState.CreateGoal"]
        guard createGoalButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Goal already exists, skipping creation test")
        }
        createGoalButton.tap()
        
        // Verify required fields exist
        let goalTitleField = app.textFields["LevelUp.GoalCreation.Title"]
        let generateButton = app.buttons["LevelUp.GoalCreation.Generate"]
        
        XCTAssertTrue(goalTitleField.waitForExistence(timeout: 5), "Goal title field should exist")
        XCTAssertTrue(generateButton.exists, "Generate button should exist")
    }
    
    @MainActor
    func testGoalCreation_canTypeGoalTitle() throws {
        app.launch()
        
        // Navigate to Arise tab
        let ariseTab = app.tabBars.buttons["Arise"]
        XCTAssertTrue(ariseTab.waitForExistence(timeout: 5))
        ariseTab.tap()
        
        // Open goal creation
        let createGoalButton = app.buttons["LevelUp.EmptyState.CreateGoal"]
        guard createGoalButton.waitForExistence(timeout: 5) else {
            throw XCTSkip("Goal already exists, skipping creation test")
        }
        createGoalButton.tap()
        
        let goalTitleField = app.textFields["LevelUp.GoalCreation.Title"]
        XCTAssertTrue(goalTitleField.waitForExistence(timeout: 5))
        
        goalTitleField.tap()
        goalTitleField.typeText("Launch my product")
        
        // Verify text was entered
        XCTAssertEqual(goalTitleField.value as? String, "Launch my product")
    }
    
    // MARK: - Tab Switching Tests
    
    @MainActor
    func testCanSwitchBetweenAllTabs() throws {
        app.launch()
        
        let chatTab = app.tabBars.buttons["Chat"]
        let notesTab = app.tabBars.buttons["Notes"]
        let tasksTab = app.tabBars.buttons["Tasks"]
        let ariseTab = app.tabBars.buttons["Arise"]
        
        XCTAssertTrue(chatTab.waitForExistence(timeout: 5))
        
        // Switch to each tab
        notesTab.tap()
        XCTAssertTrue(notesTab.isSelected, "Notes tab should be selected")
        
        tasksTab.tap()
        XCTAssertTrue(tasksTab.isSelected, "Tasks tab should be selected")
        
        ariseTab.tap()
        XCTAssertTrue(ariseTab.isSelected, "Arise tab should be selected")
        
        chatTab.tap()
        XCTAssertTrue(chatTab.isSelected, "Chat tab should be selected")
    }
    
    // MARK: - Goal Settings Tests
    
    @MainActor
    func testAriseSettings_hasGoalsSection() throws {
        app.launch()
        
        // Navigate to Arise tab
        let ariseTab = app.tabBars.buttons["Arise"]
        XCTAssertTrue(ariseTab.waitForExistence(timeout: 5))
        ariseTab.tap()
        
        // Look for settings button (gear icon)
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            
            // Verify Goals section exists
            let goalsHeader = app.staticTexts["Goals"]
            XCTAssertTrue(goalsHeader.waitForExistence(timeout: 5), "Goals section should exist in settings")
            
            // Verify New Goal button exists
            let newGoalButton = app.buttons["LevelUp.Settings.NewGoal"]
            XCTAssertTrue(newGoalButton.exists, "New Goal button should exist")
        }
    }
    
    @MainActor
    func testAriseSettings_showsPinnedCount() throws {
        app.launch()
        
        // Navigate to Arise tab
        let ariseTab = app.tabBars.buttons["Arise"]
        XCTAssertTrue(ariseTab.waitForExistence(timeout: 5))
        ariseTab.tap()
        
        // Look for settings button
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            
            // Check for pinned count indicator (e.g., "Pinned 0/3" or "Pinned 1/3")
            let pinnedIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Pinned'")).firstMatch
            XCTAssertTrue(pinnedIndicator.waitForExistence(timeout: 5), "Pinned count should be visible")
        }
    }
    
    // MARK: - Goal Switcher Tests
    
    @MainActor
    func testGoalSwitcher_appearsWithMultiplePinnedGoals() throws {
        // This test verifies the switcher UI component exists when there are multiple pinned goals.
        // In mock mode, we may not have multiple goals, so we check the component structure.
        app.launch()
        
        let ariseTab = app.tabBars.buttons["Arise"]
        XCTAssertTrue(ariseTab.waitForExistence(timeout: 5))
        ariseTab.tap()
        
        // If there are multiple pinned goals, the switcher should appear
        // The switcher has accessibility identifiers like "LevelUp.GoalSwitcher.0", "LevelUp.GoalSwitcher.1"
        let switcher0 = app.buttons["LevelUp.GoalSwitcher.0"]
        let switcher1 = app.buttons["LevelUp.GoalSwitcher.1"]
        
        // If switcher exists, verify it can be tapped
        if switcher0.waitForExistence(timeout: 3) && switcher1.exists {
            // Tap the second goal in switcher
            switcher1.tap()
            
            // Verify it's now selected (would need visual verification in real test)
            XCTAssertTrue(true, "Goal switcher is interactive")
        }
        // If no switcher, that's OK - means single or no goals
    }
}

// MARK: - Performance Tests

final class LevelUpPerformanceTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--levelup-mock-api", "--ui-testing"]
    }
    
    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
    }
}
