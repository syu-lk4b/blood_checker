import SwiftUI

@main
struct BloodPressureCamApp: App {
    @StateObject private var store = MeasurementStore()
    @StateObject private var llmService = LLMService()
    @StateObject private var chatStore = ChatStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(llmService)
                .environmentObject(chatStore)
        }
    }
}
