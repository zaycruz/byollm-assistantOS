import Foundation
import Testing
@testable import byollm_assistantOS

struct LevelUpAPIDecodingTests {
    @Test func decodesAuthResponse_withNoTimezoneExpiresAt() throws {
        let json = #"{"token":"t","expires_at":"2026-01-12T18:27:02","device_id":"dev"}"#
        let data = try #require(json.data(using: .utf8))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) { return date }
            if let date = ISO8601DateFormatter().withFractionalSeconds.date(from: string) { return date }
            if let date = LevelUpDateCoding.parseNoTimezoneFractional(string) { return date }
            if let date = LevelUpDateCoding.posixNoTZ.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }

        let decoded = try decoder.decode(LevelUpAuthResponse.self, from: data)
        #expect(decoded.token == "t")
        #expect(decoded.deviceID == "dev")
    }

    @Test func decodesGoalCreateResponse_withFractionalNoTimezoneCreatedAt() throws {
        let json = #"{"id":"186a09f8-7335-4850-bf69-5e08cff10bbb","title":"Launch my product","description":null,"target_date":null,"status":"active","created_at":"2025-12-13T18:29:21.349613","updated_at":"2025-12-13T18:29:21.349613","last_path_generated_at":null}"#
        let data = try #require(json.data(using: .utf8))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) { return date }
            if let date = ISO8601DateFormatter().withFractionalSeconds.date(from: string) { return date }
            if let date = LevelUpDateCoding.parseNoTimezoneFractional(string) { return date }
            if let date = LevelUpDateCoding.posixNoTZ.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }

        let decoded = try decoder.decode(LevelUpGoalResponse.self, from: data)
        #expect(decoded.id == "186a09f8-7335-4850-bf69-5e08cff10bbb")
        #expect(decoded.status == "active")
        #expect(decoded.createdAt.timeIntervalSince1970 > 0)
    }
    
    @Test func decodesJobStatusResponse_withIdField() throws {
        let json = #"""
        {
          "id":"e50d243f-2112-4d29-9823-abe1d6ce79bf",
          "goal_id":"a6b52e73-6d7e-483d-9b55-62b5c766bfa8",
          "plan_id":"8e3f9e09-2d6b-49d8-ad9d-a9a4d5be4441",
          "type":"initial",
          "status":"queued",
          "error":null,
          "plan_version_id":null,
          "diff_id":null,
          "started_at":null,
          "finished_at":null,
          "created_at":"2025-12-13T18:46:03.599698"
        }
        """#
        let data = try #require(json.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) { return date }
            if let date = ISO8601DateFormatter().withFractionalSeconds.date(from: string) { return date }
            if let date = LevelUpDateCoding.parseNoTimezoneFractional(string) { return date }
            if let date = LevelUpDateCoding.posixNoTZ.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        
        let decoded = try decoder.decode(LevelUpJobStatusResponse.self, from: data)
        #expect(decoded.jobID == "e50d243f-2112-4d29-9823-abe1d6ce79bf")
        #expect(decoded.status == "queued")
        #expect(decoded.planID == "8e3f9e09-2d6b-49d8-ad9d-a9a4d5be4441")
    }
    
    @Test func decodesPlanVersionResponse_withPlanIdPromptHashRawResponse() throws {
        let json = #"""
        {
          "id":"470e4411-0c07-4b2f-a653-9f1b754a615e",
          "plan_id":"2f26e2c9-f9d4-458c-8557-d19206b201d2",
          "version":1,
          "prompt_hash":"f7416777143473a4",
          "raw_response":{"plan":{"title":"T","deadline_days":108}},
          "created_at":"2025-12-13T18:46:03.599698",
          "objectives":[],
          "dependencies":[]
        }
        """#
        let data = try #require(json.data(using: .utf8))
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) { return date }
            if let date = ISO8601DateFormatter().withFractionalSeconds.date(from: string) { return date }
            if let date = LevelUpDateCoding.parseNoTimezoneFractional(string) { return date }
            if let date = LevelUpDateCoding.posixNoTZ.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        
        let decoded = try decoder.decode(LevelUpPlanVersionResponse.self, from: data)
        #expect(decoded.planId == "2f26e2c9-f9d4-458c-8557-d19206b201d2")
        #expect(decoded.promptHash == "f7416777143473a4")
        #expect(decoded.rawResponse?["plan"] != nil)
    }
}

private extension ISO8601DateFormatter {
    var withFractionalSeconds: ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }
}
