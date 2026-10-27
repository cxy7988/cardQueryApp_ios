import Foundation

struct BoundRoom: Codable, Equatable, Sendable {
    let buildingCode: String
    let buildingName: String
    let floorCode: String
    let floorName: String
    let roomCode: String
    let roomName: String

    var displayName: String { "\(buildingName) \(floorName) \(roomName)" }
}

struct LoginResponse: Decodable {
    let valid: Bool
    let accessToken: String
    let expiresIn: Int
    let roomInfo: BoundRoom?
}

enum QueryTaskStatus: String, Codable {
    case queued, running, succeeded, partial, failed

    var isTerminal: Bool { self == .succeeded || self == .partial || self == .failed }
}

struct QueryTaskState: Decodable, Equatable {
    let taskId: String
    var status: QueryTaskStatus
    var total: Int
    var completed: Int
    var succeeded: Int
    var failed: Int
    var error: String?

    mutating func apply(_ update: QueryTaskUpdate) throws {
        guard update.taskId == taskId else { throw APIError.invalidResponse }
        if let value = update.status, !(status == .running && value == .queued) { status = value }
        if let value = update.total { total = max(total, value) }
        if let value = update.completed { completed = max(completed, value) }
        if let value = update.succeeded { succeeded = max(succeeded, value) }
        if let value = update.failed { failed = max(failed, value) }
        if let value = update.error { error = value }
    }
}

// progress 事件只携带变化的字段，不能把省略的计数重置为零。
struct QueryTaskUpdate: Decodable {
    let taskId: String
    let status: QueryTaskStatus?
    let stage: String?
    let total: Int?
    let completed: Int?
    let succeeded: Int?
    let failed: Int?
    let error: String?
}

struct ServerHistoryRecord: Decodable, Identifiable {
    let date: String
    let queryTime: String?
    let roomName: String?
    let electricityBalance: Double?
    let electricityUnit: String
    let electricitySuccess: Bool
    let waterBalance: Double?
    let waterUnit: String
    let waterSuccess: Bool

    var id: String { date }
    // 后端的 query_time 没有时区，原样显示，不擅自按设备时区转换。
    var displayTime: String { String((queryTime ?? date).replacingOccurrences(of: "T", with: " ").prefix(19)) }
}

enum APIError: LocalizedError {
    case unauthorized
    case invalidResponse
    case http(Int, String, retryAfter: Int?, failedTaskId: String?)
    case streamInterrupted
    case taskExpired
    case streamUnavailable

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "登录已失效，请重新验证邮箱"
        case .invalidResponse: return "服务器响应格式不正确，请确认已部署新版后端"
        case let .http(_, message, retryAfter, _):
            return retryAfter.map { "\(message)，请在 \($0) 秒后重试" } ?? message
        case .streamInterrupted: return "进度连接已中断，可继续连接原任务"
        case .taskExpired: return "任务记录已过期，请重新查询"
        case .streamUnavailable: return "进度服务暂不可用，可继续连接原任务"
        }
    }

    var isTransient: Bool {
        switch self {
        case .http(let code, _, _, let taskId): return code >= 500 && taskId == nil
        case .streamInterrupted, .streamUnavailable: return true
        default: return false
        }
    }
}

struct ServerEvent: Equatable {
    let id: String?
    let name: String
    let data: String
}

// AsyncBytes.lines 会跳过空行，而 SSE 用空行分帧，因此直接解析字节流。
struct SSEParser {
    private var lineBuffer = Data()
    private var previousWasCR = false
    private var firstLine = true
    private var eventId: String?
    private var name = "message"
    private var data: [String] = []

    mutating func consume(byte: UInt8) throws -> ServerEvent? {
        if byte == 10 && previousWasCR {
            previousWasCR = false
            return nil
        }
        previousWasCR = false
        if byte == 10 || byte == 13 {
            guard var line = String(data: lineBuffer, encoding: .utf8) else { throw APIError.invalidResponse }
            lineBuffer.removeAll(keepingCapacity: true)
            previousWasCR = byte == 13
            if firstLine {
                firstLine = false
                if line.hasPrefix("\u{FEFF}") { line.removeFirst() }
            }
            return consume(line)
        }
        guard lineBuffer.count < 65_536 else { throw APIError.invalidResponse }
        lineBuffer.append(byte)
        return nil
    }

    mutating func consume(_ line: String) -> ServerEvent? {
        if line.isEmpty {
            let event = data.isEmpty ? nil : ServerEvent(id: eventId, name: name, data: data.joined(separator: "\n"))
            eventId = nil
            name = "message"
            data = []
            return event
        }
        guard !line.hasPrefix(":") else { return nil }
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        var value = parts.count == 2 ? String(parts[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }
        switch parts[0] {
        case "id": if !value.contains("\0") { eventId = value }
        case "event": name = value
        case "data": data.append(value)
        default: break
        }
        return nil
    }
}

struct ServerAPI {
    // 沿用原客户端地址；部署地址变更时只需修改这里。
    static let live = ServerAPI(baseURL: URL(string: "https://wkuquery.asia:5000")!)
    let baseURL: URL
    var session: URLSession = .shared

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    func sendCode(email: String) async throws {
        let _: MessageResponse = try await request("api/send_code", method: "POST", body: ["email": email])
    }

    func verifyCode(email: String, code: String) async throws -> LoginResponse {
        try await request("api/verify_code", method: "POST", body: ["email": email, "code": code])
    }

    func bindRoom(_ room: BoundRoom, email: String, token: String) async throws -> LoginResponse {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let roomJSON = try JSONSerialization.jsonObject(with: encoder.encode(room))
        return try await request("api/verify_code_with_room", method: "POST",
                                 body: ["email": email, "room_info": roomJSON], token: token)
    }

    func logout(token: String) async throws {
        let _: MessageResponse = try await request("api/logout", method: "POST", body: [:], token: token)
    }

    func submitTask(token: String, idempotencyKey: String) async throws -> QueryTaskState {
        try await request("api/tasks", method: "POST", body: [:], token: token,
                          headers: ["Idempotency-Key": idempotencyKey])
    }

    func task(id: String, token: String) async throws -> QueryTaskState {
        try await request("api/tasks/\(id)", token: token)
    }

    func history(email: String, token: String) async throws -> [ServerHistoryRecord] {
        let response: HistoryResponse = try await request("api/query_history/\(email)", token: token)
        return response.history
    }

    func events(id: String, token: String, lastEventId: String?) async throws -> URLSession.AsyncBytes {
        var request = makeRequest("api/tasks/\(id)/events", token: token)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let lastEventId { request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID") }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            bytes.task.cancel()
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            // 错误响应是短 JSON；不要把无限的成功流缓冲到内存。
            var data = Data()
            do {
                for try await byte in bytes {
                    data.append(byte)
                    if data.count >= 16_384 { break }
                }
            } catch {
                bytes.task.cancel()
                throw error
            }
            bytes.task.cancel()
            try validate(http, data: data)
            throw APIError.invalidResponse
        }
        guard http.mimeType == "text/event-stream" else {
            bytes.task.cancel()
            throw APIError.invalidResponse
        }
        return bytes
    }

    private func makeRequest(_ path: String, token: String?) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 45)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return request
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil,
                                       token: String? = nil, headers: [String: String] = [:]) async throws -> T {
        var request = makeRequest(path, token: token)
        request.httpMethod = method
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        try validate(http, data: data)
        do { return try Self.decode(T.self, from: data) }
        catch { throw APIError.invalidResponse }
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        if response.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(response.statusCode) else {
            let error = try? Self.decode(ErrorResponse.self, from: data)
            throw APIError.http(response.statusCode, error?.error ?? "请求失败（\(response.statusCode)）",
                                retryAfter: error?.retryAfter ?? response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init),
                                failedTaskId: error?.taskId)
        }
    }

    private struct MessageResponse: Decodable { let message: String }
    private struct HistoryResponse: Decodable { let history: [ServerHistoryRecord] }
    private struct ErrorResponse: Decodable { let error: String; let retryAfter: Int?; let taskId: String? }
}
