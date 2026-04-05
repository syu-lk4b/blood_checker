import SwiftUI

@main
struct BloodPressureCamApp: App {
    @StateObject private var store = MeasurementStore()
    @StateObject private var llmService = LLMService()
    @StateObject private var chatStore = ChatStore()
    @StateObject private var healthKitService = HealthKitService()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(llmService)
                    .environmentObject(chatStore)
                    .environmentObject(healthKitService)
                    .onAppear { store.healthKitService = healthKitService }
            } else {
                OnboardingView()
            }
        }
    }
}
