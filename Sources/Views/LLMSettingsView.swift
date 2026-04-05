import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject private var llmService: LLMService

    var body: some View {
        Section(header: Text("AI 服务商")) {
            ForEach(llmService.providers) { provider in
                NavigationLink(destination: ProviderEditView(provider: provider)) {
                    ProviderRowView(provider: provider)
                }
            }

            Button(action: addCustomProvider) {
                Label("添加自定义服务商", systemImage: "plus.circle")
            }
        }
    }

    private func addCustomProvider() {
        let newProvider = ProviderConfig(
            name: "自定义服务商",
            type: .openaiCompatible,
            baseURL: "",
            modelName: ""
        )
        llmService.addProvider(newProvider)
    }
}

struct ProviderRowView: View {
    let provider: ProviderConfig

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: provider.type.iconName)
                .font(.title3)
                .foregroundColor(Color(provider.type.iconColor))
                .frame(width: 32, height: 32)
                .background(Color(provider.type.iconColor).opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(provider.name)
                        .font(.body)
                    if provider.isDefault {
                        Text("默认")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                Text(provider.modelName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(provider.isConfigured ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
    }
}
