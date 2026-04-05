import SwiftUI
import Charts

enum TabItem: Int, CaseIterable {
    case records, statistics, capture, ai, more

    var title: String {
        switch self {
        case .records: return "记录"
        case .statistics: return "统计"
        case .capture: return "拍照"
        case .ai: return "AI 助手"
        case .more: return "更多"
        }
    }

    var icon: String {
        switch self {
        case .records: return "heart.text.square.fill"
        case .statistics: return "chart.line.uptrend.xyaxis"
        case .capture: return "camera.fill"
        case .ai: return "brain.head.profile"
        case .more: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .records: return .red
        case .statistics: return .orange
        case .capture: return .blue
        case .ai: return .purple
        case .more: return .gray
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var selectedTab: TabItem = .records
    @State private var showCapture = false

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                switch selectedTab {
                case .records:
                    RecordsView()
                case .statistics:
                    StatisticsView()
                case .capture:
                    CaptureEntryView(isPresented: $showCapture)
                case .ai:
                    AIAssistantView()
                case .more:
                    MoreView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar
            Divider()
            HStack {
                ForEach(TabItem.allCases, id: \.rawValue) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
            .padding(.bottom, bottomSafeArea > 0 ? 20 : 8)
            .background(Color(.systemBackground))
        }
        .edgesIgnoringSafeArea(.bottom)
    }

    private func tabButton(_ tab: TabItem) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22))
                    .foregroundColor(selectedTab == tab ? tab.color : .gray.opacity(0.5))
                    .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundColor(selectedTab == tab ? tab.color : .gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var bottomSafeArea: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(MeasurementStore())
            .environmentObject(LLMService())
            .environmentObject(ChatStore())
    }
}
