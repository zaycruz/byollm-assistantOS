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
    
    @Test func personalizationSystemPrompt_includesUserInfoAndPreferences() async throws {
        let settings = PersonalizationSettings(
            fullName: "John Doe",
            nickname: "JD",
            personalPreferences: "Push me to be better. Always reference other chats."
        )
        
        let prompt = settings.systemPrompt()
        
        #expect(prompt.contains("About the user:"))
        #expect(prompt.contains("Name: John Doe"))
        #expect(prompt.contains("Nickname: JD"))
        #expect(prompt.contains("User preferences:"))
        #expect(prompt.contains("Push me to be better"))
    }
    
    @Test func personalizationStore_roundTripPersists() async throws {
        let suiteName = "byollm-assistantOS.tests.personalization"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        
        let store = PersonalizationStore(defaults: defaults)
        let original = PersonalizationSettings(
            fullName: "Test User",
            nickname: "Tester",
            personalPreferences: "Always be concise."
        )
        
        store.save(original)
        let loaded = store.load()
        
        #expect(loaded == original)
        #expect(defaults.string(forKey: "systemPrompt") == original.systemPrompt())
    }

}
