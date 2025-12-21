//
//  byollm_assistantOSTests.swift
//  byollm-assistantOSTests
//
//  Created by master on 11/16/25.
//

import Testing
import Foundation
@testable import byollm_assistantOS

struct byollm_assistantOSTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func personalizationSystemPrompt_includesAboutMeAndInstructions() async throws {
        let settings = PersonalizationSettings(
            baseStyle: .nerdy,
            customInstructions: "Be direct.\nPrefer bullets.",
            occupation: "Engineer",
            moreAboutYou: "I like writing code in Python."
        )
        
        let prompt = settings.systemPrompt()
        
        #expect(prompt.contains("Style: Nerdy"))
        #expect(prompt.contains("Instructions:"))
        #expect(prompt.contains("Be direct."))
        #expect(prompt.contains("About me:"))
        #expect(prompt.contains("Occupation: Engineer"))
        #expect(prompt.contains("I like writing code in Python."))
        
        // Regression: nickname removed
        #expect(!prompt.lowercased().contains("nickname"))
    }
    
    @Test func personalizationStore_roundTripPersists() async throws {
        let suiteName = "byollm-assistantOS.tests.personalization"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        
        let store = PersonalizationStore(defaults: defaults)
        let original = PersonalizationSettings(
            baseStyle: .candid,
            customInstructions: "Always be concise.",
            occupation: "Student",
            moreAboutYou: "Interested in ML."
        )
        
        store.save(original)
        let loaded = store.load()
        
        #expect(loaded == original)
        #expect(defaults.string(forKey: "systemPrompt") == original.systemPrompt())
    }

}
