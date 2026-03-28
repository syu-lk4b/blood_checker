import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject private var llmService: LLMService
    @EnvironmentObject private var chatStore: ChatStore
    @EnvironmentObject private var measurementStore: MeasurementStore
    @AppStorage("hasAcceptedAIPrivacy") private var hasAcceptedAIPrivacy = false

    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var streamingContent = ""
    @State private var attachData = false
    @State private var currentSessionId: UUID?
    @State private var showPrivacyAlert = false
    @State private var showSessionList = false
    @State private var streamTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            Group {
                if !llmService.config.isConfigured {
                    notConfiguredView
                } else {
                    chatView
                }
            }
            .navigationTitle("AI 助手")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSessionList.toggle() }) {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: createNewSession) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showSessionList) {
                sessionListView
            }
            .alert("数据隐私说明", isPresented: $showPrivacyAlert) {
                Button("我知道了") {
                    hasAcceptedAIPrivacy = true
                    attachData = true
                }
                Button("取消", role: .cancel) {
                    attachData = false
                }
            } message: {
                Text("您的血压数据将发送到所配置的 AI 服务进行分析。数据安全取决于您所选的服务提供商。")
            }
            .onAppear {
                if currentSessionId == nil, let first = chatStore.sessions.first {
                    currentSessionId = first.id
                }
            }
            .onDisappear {
                streamTask?.cancel()
            }
        }
    }

    // MARK: - Not Configured View

    private var notConfiguredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("AI 助手未配置")
                .font(.title2)
            Text("请前往「设置」页面配置 AI 服务")
                .foregroundColor(.secondary)
            NavigationLink(destination: LLMSettingsFormView()) {
                Text("前往设置")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Chat View

    private var chatView: some View {
        VStack(spacing: 0) {
            // Analysis quick action
            Button(action: analyzeData) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("分析我的血压数据")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .disabled(isStreaming)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        if let session = currentSession {
                            ForEach(session.messages.filter { $0.role != .system }) { message in
                                ChatBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        if isStreaming, !streamingContent.isEmpty {
                            ChatBubbleView(
                                message: ChatMessage(
                                    role: .assistant,
                                    content: streamingContent
                                ),
                                isStreaming: true
                            )
                            .id("streaming")
                        }
                    }
                }
                .onChange(of: streamingContent) { _ in
                    proxy.scrollTo("streaming", anchor: .bottom)
                }
            }

            Divider()

            // Input bar
            inputBar
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            if attachData {
                HStack {
                    Image(systemName: "heart.text.square")
                    Text("已附加血压数据")
                        .font(.caption)
                    Spacer()
                    Button(action: { attachData = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button(action: toggleAttachData) {
                    Image(systemName: attachData ? "heart.text.square.fill" : "heart.text.square")
                        .font(.title3)
                        .foregroundColor(attachData ? .accentColor : .secondary)
                }

                TextField("输入问题...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...5)

                let canSend = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .accentColor : .secondary)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Session List

    private var sessionListView: some View {
        NavigationView {
            List {
                ForEach(chatStore.sessions) { session in
                    Button(action: {
                        currentSessionId = session.id
                        showSessionList = false
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                            Text(sessionDateString(session.updatedAt))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let session = chatStore.sessions[index]
                        if currentSessionId == session.id {
                            currentSessionId = nil
                        }
                        chatStore.deleteSession(session.id)
                    }
                }
            }
            .navigationTitle("对话记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showSessionList = false }
                }
            }
        }
    }

    // MARK: - Actions

    private static let systemPrompt = "你是一个专业的健康助手，擅长血压相关的健康问题。请用中文回答。注意：你的回答仅供参考，不构成医疗建议。"

    private static let sessionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()

    private var currentSession: ChatSession? {
        chatStore.sessions.first { $0.id == currentSessionId }
    }

    private func createNewSession() {
        let session = chatStore.createSession()
        currentSessionId = session.id
    }

    @discardableResult
    private func ensureActiveSession() -> UUID {
        if let id = currentSessionId { return id }
        let session = chatStore.createSession()
        currentSessionId = session.id
        return session.id
    }

    private func toggleAttachData() {
        if !attachData && !hasAcceptedAIPrivacy {
            showPrivacyAlert = true
        } else {
            attachData.toggle()
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let sessionId = ensureActiveSession()

        var fullContent = text
        if attachData {
            let dataContext = formatReadingsForContext()
            fullContent = "以下是我的血压数据:\n\(dataContext)\n\n我的问题是: \(text)"
        }

        let userMessage = ChatMessage(role: .user, content: text)
        chatStore.addMessage(userMessage, toSessionId: sessionId)

        let allMessages = buildMessagesForAPI(userContent: fullContent, sessionId: sessionId)
        inputText = ""
        attachData = false

        startStreaming(messages: allMessages, sessionId: sessionId)
    }

    private func analyzeData() {
        let sessionId = ensureActiveSession()

        let dataContext = formatReadingsForContext()

        let userMessage = ChatMessage(role: .user, content: "📊 分析我的血压数据")
        chatStore.addMessage(userMessage, toSessionId: sessionId)

        let fullContent = "以下是用户的血压测量记录:\n\(dataContext)\n\n请分析血压趋势，指出是否有异常，并给出健康建议。"
        let messages = [
            ChatMessage(role: .system, content: Self.systemPrompt),
            ChatMessage(role: .user, content: fullContent)
        ]

        startStreaming(messages: messages, sessionId: sessionId)
    }

    private func startStreaming(messages: [ChatMessage], sessionId: UUID) {
        isStreaming = true
        streamingContent = ""

        streamTask?.cancel()
        streamTask = Task {
            var buffer = ""
            do {
                for try await chunk in llmService.streamChat(messages: messages) {
                    if Task.isCancelled { break }
                    buffer += chunk
                    let snapshot = buffer
                    await MainActor.run { streamingContent = snapshot }
                }
                if !Task.isCancelled {
                    let finalContent = buffer
                    await MainActor.run {
                        streamingContent = ""
                        let assistantMessage = ChatMessage(
                            role: .assistant,
                            content: finalContent
                        )
                        chatStore.addMessage(assistantMessage, toSessionId: sessionId)
                        isStreaming = false
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        role: .assistant,
                        content: "⚠️ \(error.localizedDescription)"
                    )
                    chatStore.addMessage(errorMessage, toSessionId: sessionId)
                    streamingContent = ""
                    isStreaming = false
                }
            }
        }
    }

    private func buildMessagesForAPI(userContent: String, sessionId: UUID) -> [ChatMessage] {
        var messages: [ChatMessage] = [
            ChatMessage(role: .system, content: Self.systemPrompt)
        ]
        if let session = chatStore.sessions.first(where: { $0.id == sessionId }) {
            let recentMessages = session.messages.suffix(10)
            messages.append(contentsOf: recentMessages.filter { $0.role != .system })
        }
        if let lastIndex = messages.lastIndex(where: { $0.role == .user }) {
            messages[lastIndex] = ChatMessage(
                role: .user,
                content: userContent,
                timestamp: messages[lastIndex].timestamp
            )
        }
        return messages
    }

    private func formatReadingsForContext() -> String {
        let readings = measurementStore.readings(for: .bloodPressure)
            .prefix(30)
        if readings.isEmpty { return "暂无血压数据" }

        return readings.map { r in
            let dateStr = r.title
            var line = "\(dateStr) | 高压:\(r.systolic) 低压:\(r.diastolic)"
            if let hr = r.heartRate { line += " 心率:\(hr)" }
            line += " 姿势:\(r.posture.displayName)"
            line += " 级别:\(r.level.title)"
            return line
        }.joined(separator: "\n")
    }

    private func sessionDateString(_ date: Date) -> String {
        Self.sessionDateFormatter.string(from: date)
    }
}

/// Wrapper to embed LLMSettingsView inside a Form for NavigationLink usage
private struct LLMSettingsFormView: View {
    var body: some View {
        Form {
            LLMSettingsView()
        }
        .navigationTitle("AI 设置")
    }
}
