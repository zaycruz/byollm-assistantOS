import Foundation

enum AssistantBaseStyle: String, CaseIterable, Identifiable, Codable, Equatable {
    case defaultStyle = "Default"
    case professional = "Professional"
    case friendly = "Friendly"
    case candid = "Candid"
    case quirky = "Quirky"
    case efficient = "Efficient"
    case nerdy = "Nerdy"
    case cynical = "Cynical"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .defaultStyle: return "Balanced style and tone"
        case .professional: return "Polished and precise"
        case .friendly: return "Warm and chatty"
        case .candid: return "Direct and encouraging"
        case .quirky: return "Playful and imaginative"
        case .efficient: return "Concise and plain"
        case .nerdy: return "Exploratory and enthusiastic"
        case .cynical: return "Critical and sarcastic"
        }
    }
}

struct PersonalizationSettings: Codable, Equatable {
    var baseStyle: AssistantBaseStyle
    var customInstructions: String
    var occupation: String
    var moreAboutYou: String
    
    init(
        baseStyle: AssistantBaseStyle = .nerdy,
        customInstructions: String = "",
        occupation: String = "",
        moreAboutYou: String = ""
    ) {
        self.baseStyle = baseStyle
        self.customInstructions = customInstructions
        self.occupation = occupation
        self.moreAboutYou = moreAboutYou
    }
    
    /// The system prompt that should be sent as the first "system" message.
    func systemPrompt() -> String {
        var lines: [String] = []
        
        // Style + tone
        lines.append("Style: \(baseStyle.rawValue) — \(baseStyle.description)")
        
        // Instructions
        let trimmedInstructions = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInstructions.isEmpty {
            lines.append("")
            lines.append("Instructions:")
            lines.append(trimmedInstructions)
        }
        
        // About me
        let trimmedOccupation = occupation.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMore = moreAboutYou.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOccupation.isEmpty || !trimmedMore.isEmpty {
            lines.append("")
            lines.append("About me:")
            if !trimmedOccupation.isEmpty {
                lines.append("- Occupation: \(trimmedOccupation)")
            }
            if !trimmedMore.isEmpty {
                lines.append("- More: \(trimmedMore)")
            }
        }
        
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        // Migration path from legacy single-string prompt.
        if let legacy = defaults.string(forKey: Keys.legacySystemPrompt),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return migrateFromLegacySystemPrompt(legacy)
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
    
    private func migrateFromLegacySystemPrompt(_ prompt: String) -> PersonalizationSettings {
        // Best-effort parse of historical formats used by older builds.
        // If parsing fails, preserve the full string as `customInstructions`.
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: .newlines)
        
        var baseStyle: AssistantBaseStyle = .nerdy
        var customInstructions = ""
        var occupation = ""
        var more = ""
        
        func value(after prefix: String, in line: String) -> String? {
            guard line.lowercased().hasPrefix(prefix.lowercased()) else { return nil }
            return line.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        for line in lines {
            if let styleLine = value(after: "Style:", in: line) {
                // Handle both "Style: X - ..." and "Style: X — ..."
                let styleName = styleLine
                    .components(separatedBy: " - ").first?
                    .components(separatedBy: " — ").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? styleLine
                if let matched = AssistantBaseStyle.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(styleName) == .orderedSame }) {
                    baseStyle = matched
                }
            } else if let occ = value(after: "User's occupation:", in: line) ?? value(after: "Occupation:", in: line) {
                occupation = occ
            } else if let m = value(after: "More about user:", in: line) ?? value(after: "More about you:", in: line) ?? value(after: "More:", in: line) {
                more = m
            }
        }
        
        // Try to extract an "Instructions:" block (which may span multiple lines).
        if let instructionsStart = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("instructions:") }) {
            let firstLine = lines[instructionsStart]
            let firstRemainder = firstLine.dropFirst("Instructions:".count).trimmingCharacters(in: .whitespaces)
            
            var collected: [String] = []
            if !firstRemainder.isEmpty {
                collected.append(firstRemainder)
            }
            
            // Collect until we hit another known field header.
            if instructionsStart + 1 < lines.count {
                for i in (instructionsStart + 1)..<lines.count {
                    let l = lines[i]
                    let lower = l.trimmingCharacters(in: .whitespaces).lowercased()
                    if lower.hasPrefix("user's occupation:") ||
                        lower.hasPrefix("occupation:") ||
                        lower.hasPrefix("more about user:") ||
                        lower.hasPrefix("more about you:") ||
                        lower.hasPrefix("user's nickname:") ||
                        lower.hasPrefix("style:") {
                        break
                    }
                    collected.append(l)
                }
            }
            
            customInstructions = collected.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // No structured marker; preserve everything as custom instructions.
            customInstructions = trimmed
        }
        
        return PersonalizationSettings(
            baseStyle: baseStyle,
            customInstructions: customInstructions,
            occupation: occupation,
            moreAboutYou: more
        )
    }
}

