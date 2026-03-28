import SwiftUI
import Charts

struct ContentView: View {
    @EnvironmentObject private var store: MeasurementStore
    @State private var showCapture = false

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        // Unselected: soft gray
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
        // Selected: accent blue
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemBlue
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            RecordsView()
                .tabItem {
                    Label("记录", systemImage: "heart.text.square")
                }
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.line.uptrend.xyaxis")
                }
            CaptureEntryView(isPresented: $showCapture)
                .tabItem {
                    Label("拍照", systemImage: "camera.fill")
                }
            AIAssistantView()
                .tabItem {
                    Label("AI 助手", systemImage: "brain")
                }
            MoreView()
                .tabItem {
                    Label("更多", systemImage: "ellipsis")
                }
        }
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
