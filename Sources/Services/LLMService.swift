import Foundation
import UIKit

final class LLMService: ObservableObject {
    @Published var providers: [ProviderConfig] = []
    @Published var activeProviderID: UUID?

    private let fileURL: URL
    private let queue = DispatchQueue(label: "LLMService", qos: .userInitiated)

    var activeProvider: ProviderConfig? {
        if let id = activeProviderID {
            return providers.first { $0.id == id }
        }
        return providers.first { $0.isDefault && $0.isEnabled }
            ?? providers.first { $0.isEnabled }
    }

    var isConfigured: Bool {
        activeProvider?.isConfigured ?? false
    }

    init() {
        let directory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        fileURL = directory.appendingPathComponent("ai-providers.json")
        load()
        seedBuiltInsIfNeeded()
    }

    // MARK: - Provider CRUD

    func addProvider(_ config: ProviderConfig) {
        providers.append(config)
        persist()
    }

    func updateProvider(_ config: ProviderConfig) {
        guard let index = providers.firstIndex(where: { $0.id == config.id }) else { return }
        providers[index] = config
        persist()
    }

    func deleteProvider(_ id: UUID) {
        guard let config = providers.first(where: { $0.id == id }) else { return }
        guard !config.isBuiltIn else { return }
        KeychainHelper.delete(key: "provider_\(id)")
        providers.removeAll { $0.id == id }
        persist()
    }

    func setDefault(_ id: UUID) {
        for i in providers.indices {
            providers[i].isDefault = (providers[i].id == id)
        }
        persist()
    }

    func setActiveProvider(_ id: UUID?) {
        activeProviderID = id
    }

    // MARK: - Provider Factory

    func makeActiveProvider() -> (any AIProvider)? {
        guard let config = activeProvider else { return nil }
        return makeProvider(from: config)
    }

    // MARK: - Streaming Chat (convenience)

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        guard let provider = makeActiveProvider() else {
            return AsyncThrowingStream { $0.finish(throwing: AIServiceError.notConfigured) }
        }

        let tuples = messages.map { (role: $0.role.rawValue, content: $0.content) }
        return provider.chatStream(messages: tuples, systemPrompt: nil)
    }

    func analyzeImage(_ image: UIImage, prompt: String) -> AsyncThrowingStream<String, Error> {
        guard let provider = makeActiveProvider() else {
            return AsyncThrowingStream { $0.finish(throwing: AIServiceError.notConfigured) }
        }

        if provider.supportsVision {
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let result = try await provider.analyzeImage(image, prompt: prompt)
                        continuation.yield(result)
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } else {
            return AsyncThrowingStream { $0.finish(throwing: AIServiceError.visionNotSupported) }
        }
    }

    // MARK: - Validation

    func validateProvider(_ config: ProviderConfig) async throws -> Bool {
        guard let provider = makeProvider(from: config) else {
            throw AIServiceError.notConfigured
        }
        _ = try await provider.chat(
            messages: [("user", "Hi")],
            systemPrompt: nil
        )
        return true
    }

    // MARK: - Persistence

    private func seedBuiltInsIfNeeded() {
        let existingNames = Set(providers.map(\.name))
        var added = false
        for builtIn in ProviderConfig.builtInProviders {
            if !existingNames.contains(builtIn.name) {
                providers.append(builtIn)
                added = true
            }
        }
        if added { persist() }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            providers = try JSONDecoder().decode([ProviderConfig].self, from: data)
        } catch {
            print("Failed to load providers: \(error)")
            providers = []
        }
    }

    private func persist() {
        let snapshot = providers
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let data = try JSONEncoder().encode(snapshot)
                try data.write(to: self.fileURL, options: .atomic)
            } catch {
                assertionFailure("Failed to save providers: \(error)")
            }
        }
    }
}
