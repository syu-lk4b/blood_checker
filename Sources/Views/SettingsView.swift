import SwiftUI

struct SettingsView: View {
    @AppStorage("shouldHighlightHighReadings") private var shouldHighlightHighReadings = true
    @AppStorage("reminderEnabled") private var reminderEnabled = false
    @AppStorage("reminderHour") private var reminderHour = 8
    @AppStorage("reminderMinute") private var reminderMinute = 0
    @State private var reminderDate = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()

    var body: some View {
        Form {
            HealthKitSettingsView()

            Section(header: Text("通用")) {
                Toggle("高血压提醒高亮", isOn: $shouldHighlightHighReadings)
                Toggle("开启测量提醒", isOn: $reminderEnabled)
                    .accessibilityHint("开启后每天定时提醒测量血压")
                if reminderEnabled {
                    DatePicker("提醒时间", selection: $reminderDate, displayedComponents: .hourAndMinute)
                        .onChange(of: reminderDate) { newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            reminderHour = components.hour ?? reminderHour
                            reminderMinute = components.minute ?? reminderMinute
                        }
                }
            }

            Section(header: Text("关于")) {
                HStack {
                    Text("应用版本")
                    Spacer()
                    Text("1.0")
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("应用版本 1.0")
                if let privacyURL = URL(string: "https://example.com/privacy") {
                    Link("隐私政策", destination: privacyURL)
                }
                if let feedbackURL = URL(string: "mailto:feedback@example.com") {
                    Link("意见反馈", destination: feedbackURL)
                }
            }
        }
        .onAppear {
            if let date = Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) {
                reminderDate = date
            }
        }
        .navigationTitle("设置")
    }
}
