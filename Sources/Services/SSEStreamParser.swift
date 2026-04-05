import Foundation

enum SSEStreamParser {
    /// Parse a single SSE line and extract content delta
    static func parseContentDelta(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !jsonString.isEmpty, jsonString != "[DONE]" else { return nil }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }

    /// Parse Claude SSE format (different from OpenAI)
    static func parseClaudeContentDelta(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let jsonString = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !jsonString.isEmpty else { return nil }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // Claude uses "content_block_delta" event type
        if let type = json["type"] as? String,
           type == "content_block_delta",
           let delta = json["delta"] as? [String: Any],
           let text = delta["text"] as? String {
            return text
        }
        return nil
    }
}
