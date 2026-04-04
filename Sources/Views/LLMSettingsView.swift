import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject private var llmService: LLMService
    @State private var validationState: ValidationState = .idle

    private enum ValidationState {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        Section(header: Text("AI 设置")) {
            TextField("API Base URL", text: $llmService.config.baseURL)
                .textContentType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.URL)

            SecureField("API Key（可选）", text: $llmService.config.apiKey)

            TextField("模型名称", text: $llmService.config.modelName)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            Button(action: testConnection) {
                HStack {
                    Text("测试连接")
                    Spacer()
                    switch validationState {
                    case .idle:
                        EmptyView()
                    case .testing:
                        ProgressView()
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .failure:
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            .disabled(!llmService.config.isConfigured)
            .accessibilityLabel("测试连接")
            .accessibilityHint("验证 AI 服务配置是否正确")

            if case .failure(let message) = validationState {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func testConnection() {
        validationState = .testing
        Task {
            do {
                _ = try await llmService.validateConfig()
                await MainActor.run { validationState = .success }
            } catch {
                await MainActor.run {
                    validationState = .failure(error.localizedDescription)
                }
            }
        }
    }
}
