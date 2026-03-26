import Foundation

final class ChatStore: ObservableObject {
    @Published private(set) var sessions: [ChatSession] = []

    private let fileURL: URL
    private let queue = DispatchQueue(label: "ChatStore", qos: .userInitiated)

    init(baseURL: URL? = nil) {
        let directory: URL
        if let baseURL {
            directory = baseURL
        } else {
            directory = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
        fileURL = directory.appendingPathComponent("chat-sessions.json")
        load()
    }

    @discardableResult
    func createSession() -> ChatSession {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        persist()
        return session
    }

    func addMessage(_ message: ChatMessage, toSessionId sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].messages.append(message)
        sessions[index].updatedAt = Date()
        if sessions[index].title == "新对话",
           message.role == .user {
            let title = String(message.content.prefix(20))
            sessions[index].title = title.isEmpty ? "新对话" : title
        }
        persist()
    }

    func deleteSession(_ sessionId: UUID) {
        sessions.removeAll { $0.id == sessionId }
        persist()
    }

    func updateSessionTitle(_ sessionId: UUID, title: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].title = title
        persist()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
        } catch {
            print("Failed to load chat sessions: \(error)")
            sessions = []
        }
    }

    private func persist() {
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let data = try JSONEncoder().encode(self.sessions)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                assertionFailure("Failed to save chat sessions: \(error)")
            }
        }
    }
}
