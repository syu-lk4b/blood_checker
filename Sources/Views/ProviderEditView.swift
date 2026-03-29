import SwiftUI

struct ProviderEditView: View {
    @EnvironmentObject private var llmService: LLMService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var type: ProviderType
    @State private var baseURL: String
    @State private var modelName: String
    @State private var apiKey: String
    @State private var supportsVision: Bool
    @State private var supportsStreaming: Bool
    @State private var testState: TestState = .idle

    let provider: ProviderConfig

    private enum TestState {
        case idle, testing, success(Int), failure(String)
    }

    init(provider: ProviderConfig) {
        self.provider = provider
        _name = State(initialValue: provider.name)
        _type = State(initialValue: provider.type)
        _baseURL = State(initialValue: provider.baseURL)
        _modelName = State(initialValue: provider.modelName)
        _apiKey = State(initialValue: provider.apiKey ?? "")
        _supportsVision = State(initialValue: provider.supportsVision)
        _supportsStreaming = State(initialValue: provider.supportsStreaming)
    }

    var body: some View {
        Form {
            Section(header: Text("基本信息")) {
                TextField("名称", text: $name)

                if !provider.isBuiltIn {
                    Picker("类型", selection: $type) {
                        ForEach(ProviderType.allCases) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .onChange(of: type) { newType in
                        if baseURL.isEmpty || baseURL == ProviderType.allCases.first(where: { $0 != newType })?.defaultBaseURL {
                            baseURL = newType.defaultBaseURL
                        }
                        if modelName.isEmpty {
                            modelName = newType.defaultModel
                        }
                    }
                }
            }

            Section(header: Text("连接配置")) {
                TextField("API Base URL", text: $baseURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)

                TextField("模型名称", text: $modelName)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if type.requiresAPIKey {
                    SecureField("API Key", text: $apiKey)
                }
            }

            Section(header: Text("能力")) {
                Toggle("支持图片识别 (Vision)", isOn: $supportsVision)
                Toggle("支持流式输出", isOn: $supportsStreaming)
            }

            Section {
                Button(action: testConnection) {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        switch testState {
                        case .idle:
                            EmptyView()
                        case .testing:
                            ProgressView()
                        case .success(let ms):
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("\(ms)ms")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .failure:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                }
                .disabled(baseURL.isEmpty || modelName.isEmpty)

                if case .failure(let msg) = testState {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if !provider.isBuiltIn {
                Section {
                    Button("删除此服务商", role: .destructive) {
                        llmService.deleteProvider(provider.id)
                        dismiss()
                    }
                }
            }

            Section {
                if !provider.isDefault {
                    Button("设为默认") {
                        llmService.setDefault(provider.id)
                    }
                }
            }
        }
        .navigationTitle(provider.isBuiltIn ? provider.name : "编辑服务商")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") { save() }
                    .disabled(name.isEmpty || modelName.isEmpty)
            }
        }
    }

    private func save() {
        var updated = provider
        updated.name = name
        if !provider.isBuiltIn { updated.type = type }
        updated.baseURL = baseURL
        updated.modelName = modelName
        updated.supportsVision = supportsVision
        updated.supportsStreaming = supportsStreaming
        updated.apiKey = apiKey.isEmpty ? nil : apiKey
        llmService.updateProvider(updated)
        dismiss()
    }

    private func testConnection() {
        testState = .testing
        var testConfig = provider
        testConfig.baseURL = baseURL
        testConfig.modelName = modelName
        if !apiKey.isEmpty {
            testConfig.apiKey = apiKey
        }

        Task {
            let start = Date()
            do {
                _ = try await llmService.validateProvider(testConfig)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                await MainActor.run { testState = .success(ms) }
            } catch {
                await MainActor.run {
                    testState = .failure(error.localizedDescription)
                }
            }
        }
    }
}
