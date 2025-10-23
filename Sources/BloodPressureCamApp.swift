import SwiftUI

@main
struct BloodPressureCamApp: App {
    @StateObject private var store = MeasurementStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
