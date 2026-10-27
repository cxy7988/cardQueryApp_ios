import Foundation
import XCTest
@testable import QueryApp

private struct MockReply {
    var status = 200
    var headers = ["Content-Type": "application/json"]
    var chunks: [Data]

    init(_ text: String, status: Int = 200, headers: [String: String] = ["Content-Type": "application/json"]) {
        self.status = status
        self.headers = headers
        chunks = [Data(text.utf8)]
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> MockReply)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let reply = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: reply.status,
                                           httpVersion: "HTTP/1.1", headerFields: reply.headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in reply.chunks { client?.urlProtocol(self, didLoad: chunk) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() { }
}

final class MemorySessionStore: SessionStore {
    var value: UserSession?
    var failSave = false
    func load() throws -> UserSession? { value }
    func save(_ session: UserSession) throws {
        if failSave { throw URLError(.cannotWriteToFile) }
        value = session
    }
    func clear() throws { value = nil }
}

final class QueryAppTests: XCTestCase {
    private let taskId = "00000000-0000-4000-8000-000000000001"
    private let roomJSON = #"{"building_code":"b1","building_name":"测试楼","floor_code":"f1","floor_name":"一层","room_code":"r1","room_name":"101"}"#
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "cardquery.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func api() -> ServerAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return ServerAPI(baseURL: URL(string: "https://cardquery.test")!, session: URLSession(configuration: config))
    }

    private func user(email: String = "student@wku.edu.cn", token: String = "test-session") -> UserSession {
        UserSession(email: email, accessToken: token, expiresAt: .distantFuture,
                    serverURL: URL(string: "https://cardquery.test")!,
                    room: BoundRoom(buildingCode: "b1", buildingName: "测试楼", floorCode: "f1",
                                    floorName: "一层", roomCode: "r1", roomName: "101"))
    }

    private func state(_ status: String = "running") -> String {
        let done = ["succeeded", "failed", "partial"].contains(status)
        return """
        {"task_id":"\(taskId)","status":"\(status)","total":1,"completed":\(done ? 1 : 0),"succeeded":\(status == "succeeded" ? 1 : 0),"failed":\(status == "failed" ? 1 : 0)}
        """
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream, data.isEmpty {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<250 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("客户端操作在五秒内未完成")
        throw URLError(.timedOut)
    }

    @MainActor
    func testFirstLoginBindsRoomWithBearerWithoutReusingCode() async throws {
        let api = api()
        let store = MemorySessionStore()
        let manager = LoginManager(api: api, store: store)
        var paths: [String] = []
        MockURLProtocol.handler = { request in
            paths.append(request.url!.path)
            let body = try self.body(request)
            if request.url!.path == "/api/verify_code" {
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertEqual(body["code"] as? String, "123456")
                return MockReply(#"{"valid":true,"access_token":"issued-token","expires_in":600,"room_info":null}"#)
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer issued-token")
            XCTAssertNil(body["code"])
            XCTAssertEqual(body["email"] as? String, "student@wku.edu.cn")
            XCTAssertEqual((body["room_info"] as? [String: String])?["room_code"], "r1")
            return MockReply("{\"valid\":true,\"access_token\":\"issued-token\",\"expires_in\":500,\"room_info\":\(self.roomJSON)}")
        }
        try await manager.verify(email: "student@wku.edu.cn", code: "123456")
        XCTAssertFalse(manager.isLoggedIn)
        XCTAssertNotNil(store.value)
        try await manager.bindRoom(user().room!)
        XCTAssertTrue(manager.isLoggedIn)
        XCTAssertEqual(manager.session?.room?.roomName, "101")
        XCTAssertEqual(paths, ["/api/verify_code", "/api/verify_code_with_room"])
    }

    @MainActor
    func testExistingUserUsesServerRoomImmediately() async throws {
        MockURLProtocol.handler = { _ in
            MockReply("{\"valid\":true,\"access_token\":\"issued-token\",\"expires_in\":600,\"room_info\":\(self.roomJSON)}")
        }
        let store = MemorySessionStore()
        let manager = LoginManager(api: api(), store: store)
        try await manager.verify(email: "student@wku.edu.cn", code: "123456")
        XCTAssertTrue(manager.isLoggedIn)
        XCTAssertEqual(manager.session?.room?.buildingCode, "b1")
        XCTAssertTrue(LoginManager(api: api(), store: store).isLoggedIn)
    }

    @MainActor
    func testExpiredOrOtherServerSessionCannotRestoreLogin() {
        let store = MemorySessionStore()
        store.value = UserSession(email: "student@wku.edu.cn", accessToken: "old", expiresAt: .distantPast,
                                  serverURL: api().baseURL, room: user().room)
        XCTAssertFalse(LoginManager(api: api(), store: store).isLoggedIn)
        store.value = UserSession(email: "student@wku.edu.cn", accessToken: "other", expiresAt: .distantFuture,
                                  serverURL: URL(string: "https://other.test")!, room: user().room)
        XCTAssertFalse(LoginManager(api: api(), store: store).isLoggedIn)
        store.value = nil
        defaults.set(true, forKey: "isLoggedIn")
        XCTAssertFalse(LoginManager(api: api(), store: store).isLoggedIn)
    }

    @MainActor
    func testFailedCredentialSaveDoesNotLogIn() async throws {
        MockURLProtocol.handler = { _ in
            MockReply("{\"valid\":true,\"access_token\":\"issued-token\",\"expires_in\":600,\"room_info\":\(self.roomJSON)}")
        }
        let store = MemorySessionStore()
        store.failSave = true
        let manager = LoginManager(api: api(), store: store)
        do {
            try await manager.verify(email: "student@wku.edu.cn", code: "123456")
            XCTFail("保存失败应返回错误")
        } catch { XCTAssertFalse(manager.isLoggedIn) }
    }

    @MainActor
    func testLogoutRevokesBeforeClearingAndNetworkFailureKeepsSession() async throws {
        let store = MemorySessionStore()
        store.value = user()
        let manager = LoginManager(api: api(), store: store)
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/logout")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-session")
            XCTAssertNotNil(store.value)
            throw URLError(.notConnectedToInternet)
        }
        do { try await manager.logout(); XCTFail("断网不能宣称远端会话已撤销") }
        catch { XCTAssertTrue(manager.isLoggedIn) }
        MockURLProtocol.handler = { _ in MockReply(#"{"message":"已退出登录"}"#) }
        try await manager.logout()
        XCTAssertFalse(manager.isLoggedIn)
        XCTAssertNil(store.value)
    }

    @MainActor
    func testUnauthorizedOnlyClearsMatchingSession() {
        let store = MemorySessionStore()
        store.value = user()
        let manager = LoginManager(api: api(), store: store)
        manager.handle(APIError.unauthorized, token: "previous-session")
        XCTAssertTrue(manager.isLoggedIn)
        manager.handle(APIError.unauthorized, token: "test-session")
        XCTAssertFalse(manager.isLoggedIn)
        XCTAssertNil(store.value)
    }

    func testSSEParserIgnoresCommentsAndJoinsDataLines() {
        var parser = SSEParser()
        XCTAssertNil(parser.consume(": heartbeat"))
        XCTAssertNil(parser.consume(""))
        XCTAssertNil(parser.consume("id: 123-0"))
        XCTAssertNil(parser.consume("event: progress"))
        XCTAssertNil(parser.consume("data: 第一行"))
        XCTAssertNil(parser.consume("data: 第二行"))
        XCTAssertEqual(parser.consume(""), ServerEvent(id: "123-0", name: "progress", data: "第一行\n第二行"))
        XCTAssertNil(parser.consume("data: next"))
        XCTAssertEqual(parser.consume(""), ServerEvent(id: nil, name: "message", data: "next"))
    }

    func testStreamingTransportPreservesFrameBoundaries() async throws {
        MockURLProtocol.handler = { _ in
            MockReply("event: progress\ndata: 测试\n\n", headers: ["Content-Type": "text/event-stream"])
        }
        let bytes = try await api().events(id: taskId, token: "test", lastEventId: nil)
        var parser = SSEParser()
        var events: [ServerEvent] = []
        for try await byte in bytes {
            if let event = try parser.consume(byte: byte) { events.append(event) }
        }
        XCTAssertEqual(events, [ServerEvent(id: nil, name: "progress", data: "测试")])
    }

    func testSSEBytesSupportCRLFCRAndSplitChineseCharacters() throws {
        let stream = "\u{FEFF}: connected\r\nid: 12-0\r\nevent: progress\r\ndata: 中文\r\n\r\nevent: completed\rdata: done\r\r"
        var parser = SSEParser()
        var events: [ServerEvent] = []
        for byte in stream.utf8 {
            if let event = try parser.consume(byte: byte) { events.append(event) }
        }
        XCTAssertEqual(events, [ServerEvent(id: "12-0", name: "progress", data: "中文"),
                                ServerEvent(id: nil, name: "completed", data: "done")])
    }

    func testPartialProgressDoesNotEraseCountsOrRegressOnReplay() throws {
        var current = try ServerAPI.decode(QueryTaskState.self, from: Data(state("succeeded").utf8))
        current.status = .running
        let update = try ServerAPI.decode(QueryTaskUpdate.self, from: Data("{\"task_id\":\"\(taskId)\",\"status\":\"queued\",\"completed\":0}".utf8))
        try current.apply(update)
        XCTAssertEqual(current.completed, 1)
        XCTAssertEqual(current.succeeded, 1)
        XCTAssertEqual(current.status, .running)
        let other = try ServerAPI.decode(QueryTaskUpdate.self, from: Data(#"{"task_id":"other","status":"running"}"#.utf8))
        XCTAssertThrowsError(try current.apply(other))
    }

    @MainActor
    func testTaskUsesEmptyScopeAndPersistsIdempotencyAcrossLostResponse() async throws {
        var keys: [String] = []
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-session")
            if request.httpMethod == "POST" {
                XCTAssertTrue(try self.body(request).isEmpty)
                keys.append(try XCTUnwrap(request.value(forHTTPHeaderField: "Idempotency-Key")))
                if keys.count == 1 { throw URLError(.networkConnectionLost) }
                return MockReply(self.state("succeeded"), status: 202)
            }
            return MockReply(self.state("succeeded"))
        }
        let model = QueryTaskModel(defaults: defaults)
        model.start(api: api(), session: user())
        try await waitUntil { model.finishedTaskId != nil }
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(Set(keys).count, 1)
        XCTAssertFalse(model.hasPendingQuery)
    }

    @MainActor
    func testSSEReconnectUsesLastEventIdAndDoesNotSubmitAgain() async throws {
        var submissions = 0
        var cursors: [String?] = []
        MockURLProtocol.handler = { request in
            if request.httpMethod == "POST" { submissions += 1; return MockReply(self.state("queued"), status: 202) }
            if request.url!.path.hasSuffix("/events") {
                cursors.append(request.value(forHTTPHeaderField: "Last-Event-ID"))
                let text = cursors.count == 1
                    ? "id: 100-0\nevent: progress\ndata: {\"task_id\":\"\(self.taskId)\",\"status\":\"running\",\"stage\":\"querying\"}\n\n"
                    : "id: 101-0\nevent: completed\ndata: \(self.state("succeeded"))\n\n"
                var reply = MockReply(text, headers: ["Content-Type": "text/event-stream"])
                let bytes = Array(text.utf8)
                reply.chunks = bytes.map { Data([$0]) }
                return reply
            }
            return MockReply(self.state())
        }
        let model = QueryTaskModel(defaults: defaults)
        model.start(api: api(), session: user())
        try await waitUntil { model.finishedTaskId != nil }
        XCTAssertEqual(submissions, 1)
        XCTAssertEqual(cursors.count, 2)
        XCTAssertNil(cursors[0])
        XCTAssertEqual(cursors[1], "100-0")
        XCTAssertEqual(model.task?.completed, 1)
    }

    @MainActor
    func testAppRestartResumesSavedTaskAndCursor() async throws {
        var submissions = 0
        var cursors: [String?] = []
        MockURLProtocol.handler = { request in
            if request.httpMethod == "POST" { submissions += 1; return MockReply(self.state("queued"), status: 202) }
            if request.url!.path.hasSuffix("/events") {
                cursors.append(request.value(forHTTPHeaderField: "Last-Event-ID"))
                let payload = cursors.count == 1 ? self.state() : self.state("succeeded")
                return MockReply("id: 200-0\nevent: progress\ndata: \(payload)\n\n", headers: ["Content-Type": "text/event-stream"])
            }
            return MockReply(self.state())
        }
        let first = QueryTaskModel(defaults: defaults)
        first.start(api: api(), session: user())
        try await waitUntil { first.progressMessage.contains("1 秒后") }
        first.suspend()
        let restored = QueryTaskModel(defaults: defaults)
        restored.restore(api: api(), session: user())
        try await waitUntil { restored.finishedTaskId != nil }
        XCTAssertEqual(submissions, 1)
        XCTAssertEqual(cursors.last!, "200-0")
        XCTAssertFalse(restored.hasPendingQuery)
    }

    @MainActor
    func testDefinitePublishFailureAllowsNewSubmissionKey() async throws {
        var keys: [String] = []
        MockURLProtocol.handler = { request in
            if request.httpMethod == "POST" {
                keys.append(request.value(forHTTPHeaderField: "Idempotency-Key")!)
                if keys.count == 1 {
                    return MockReply("{\"error\":\"任务入队失败\",\"task_id\":\"\(self.taskId)\"}", status: 503)
                }
                return MockReply(self.state("succeeded"), status: 202)
            }
            return MockReply(self.state("succeeded"))
        }
        let model = QueryTaskModel(defaults: defaults)
        model.start(api: api(), session: user())
        try await waitUntil { model.errorMessage != nil && !model.isMonitoring }
        XCTAssertFalse(model.hasPendingQuery)
        model.start(api: api(), session: user())
        try await waitUntil { model.finishedTaskId != nil }
        XCTAssertEqual(Set(keys).count, 2)
    }

    @MainActor
    func testRevokedSSESessionStopsAndRequestsLogin() async throws {
        MockURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("/events") {
                return MockReply("event: auth_expired\ndata: {\"error\":\"登录失效\"}\n\n", headers: ["Content-Type": "text/event-stream"])
            }
            return MockReply(self.state(), status: request.httpMethod == "POST" ? 202 : 200)
        }
        let model = QueryTaskModel(defaults: defaults)
        model.start(api: api(), session: user())
        try await waitUntil { model.expiredToken != nil }
        XCTAssertEqual(model.expiredToken, "test-session")
        XCTAssertTrue(model.hasPendingQuery)
    }

    @MainActor
    func testExpiredTaskCanBeSubmittedAgain() async throws {
        MockURLProtocol.handler = { request in
            request.httpMethod == "POST" ? MockReply(self.state(), status: 202) : MockReply(#"{"error":"任务不存在"}"#, status: 404)
        }
        let model = QueryTaskModel(defaults: defaults)
        model.start(api: api(), session: user())
        try await waitUntil { model.errorMessage != nil }
        XCTAssertFalse(model.hasPendingQuery)
        XCTAssertEqual(model.errorMessage, APIError.taskExpired.localizedDescription)
    }

    @MainActor
    func testPendingTasksAreScopedToAccountAndServer() async throws {
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let first = QueryTaskModel(defaults: defaults)
        first.start(api: api(), session: user())
        try await waitUntil { first.progressMessage.contains("1 秒后") }
        first.suspend()
        let second = QueryTaskModel(defaults: defaults)
        second.restore(api: api(), session: user(email: "other@wku.edu.cn"))
        XCTAssertFalse(second.hasPendingQuery)
        let elsewhere = QueryTaskModel(defaults: defaults)
        let differentServer = UserSession(email: user().email, accessToken: "new", expiresAt: .distantFuture,
                                          serverURL: URL(string: "https://other.test")!, room: user().room)
        elsewhere.restore(api: api(), session: differentServer)
        XCTAssertFalse(elsewhere.hasPendingQuery)
    }

    @MainActor
    func testLocalHistoryIsAccountScopedAndKeepsStableIds() throws {
        let first = HistoryManager(scope: user().storageScope, defaults: defaults)
        first.addHistory(roomName: "101", cardBalance: "10", waterBalance: 2, electricityBalance: 3)
        let again = HistoryManager(scope: user().storageScope, defaults: defaults)
        XCTAssertEqual(again.histories.first?.id, first.histories.first?.id)
        XCTAssertTrue(HistoryManager(scope: user(email: "other@wku.edu.cn").storageScope, defaults: defaults).histories.isEmpty)
        XCTAssertTrue(HistoryManager(scope: "another-server", defaults: defaults).histories.isEmpty)
    }

    @MainActor
    func testLegacyHistoryOnlyMigratesToItsRecordedOwner() throws {
        let record = QueryHistory(date: Date(), roomName: "101", cardBalance: "1", waterBalance: 2, electricityBalance: 3)
        defaults.set(try JSONEncoder().encode([record]), forKey: "QueryHistories")
        defaults.set("student@wku.edu.cn", forKey: "userEmail")
        XCTAssertTrue(HistoryManager(scope: "other", legacyEmail: "other@wku.edu.cn", defaults: defaults).histories.isEmpty)
        let matching = HistoryManager(scope: user().storageScope, legacyEmail: user().email, defaults: defaults)
        XCTAssertEqual(matching.histories.count, 1)
        XCTAssertNotNil(defaults.data(forKey: "QueryHistories"))
    }

    func testLegacyCardCredentialNeverLeaksToAnotherAccount() {
        defaults.set("student@wku.edu.cn", forKey: "userEmail")
        defaults.set("legacy-card-cookie", forKey: "cardUserId")
        XCTAssertNil(Config.cardUserId(for: "other@wku.edu.cn", defaults: defaults))
        XCTAssertEqual(Config.cardUserId(for: "student@wku.edu.cn", defaults: defaults), "legacy-card-cookie")
        defaults.set("", forKey: "cardUserId|student@wku.edu.cn")
        XCTAssertNil(Config.cardUserId(for: "student@wku.edu.cn", defaults: defaults))
    }

    @MainActor
    func testHistoryUsesBearerAndRetainsServerSuccessFlags() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url!.path, "/api/query_history/student@wku.edu.cn")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-session")
            return MockReply(#"{"history":[{"date":"2026-10-26","query_time":"2026-10-26T10:20:30.123456","room_name":"101","water_balance":1.5,"water_unit":"元","water_success":true,"electricity_balance":null,"electricity_unit":"度","electricity_success":false}]}"#)
        }
        let history = HistoryManager(scope: user().storageScope, defaults: defaults)
        try await history.refresh(api: api(), session: user())
        XCTAssertEqual(history.serverHistories.first?.displayTime, "2026-10-26 10:20:30")
        XCTAssertEqual(history.serverHistories.first?.waterBalance, 1.5)
        XCTAssertEqual(history.serverHistories.first?.electricitySuccess, false)
        XCTAssertNil(history.serverHistories.first?.electricityBalance)
        XCTAssertTrue(history.histories.isEmpty)
    }

    func testRateLimitExposesRetryAfterWithoutPretendingSuccess() async throws {
        MockURLProtocol.handler = { _ in
            MockReply(#"{"error":"申请过于频繁"}"#, status: 429,
                      headers: ["Content-Type": "application/json", "Retry-After": "45"])
        }
        do { try await api().sendCode(email: "student@wku.edu.cn"); XCTFail("限流不能成功") }
        catch APIError.http(let status, _, let seconds, _) {
            XCTAssertEqual(status, 429)
            XCTAssertEqual(seconds, 45)
        }
    }

    func testHTTPUnauthorizedIsRecognizedForDataAndEvents() async throws {
        MockURLProtocol.handler = { _ in MockReply(#"{"error":"登录失效"}"#, status: 401) }
        do { _ = try await api().history(email: "student@wku.edu.cn", token: "old"); XCTFail("应拒绝") }
        catch APIError.unauthorized { }
        do { _ = try await api().events(id: taskId, token: "old", lastEventId: nil); XCTFail("应拒绝") }
        catch APIError.unauthorized { }
    }
}
