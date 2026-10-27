import Foundation
import XCTest
@testable import QueryApp

final class BackendIntegrationTests: XCTestCase {
    @MainActor
    func testRealBackendLoginTaskReplayHistoryAndLogout() async throws {
        guard let address = ProcessInfo.processInfo.environment["CARDQUERY_INTEGRATION_URL"],
              let url = URL(string: address), url.host == "127.0.0.1" else {
            throw XCTSkip("通过 scripts/test_backend_integration.py 启动隔离的后端和 Redis 后运行")
        }
        let api = ServerAPI(baseURL: url, session: URLSession(configuration: .ephemeral))
        let manager = LoginManager(api: api, store: MemorySessionStore())
        let email = "ios-integration@wku.edu.cn"
        try await api.sendCode(email: email)
        try await manager.verify(email: email, code: "123456")
        XCTAssertFalse(manager.isLoggedIn)
        let room = BoundRoom(buildingCode: "test-building", buildingName: "测试楼",
                             floorCode: "test-floor", floorName: "一层", roomCode: "test-room", roomName: "101")
        try await manager.bindRoom(room)
        XCTAssertTrue(manager.isLoggedIn)
        let session = try manager.requireSession()
        do { _ = try await api.verifyCode(email: email, code: "123456"); XCTFail("验证码不能重复使用") }
        catch APIError.http(let code, _, _, _) { XCTAssertEqual(code, 400) }

        let key = UUID().uuidString
        var state = try await api.submitTask(token: session.accessToken, idempotencyKey: key)
        let repeated = try await api.submitTask(token: session.accessToken, idempotencyKey: key)
        XCTAssertEqual(state.taskId, repeated.taskId)
        let first = try await api.events(id: state.taskId, token: session.accessToken, lastEventId: nil)
        var parser = SSEParser()
        var cursor: String?
        for try await byte in first {
            if let event = try parser.consume(byte: byte) {
                cursor = event.id
                break
            }
        }
        first.task.cancel()
        XCTAssertNotNil(cursor)

        let resumed = try await api.events(id: state.taskId, token: session.accessToken, lastEventId: cursor)
        parser = SSEParser()
        var receivedCompletion = false
        for try await byte in resumed {
            guard let event = try parser.consume(byte: byte) else { continue }
            XCTAssertNotEqual(event.id, cursor)
            try state.apply(ServerAPI.decode(QueryTaskUpdate.self, from: Data(event.data.utf8)))
            if state.status.isTerminal { receivedCompletion = true; break }
        }
        resumed.task.cancel()
        XCTAssertTrue(receivedCompletion)
        XCTAssertEqual(state.status, .succeeded)
        XCTAssertEqual(state.completed, 1)
        let history = try await api.history(email: email, token: session.accessToken)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.waterBalance, 88.5)
        XCTAssertEqual(history.first?.electricityBalance, 120.25)

        // 再以 App 使用的任务模型跑一次，验证真实 Redis/Celery/SSE 与模型兼容。
        let suite = "cardquery.integration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = QueryTaskModel(defaults: defaults)
        model.start(api: api, session: session)
        for _ in 0..<250 {
            if model.finishedTaskId != nil || model.errorMessage != nil { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(model.task?.status, .succeeded, model.errorMessage ?? model.progressMessage)
        XCTAssertFalse(model.hasPendingQuery)
        model.suspend()

        try await manager.logout()
        XCTAssertFalse(manager.isLoggedIn)
        do { _ = try await api.history(email: email, token: session.accessToken); XCTFail("已撤销的会话不能继续访问") }
        catch APIError.unauthorized { }
    }
}
