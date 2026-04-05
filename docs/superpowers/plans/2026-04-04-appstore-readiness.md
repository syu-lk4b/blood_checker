# App Store Readiness Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all App Store readiness issues so BloodPressureCam passes Apple review.

**Architecture:** Five independent fix areas applied to the existing SwiftUI codebase: force-unwrap cleanup, Info.plist configuration (LaunchScreen + Chinese privacy descriptions), new OnboardingView with AppStorage gating, accessibility labels on all views, and wiring onboarding into the app entry point.

**Tech Stack:** Swift, SwiftUI, iOS 16+, XcodeGen

---

### Task 1: Force Unwrap Cleanup

**Files:**
- Modify: `Sources/Views/SettingsView.swift:36-37`
- Modify: `Sources/Views/CameraCaptureView.swift:78`

- [ ] **Step 1: Fix SettingsView force unwraps**

In `Sources/Views/SettingsView.swift`, replace lines 36-37:

```swift
// OLD:
Link("隐私政策", destination: URL(string: "https://example.com/privacy")!)
Link("意见反馈", destination: URL(string: "mailto:feedback@example.com")!)
```

```swift
// NEW:
if let privacyURL = URL(string: "https://example.com/privacy") {
    Link("隐私政策", destination: privacyURL)
}
if let feedbackURL = URL(string: "mailto:feedback@example.com") {
    Link("意见反馈", destination: feedbackURL)
}
```

- [ ] **Step 2: Fix CameraCaptureView force unwrap**

In `Sources/Views/CameraCaptureView.swift`, replace line 78:

```swift
// OLD:
Link("前往设置", destination: URL(string: UIApplication.openSettingsURLString)!)
```

```swift
// NEW:
if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
    Link("前往设置", destination: settingsURL)
}
```

- [ ] **Step 3: Build to verify no compile errors**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Views/SettingsView.swift Sources/Views/CameraCaptureView.swift
git commit -m "fix: remove force unwraps in production code paths"
```

---

### Task 2: Info.plist — LaunchScreen + Chinese Privacy Descriptions

**Files:**
- Modify: `Sources/Info.plist`

- [ ] **Step 1: Add LaunchScreen config and update privacy descriptions**

In `Sources/Info.plist`, make three changes:

1. Replace the empty `UILaunchStoryboardName` with a `UILaunchScreen` dictionary:

```xml
<!-- REMOVE these two lines: -->
<key>UILaunchStoryboardName</key>
<string></string>

<!-- ADD this block in their place: -->
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>AccentColor</string>
    <key>UIImageName</key>
    <string>AppIcon</string>
</dict>
```

2. Replace the English camera description with Chinese:

```xml
<!-- OLD: -->
<key>NSCameraUsageDescription</key>
<string>BloodPressureCam needs camera access to capture readings from your monitor.</string>

<!-- NEW: -->
<key>NSCameraUsageDescription</key>
<string>需要使用相机拍摄血压计读数</string>
```

3. Replace the English photo library description with Chinese:

```xml
<!-- OLD: -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>BloodPressureCam saves captured readings to your photo library.</string>

<!-- NEW: -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要访问相册以保存血压记录照片</string>
```

- [ ] **Step 2: Regenerate Xcode project**

Run: `cd /Users/syu/repo/ios_apps/blood_checker && xcodegen generate`
Expected: output contains "Generated BloodPressureCam.xcodeproj"

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Sources/Info.plist
git commit -m "fix: add LaunchScreen config and Chinese privacy descriptions"
```

---

### Task 3: Onboarding View

**Files:**
- Create: `Sources/Views/OnboardingView.swift`

- [ ] **Step 1: Create OnboardingView.swift**

Create `Sources/Views/OnboardingView.swift` with the following content:

```swift
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                onboardingPage(
                    icon: "heart.text.square.fill",
                    iconColor: .red,
                    title: "欢迎使用血压管家",
                    subtitle: "轻松记录和追踪您的血压数据，守护您的心血管健康"
                )
                .tag(0)

                onboardingPage(
                    icon: "camera.fill",
                    iconColor: .accentColor,
                    title: "拍照即可识别",
                    subtitle: "对准血压计屏幕拍照，AI 自动识别读数，免去手动输入"
                )
                .tag(1)

                onboardingPage(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: "趋势分析与报告",
                    subtitle: "查看血压变化趋势，生成 PDF 报告，方便就医时展示给医生"
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: {
                if currentPage < 2 {
                    withAnimation { currentPage += 1 }
                } else {
                    hasCompletedOnboarding = true
                }
            }) {
                Text(currentPage < 2 ? "下一步" : "开始使用")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

            if currentPage < 2 {
                Button("跳过") {
                    hasCompletedOnboarding = true
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
            } else {
                Spacer().frame(height: 52)
            }
        }
    }

    private func onboardingPage(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(iconColor)
                .accessibilityHidden(true)
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)。\(subtitle)")
    }
}
```

- [ ] **Step 2: Regenerate Xcode project and build**

Run:
```bash
cd /Users/syu/repo/ios_apps/blood_checker && xcodegen generate
xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/Views/OnboardingView.swift
git commit -m "feat: add onboarding flow for first-time users"
```

---

### Task 4: Accessibility Labels on All Views

**Files:**
- Modify: `Sources/Views/RecordsView.swift`
- Modify: `Sources/Views/StatisticsView.swift`
- Modify: `Sources/Views/CaptureEntryView.swift`
- Modify: `Sources/Views/ManualEntryView.swift`
- Modify: `Sources/Views/CameraCaptureView.swift`
- Modify: `Sources/Views/AIAssistantView.swift`
- Modify: `Sources/Views/ReportsView.swift`
- Modify: `Sources/Views/SettingsView.swift`
- Modify: `Sources/Views/LLMSettingsView.swift`
- Modify: `Sources/Views/ChatBubbleView.swift`
- Modify: `Sources/Views/ContentView.swift`

#### Step 1: ContentView.swift

- [ ] Add accessibility labels to tab items. Replace the TabView body:

```swift
TabView {
    RecordsView()
        .tabItem {
            Label("记录", systemImage: "heart.text.square")
        }
        .accessibilityLabel("健康记录")
    StatisticsView()
        .tabItem {
            Label("统计", systemImage: "chart.line.uptrend.xyaxis")
        }
        .accessibilityLabel("趋势统计")
    CaptureEntryView(isPresented: $showCapture)
        .tabItem {
            Label("拍照", systemImage: "camera.fill")
        }
        .accessibilityLabel("拍照录入")
    AIAssistantView()
        .tabItem {
            Label("AI 助手", systemImage: "brain")
        }
        .accessibilityLabel("AI 助手")
    ReportsView()
        .tabItem {
            Label("报告", systemImage: "doc.plaintext")
        }
        .accessibilityLabel("健康报告")
    SettingsView()
        .tabItem {
            Label("设置", systemImage: "gearshape")
        }
        .accessibilityLabel("设置")
}
```

#### Step 2: RecordsView.swift

- [ ] Add accessibility to ReadingRowView. In the `body` of `ReadingRowView`, add after `.padding(.vertical, 8)`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(formatter.string(from: reading.recordedAt))，高压\(reading.systolic)，低压\(reading.diastolic)\(reading.heartRate.map { "，心率\($0)" } ?? "")，\(reading.level.title)")
```

- [ ] Add accessibility to the empty state. On the `emptyState` VStack, add:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("暂无记录，点击右上角加号添加")
```

- [ ] Add accessibility to the add button. On the toolbar Button's Image, add:

```swift
Image(systemName: "plus.circle.fill")
    .accessibilityLabel("添加记录")
```

- [ ] In `ReadingDetailView`, add accessibility to the photo image:

```swift
if let image = store.image(for: reading) {
    Image(uiImage: image)
        .resizable()
        .scaledToFit()
        .cornerRadius(12)
        .accessibilityLabel("血压计照片")
}
```

#### Step 3: StatisticsView.swift

- [ ] Add accessibility to `StatisticBadge`. In the `StatisticBadge` body, add after `.cornerRadius(12)`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title) \(value)")
```

- [ ] Add accessibility to chart. On the `Chart` view, add:

```swift
.accessibilityLabel("血压趋势图表，共\(data.count)条数据")
```

#### Step 4: CaptureEntryView.swift

- [ ] Add accessibility to the camera icon (decorative). On `Image(systemName: "camera.fill")`:

```swift
.accessibilityHidden(true)
```

- [ ] Add accessibility hint to the capture button:

```swift
Button(action: { showCameraSheet = true }) {
    Label("开始拍照", systemImage: "camera")
        // ... existing modifiers
}
.accessibilityHint("打开相机拍摄血压计屏幕")
```

- [ ] Add accessibility hint to manual entry button:

```swift
Button(action: { showManualEntry = true }) {
    Text("手动录入")
        .padding(.bottom)
}
.accessibilityHint("手动输入血压读数")
```

#### Step 5: CameraCaptureView.swift

- [ ] In `PhotoAuthorizationView`, add accessibility to the camera icon (in denied state):

```swift
Image(systemName: "camera.fill")
    .font(.system(size: 48))
    .foregroundColor(.accentColor)
    .accessibilityHidden(true)
```

- [ ] Add accessibility to "授权相机" button:

```swift
Button("授权相机") {
    // existing code
}
.accessibilityHint("授权应用使用相机")
```

#### Step 6: ManualEntryView.swift

- [ ] Add accessibility to recognition status. On the recognizing HStack:

```swift
HStack {
    ProgressView()
    Text("正在识别血压读数...")
        .foregroundColor(.secondary)
        .padding(.leading, 8)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("正在识别血压读数")
```

- [ ] Add accessibility to photo section images:

```swift
if let photo {
    Image(uiImage: photo)
        .resizable()
        .scaledToFit()
        .cornerRadius(8)
        .accessibilityLabel("已拍摄的血压计照片")
} else if let existing = existingReading, let storedImage = store.image(for: existing) {
    Image(uiImage: storedImage)
        .resizable()
        .scaledToFit()
        .cornerRadius(8)
        .accessibilityLabel("已保存的血压计照片")
}
```

#### Step 7: AIAssistantView.swift

- [ ] Add accessibility to the notConfiguredView icon:

```swift
Image(systemName: "brain")
    .font(.system(size: 64))
    .foregroundColor(.secondary)
    .accessibilityHidden(true)
```

- [ ] Add accessibility to the "分析我的血压数据" button:

```swift
Button(action: analyzeData) {
    HStack {
        Image(systemName: "waveform.path.ecg")
        Text("分析我的血压数据")
        Spacer()
        Image(systemName: "chevron.right")
    }
    // ... existing modifiers
}
.disabled(isStreaming)
.accessibilityLabel("分析我的血压数据")
.accessibilityHint("使用 AI 分析您的血压记录并给出建议")
```

- [ ] Add accessibility to toolbar buttons:

On the session list button:
```swift
Button(action: { showSessionList.toggle() }) {
    Image(systemName: "list.bullet")
}
.accessibilityLabel("对话记录列表")
```

On the new session button:
```swift
Button(action: createNewSession) {
    Image(systemName: "square.and.pencil")
}
.accessibilityLabel("新建对话")
```

- [ ] Add accessibility to the attach data button in inputBar:

```swift
Button(action: toggleAttachData) {
    Image(systemName: attachData ? "heart.text.square.fill" : "heart.text.square")
        .font(.title3)
        .foregroundColor(attachData ? .accentColor : .secondary)
}
.accessibilityLabel(attachData ? "已附加血压数据" : "附加血压数据")
.accessibilityHint("将血压数据一并发送给 AI 分析")
```

- [ ] Add accessibility to the send button:

```swift
Button(action: sendMessage) {
    Image(systemName: "arrow.up.circle.fill")
        .font(.title2)
        .foregroundColor(canSend ? .accentColor : .secondary)
}
.disabled(!canSend)
.accessibilityLabel("发送消息")
```

#### Step 8: ReportsView.swift

- [ ] Add accessibility to the export button:

```swift
Button(action: exportReport) {
    Image(systemName: "square.and.arrow.up")
}
.disabled(readings.isEmpty)
.accessibilityLabel("导出报告")
.accessibilityHint("生成并分享 PDF 格式的血压报告")
```

- [ ] Add accessibility to `summaryTile` in `ReportPreview`. After `.cornerRadius(12)`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(title) \(value)")
```

#### Step 9: SettingsView.swift

- [ ] Add accessibility hint to the reminder toggle:

```swift
Toggle("开启测量提醒", isOn: $reminderEnabled)
    .accessibilityHint("开启后每天定时提醒测量血压")
```

- [ ] Add accessibility to version display:

```swift
HStack {
    Text("应用版本")
    Spacer()
    Text("1.0")
        .foregroundColor(.secondary)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("应用版本 1.0")
```

#### Step 10: LLMSettingsView.swift

- [ ] Add accessibility hint to test connection button:

```swift
Button(action: testConnection) {
    // ... existing HStack
}
.disabled(!llmService.config.isConfigured)
.accessibilityLabel("测试连接")
.accessibilityHint("验证 AI 服务配置是否正确")
```

#### Step 11: ChatBubbleView.swift

- [ ] Add accessibility to the chat bubble. After `.padding(.vertical, 2)`:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel("\(isUser ? "我" : "AI 助手")说：\(message.content)")
```

- [ ] **Step 12: Build to verify all changes compile**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 13: Commit**

```bash
git add Sources/Views/
git commit -m "feat: add accessibility labels to all views for VoiceOver support"
```

---

### Task 5: Wire Onboarding into App Entry Point

**Files:**
- Modify: `Sources/BloodPressureCamApp.swift`

- [ ] **Step 1: Update BloodPressureCamApp.swift**

Replace the entire file content:

```swift
import SwiftUI

@main
struct BloodPressureCamApp: App {
    @StateObject private var store = MeasurementStore()
    @StateObject private var llmService = LLMService()
    @StateObject private var chatStore = ChatStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(store)
                    .environmentObject(llmService)
                    .environmentObject(chatStore)
            } else {
                OnboardingView()
            }
        }
    }
}
```

- [ ] **Step 2: Regenerate project and build**

Run:
```bash
cd /Users/syu/repo/ios_apps/blood_checker && xcodegen generate
xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Run tests**

Run: `xcodebuild -scheme BloodPressureCam -destination 'platform=iOS Simulator,name=iPhone 16' test 2>&1 | tail -10`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Sources/BloodPressureCamApp.swift
git commit -m "feat: gate app launch on onboarding completion"
```
