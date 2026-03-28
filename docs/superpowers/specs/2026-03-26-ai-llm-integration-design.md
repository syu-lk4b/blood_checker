# AI LLM Integration Design Spec

## Overview

为 BloodPressureCam iOS App 集成 AI LLM 功能，支持用户自行配置 OpenAI 兼容的 LLM 提供商（Ollama、OpenAI、DeepSeek 等），实现三个核心场景：血压数据分析、拍照 OCR 识别、健康问答聊天。

## 功能场景

### 场景 A：血压数据分析

- **触发方式**：AI Tab 内"分析我的数据"按钮
- **流程**：点击 → 从 MeasurementStore 取近期数据 → 构造 system prompt（包含格式化的血压数据摘要）+ user prompt → 流式展示分析结果
- **Prompt 策略**：将血压数据格式化为结构化文本注入 system prompt，包含日期、收缩压、舒张压、心率、姿势等字段
- **展示**：流式输出的文本分析报告

### 场景 B：拍照 OCR 识别

- **触发方式**：现有拍照流程中，拍照完成后自动触发
- **流程**：拍照 → 图片 base64 编码发送给 LLM（vision API）→ LLM 返回 JSON 格式读数 → 自动填充 ManualEntryView 表单
- **返回格式**：`{"systolic": 120, "diastolic": 80, "heartRate": 72}`
- **降级处理**：LLM 未配置或请求失败时，提示用户手动输入；检测到模型不支持 vision 时，提示用户更换模型
- **Vision 检测**：首次使用 OCR 时发送测试请求，错误则提示模型不支持 vision

### 场景 C：健康问答聊天

- **触发方式**：AI Tab 主界面，标准聊天 UI
- **流程**：用户输入 → 可选点击"附加我的数据"按钮注入血压数据 → 流式展示回答
- **"附加我的数据"**：点击后从 MeasurementStore 取最近 30 条记录，格式化追加到当前消息上下文
- **会话管理**：支持多轮对话，可新建/切换/删除会话
- **隐私提示**：首次附加数据时弹出确认弹窗

## 架构设计

### 方案：统一 Service 层

```
LLMService (统一 API 调用 + SSE 解析)
    ├── ChatStore (会话管理、消息历史持久化)
    ├── OCR 分析 (图片→读数提取，内嵌 LLMService 方法)
    └── 健康分析 (血压数据→分析报告，内嵌 LLMService 方法)
```

所有 AI 功能共享一个 LLMService 实例，差异在于 prompt 构造和响应解析。

### 配置模型

```swift
struct LLMConfig: Codable {
    var baseURL: String      // e.g. "http://localhost:11211/api/openai/v1"
    var apiKey: String       // 可为空（Ollama 不需要）
    var modelName: String    // e.g. "gemini-3.1-pro-preview:latest"
}
```

存储：`@AppStorage` / UserDefaults，JSON 序列化。

### 消息模型

```swift
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole        // .system, .user, .assistant
    let content: String
    let imageData: Data?         // vision 场景的 base64 图片
    let timestamp: Date
}

enum MessageRole: String, Codable {
    case system, user, assistant
}
```

### 会话模型

```swift
struct ChatSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
}
```

### LLMService 接口

```swift
class LLMService: ObservableObject {
    @Published var config: LLMConfig

    // 流式聊天
    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>

    // 带图片的 vision 请求（OCR）
    func analyzeImage(_ image: UIImage, prompt: String) -> AsyncThrowingStream<String, Error>

    // 配置验证
    func validateConfig() async throws -> Bool
}
```

使用 `URLSession.bytes(for:)` 处理 SSE streaming，原生 `AsyncSequence`，无第三方依赖。

### ChatStore

```swift
class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession]

    func createSession() -> ChatSession
    func addMessage(_ message: ChatMessage, to session: ChatSession)
    func deleteSession(_ session: ChatSession)
}
```

持久化到 `Documents/chat-sessions.json`，与 MeasurementStore 模式一致。

## UI 结构

### AI Tab（新增第 6 个 Tab）

SF Symbol: `brain` 或 `sparkles`

```
AIAssistantView (NavigationView)
├── 顶部：功能区
│   ├── "分析我的数据" 按钮卡片
│   └── AI 配置状态指示（已配置 ✓ / 未配置 → 跳转设置）
├── 中部：聊天区域
│   ├── 会话列表切换
│   ├── 消息列表（ScrollView + LazyVStack）
│   │   ├── 用户消息气泡（右侧）
│   │   ├── AI 消息气泡（左侧，流式更新）
│   │   └── "附加我的数据" 标记
│   └── 流式输出时底部打字动画
└── 底部：输入栏
    ├── TextField 输入框
    ├── "附加我的数据" 切换按钮
    └── 发送按钮
```

### Settings 扩展

在 SettingsView 新增 "AI 设置" Section：

- API Base URL（TextField）
- API Key（SecureField）
- Model Name（TextField）
- "测试连接" 按钮 → `validateConfig()`
- 连接状态显示

### OCR 集成

修改 CaptureEntryView / ManualEntryView：
- 拍照完成后若 LLM 已配置，显示"正在识别..."
- 成功：自动填充表单，用户可修改后保存
- 失败/未配置：提示文案，正常手动输入

### 隐私提示

首次使用 AI 功能弹出 Alert：
- 标题："数据隐私说明"
- 内容：说明数据将发送到用户配置的 LLM 服务
- 按钮："我知道了" / "取消"
- 确认后 `@AppStorage("hasAcceptedAIPrivacy")` 记录，不再重复

## 错误处理

### 错误类型

```swift
enum LLMError: LocalizedError {
    case notConfigured
    case invalidURL
    case networkError(Error)
    case apiError(Int, String)
    case streamingError
    case visionNotSupported
    case timeout
    case invalidResponse
}
```

### 各场景错误处理

| 场景 | 错误情况 | 处理方式 |
|------|---------|---------|
| 配置验证 | 连接失败 | 设置页显示错误信息 |
| 聊天 | 网络/API 错误 | 聊天气泡中显示错误，提供"重试" |
| 聊天 | 流式中断 | 保留已接收内容，显示"回答被中断"，可重试 |
| OCR | 不支持 vision | 提示更换模型，回退手动输入 |
| OCR | JSON 解析失败 | 提示"无法识别读数"，回退手动输入 |
| 数据分析 | 任何错误 | 结果区域显示错误，提供重试 |
| 全局 | 未配置 LLM | AI Tab 显示引导卡片 |

### 超时策略

- 聊天/分析：60 秒
- OCR：30 秒
- 配置验证：10 秒
- 不做自动重试，用户手动重试
- 用户离开页面或发送新消息时取消进行中的请求

## 文件结构

### 新增文件

```
Sources/
├── Models/
│   ├── LLMConfig.swift
│   └── ChatMessage.swift
├── Services/
│   ├── LLMService.swift
│   └── ChatStore.swift
└── Views/
    ├── AIAssistantView.swift
    ├── ChatBubbleView.swift
    └── LLMSettingsView.swift
```

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `ContentView.swift` | 新增 AI 助手 Tab |
| `SettingsView.swift` | 新增 AI 设置 Section |
| `CaptureEntryView.swift` | 拍照后触发 OCR |
| `ManualEntryView.swift` | 接收 OCR 结果自动填充表单 |
| `BloodPressureCamApp.swift` | 注入 LLMService 和 ChatStore |

### 外部依赖

无。全部使用 iOS 原生 API：
- `URLSession.bytes(for:)` — SSE streaming（iOS 15+）
- `JSONDecoder` / `JSONEncoder` — 序列化
- SwiftUI 原生组件 — UI

### 注入方式

```swift
// BloodPressureCamApp.swift
@StateObject private var llmService = LLMService()
@StateObject private var chatStore = ChatStore()

.environmentObject(llmService)
.environmentObject(chatStore)
```
