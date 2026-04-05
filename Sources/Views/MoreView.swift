import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: MeasurementStore
    @EnvironmentObject private var llmService: LLMService

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary banner
                    summaryBanner

                    // Feature cards grid
                    featureCards

                    // Quick links
                    quickLinks
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("更多")
        }
    }

    // MARK: - Summary Banner

    private var summaryBanner: some View {
        let readingCount = store.readings(for: .bloodPressure).count
        let greeting = greetingText

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🩺 \(greeting)")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(readingCount) 条记录")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
            }
            Text("持续记录，掌握健康趋势")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemBlue).opacity(0.12), Color(.systemCyan).opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ], spacing: 14) {
            NavigationLink(destination: ReportsView()) {
                FeatureCardView(
                    icon: "📊",
                    title: "健康报告",
                    subtitle: "查看趋势分析",
                    backgroundColor: Color(.systemGreen).opacity(0.1),
                    accentColor: .green
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: SettingsView()) {
                FeatureCardView(
                    icon: "⚙️",
                    title: "设置",
                    subtitle: "提醒与偏好",
                    backgroundColor: Color(.systemGray4).opacity(0.3),
                    accentColor: .gray
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: LLMSettingsFormView()) {
                FeatureCardView(
                    icon: "🤖",
                    title: "AI 配置",
                    subtitle: llmService.config.isConfigured ? "已连接" : "未配置",
                    backgroundColor: Color(.systemPurple).opacity(0.1),
                    accentColor: .purple
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: aboutView) {
                FeatureCardView(
                    icon: "💡",
                    title: "关于",
                    subtitle: "版本 1.0",
                    backgroundColor: Color(.systemOrange).opacity(0.1),
                    accentColor: .orange
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Links

    private var quickLinks: some View {
        VStack(spacing: 0) {
            quickLinkRow(
                icon: "shield.checkered",
                iconColor: .blue,
                title: "隐私政策",
                destination: URL(string: "https://example.com/privacy")!
            )
            Divider().padding(.leading, 44)
            quickLinkRow(
                icon: "envelope.fill",
                iconColor: .green,
                title: "意见反馈",
                destination: URL(string: "mailto:feedback@example.com")!
            )
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func quickLinkRow(icon: String, iconColor: Color, title: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(iconColor)
                    .cornerRadius(7)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - About View

    private var aboutView: some View {
        Form {
            Section(header: Text("应用信息")) {
                HStack {
                    Text("应用名称")
                    Spacer()
                    Text("血压相机")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("版本号")
                    Spacer()
                    Text("1.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("关于")
    }

    // MARK: - Helpers

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }
}

// MARK: - Feature Card Component

private struct FeatureCardView: View {
    let icon: String
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(icon)
                .font(.system(size: 32))
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(backgroundColor)
        .cornerRadius(14)
    }
}

/// Standalone form wrapper for LLM settings, used from MoreView navigation
struct LLMSettingsFormView: View {
    var body: some View {
        Form {
            LLMSettingsView()
        }
        .navigationTitle("AI 设置")
    }
}
