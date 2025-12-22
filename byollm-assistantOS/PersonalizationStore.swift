import Foundation

struct PersonalizationSettings: Codable, Equatable {
    var fullName: String
    var nickname: String
    var personalPreferences: String
    
    init(
        fullName: String = "",
        nickname: String = "",
        personalPreferences: String = ""
    ) {
        self.fullName = fullName
        self.nickname = nickname
        self.personalPreferences = personalPreferences
    }
    
    /// The system prompt that should be sent as the first "system" message.
    func systemPrompt() -> String {
        var lines: [String] = []
        
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !trimmedName.isEmpty || !trimmedNickname.isEmpty {
            lines.append("About the user:")
            if !trimmedName.isEmpty {
                lines.append("- Name: \(trimmedName)")
            }
            if !trimmedNickname.isEmpty {
                lines.append("- Nickname: \(trimmedNickname)")
            }
        }
        
        let trimmedPreferences = personalPreferences.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPreferences.isEmpty {
            if !lines.isEmpty {
                lines.append("")
            }
            lines.append("User preferences:")
            lines.append(trimmedPreferences)
        }
        
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PersonalizationStore {
    private enum Keys {
        static let settingsData = "personalizationSettings"
        static let legacySystemPrompt = "systemPrompt"
    }
    
    var defaults: UserDefaults = .standard
    
    func load() -> PersonalizationSettings {
        if let data = defaults.data(forKey: Keys.settingsData),
           let decoded = try? JSONDecoder().decode(PersonalizationSettings.self, from: data) {
            return decoded
        }
        
        // Migration: preserve any legacy system prompt as personal preferences
        if let legacy = defaults.string(forKey: Keys.legacySystemPrompt),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return PersonalizationSettings(personalPreferences: legacy)
        }
        
        return PersonalizationSettings()
    }
    
    func save(_ settings: PersonalizationSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.settingsData)
        }
        
        // Keep `systemPrompt` in sync for the chat request pipeline.
        defaults.set(settings.systemPrompt(), forKey: Keys.legacySystemPrompt)
    }
}

