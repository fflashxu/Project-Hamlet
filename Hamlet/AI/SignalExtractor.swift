import Foundation

// MARK: - Shared Prompt

private let systemPrompt = """
You are an expert at analyzing human behavior and mapping it to capability dimensions.

Given a personal journal entry or description of events, identify which of the following capability dimensions are evidenced by specific behaviors described in the text.

Dimensions to analyze:
- get_things_done: Finding ways to make things happen, overcoming obstacles
- see_further: Thinking beyond the immediate, seeing larger patterns
- push_change: Challenging status quo, initiating change
- move_others: Getting people to act, inspiring or leading others
- navigate_resistance: Influencing without formal authority, building consensus
- grow_people: Helping others develop, coaching, mentoring
- read_needs: Sensing what others truly need, empathy in action
- stay_true: Acting according to values under pressure, authenticity
- bridge_difference: Building trust across cultural/background differences
- create_value: Turning ideas into things others find valuable
- read_the_room: Understanding underlying dynamics and power structures
- make_something: Creating from scratch, building new things
- self_regulate: Managing own emotions and state effectively
- stay_curious: Exploring unknown territory, learning-driven behavior
- think_in_systems: Seeing connections between disparate elements

For each dimension you identify:
1. Only include it if there is clear behavioral evidence in the text
2. Assign a strength score 0.1-1.0 based on how clearly/strongly it is demonstrated
3. Quote the specific phrase or sentence that is the evidence

Return ONLY a valid JSON array. No explanation, no markdown. Example:
[
  {"dimension_id": "navigate_resistance", "strength": 0.72, "evidence": "convinced the engineering team to accept a new technical approach despite initial resistance"},
  {"dimension_id": "move_others", "strength": 0.45, "evidence": "led a cross-department meeting"}
]

If no dimensions are clearly evidenced, return an empty array: []
"""

private func buildUserMessage(_ text: String, additionalContext: String = "") -> String {
    var msg = "Journal entry to analyze:\n\n\(text)"
    if !additionalContext.isEmpty {
        msg += "\n\n---\nAdditional context from attached content:\n\(additionalContext)"
    }
    return msg
}

// MARK: - Claude Provider

struct ClaudeProvider: AIProvider {
    let name = "Claude"
    let requiresAPIKey = true

    func extractSignals(from text: String) async throws -> [SignalData] {
        try await extractSignals(from: text, additionalContext: "")
    }

    func extractSignals(from text: String, additionalContext: String) async throws -> [SignalData] {
        guard let apiKey = APIKeyStore.shared.get(for: .claude) else {
            throw AIError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": AIProviderType.claude.defaultModel,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": buildUserMessage(text, additionalContext: additionalContext)]
            ]
        ]

        var request = URLRequest(url: URL(string: AIProviderType.claude.baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw AIError.rateLimited
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AIError.networkError("Status \(http.statusCode)")
        }

        return try parseClaudeResponse(data)
    }

    private func parseClaudeResponse(_ data: Data) throws -> [SignalData] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String
        else { throw AIError.parseError }

        return try parseSignalJSON(text)
    }
}

// MARK: - Qwen Provider

struct QwenProvider: AIProvider {
    let name = "Qwen"
    let requiresAPIKey = true

    func extractSignals(from text: String) async throws -> [SignalData] {
        try await extractSignals(from: text, additionalContext: "")
    }

    func extractSignals(from text: String, additionalContext: String) async throws -> [SignalData] {
        guard let apiKey = APIKeyStore.shared.get(for: .qwen) else {
            throw AIError.missingAPIKey
        }

        let body: [String: Any] = [
            "model": AIProviderType.qwen.defaultModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": buildUserMessage(text, additionalContext: additionalContext)]
            ],
            "max_tokens": 1024
        ]

        var request = URLRequest(url: URL(string: AIProviderType.qwen.baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 429 {
            throw AIError.rateLimited
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AIError.networkError("Status \(http.statusCode)")
        }

        return try parseOpenAICompatibleResponse(data)
    }

    private func parseOpenAICompatibleResponse(_ data: Data) throws -> [SignalData] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let text = message["content"] as? String
        else { throw AIError.parseError }

        return try parseSignalJSON(text)
    }
}

// MARK: - Shared JSON Parser

private func parseSignalJSON(_ text: String) throws -> [SignalData] {
    // Find JSON array in response, handle markdown code blocks
    var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if jsonText.hasPrefix("```") {
        let lines = jsonText.components(separatedBy: "\n")
        jsonText = lines.dropFirst().dropLast().joined(separator: "\n")
    }

    guard let startIdx = jsonText.firstIndex(of: "["),
          let endIdx = jsonText.lastIndex(of: "]")
    else { return [] }

    let jsonSlice = String(jsonText[startIdx...endIdx])
    guard let data = jsonSlice.data(using: .utf8) else { throw AIError.parseError }

    let signals = try JSONDecoder().decode([SignalData].self, from: data)

    // Validate dimension IDs against framework
    let validIds = Set(HamletFramework.shared.dimensions.map { $0.id })
    return signals.filter { validIds.contains($0.dimensionId) }
}
