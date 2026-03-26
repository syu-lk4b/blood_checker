import XCTest
@testable import BloodPressureCam

final class ChatStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDirectory, withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testCreateSession() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(session.title, "新对话")
        XCTAssertTrue(session.messages.isEmpty)
    }

    func testAddMessage() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()
        let msg = ChatMessage(role: .user, content: "Hello")

        store.addMessage(msg, toSessionId: session.id)

        XCTAssertEqual(store.sessions[0].messages.count, 1)
        XCTAssertEqual(store.sessions[0].messages[0].content, "Hello")
    }

    func testDeleteSession() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()
        XCTAssertEqual(store.sessions.count, 1)

        store.deleteSession(session.id)
        XCTAssertTrue(store.sessions.isEmpty)
    }

    func testPersistenceRoundTrip() {
        let store1 = ChatStore(baseURL: tempDirectory)
        let session = store1.createSession()
        let msg = ChatMessage(role: .user, content: "Persisted")
        store1.addMessage(msg, toSessionId: session.id)

        let store2 = ChatStore(baseURL: tempDirectory)
        XCTAssertEqual(store2.sessions.count, 1)
        XCTAssertEqual(store2.sessions[0].messages[0].content, "Persisted")
    }

    func testUpdateSessionTitle() {
        let store = ChatStore(baseURL: tempDirectory)
        let session = store.createSession()

        store.updateSessionTitle(session.id, title: "血压咨询")

        XCTAssertEqual(store.sessions[0].title, "血压咨询")
    }
}
