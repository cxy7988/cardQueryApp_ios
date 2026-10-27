import Foundation
import Combine

private struct PendingQuery: Codable {
    let idempotencyKey: String
    var taskId: String?
    var lastEventId: String?
}

@MainActor
class QueryTaskModel: ObservableObject {
    @Published private(set) var task: QueryTaskState?
    @Published private(set) var isMonitoring = false
    @Published private(set) var hasPendingQuery = false
    @Published private(set) var progressMessage = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var expiredToken: String?
    @Published private(set) var finishedTaskId: String?

    private let defaults: UserDefaults
    private var storageKey = ""
    private var pending: PendingQuery?
    private var operation: Task<Void, Never>?
    private var generation = UUID()

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func restore(api: ServerAPI, session: UserSession) {
        configure(session)
        if pending != nil { start(api: api, session: session) }
    }

    func start(api: ServerAPI, session: UserSession) {
        guard operation == nil else { return }
        configure(session)
        if pending == nil {
            // 在发出 POST 之前保存幂等键；响应丢失或 App 重启仍重试同一提交。
            pending = PendingQuery(idempotencyKey: UUID().uuidString)
            savePending()
            task = nil
        }
        errorMessage = nil
        expiredToken = nil
        progressMessage = pending?.taskId == nil ? "正在提交查询任务…" : "正在恢复查询进度…"
        isMonitoring = true
        let currentGeneration = UUID()
        generation = currentGeneration
        operation = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == currentGeneration {
                    operation = nil
                    isMonitoring = false
                }
            }
            await run(api: api, session: session)
        }
    }

    // iOS 挂起时停止本地连接；服务器任务继续执行，回来后读取同一 task_id。
    func suspend() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        isMonitoring = false
    }

    private func configure(_ session: UserSession) {
        let key = "PendingQuery|\(session.storageScope)"
        guard storageKey != key else { return }
        storageKey = key
        pending = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(PendingQuery.self, from: $0) }
        hasPendingQuery = pending != nil
    }

    private func savePending() {
        if let pending, let data = try? JSONEncoder().encode(pending) {
            defaults.set(data, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
        hasPendingQuery = pending != nil
    }

    private func run(api: ServerAPI, session: UserSession) async {
        var retryCount = 0
        var resetCursor = false
        while !Task.isCancelled {
            do {
                if session.isExpired { throw APIError.unauthorized }
                guard let request = pending else { return }
                if request.taskId == nil {
                    let state = try await api.submitTask(token: session.accessToken, idempotencyKey: request.idempotencyKey)
                    try Task.checkCancellation()
                    guard UUID(uuidString: state.taskId) != nil else { throw APIError.invalidResponse }
                    pending?.taskId = state.taskId
                    task = state
                    savePending()
                }
                guard let id = pending?.taskId else { throw APIError.invalidResponse }
                let state = try await api.task(id: id, token: session.accessToken)
                try Task.checkCancellation()
                guard state.taskId == id else { throw APIError.invalidResponse }
                task = state
                if state.status.isTerminal {
                    finish(state)
                    return
                }
                progressMessage = state.status == .queued ? "任务已提交，等待执行…" : "正在查询水电余额…"
                try await consumeEvents(api: api, session: session, id: id)
                if let state = task, state.status.isTerminal {
                    finish(state)
                    return
                }
                throw APIError.streamInterrupted
            } catch {
                if Task.isCancelled || error is CancellationError { return }
                if case APIError.unauthorized = error {
                    expiredToken = session.accessToken
                } else if case APIError.http(404, _, _, _) = error {
                    pending = nil
                    savePending()
                    errorMessage = APIError.taskExpired.localizedDescription
                    return
                } else if case APIError.taskExpired = error {
                    pending = nil
                    savePending()
                } else if case APIError.http(400, _, _, _) = error,
                          pending?.lastEventId != nil, !resetCursor {
                    // 服务端拒绝不合法的游标时，重新回放原任务。
                    pending?.lastEventId = nil
                    savePending()
                    resetCursor = true
                    continue
                } else if case APIError.http(let code, _, _, let failedId) = error,
                          failedId != nil || code == 400 || code == 409 {
                    pending = nil
                    savePending()
                }
                let transient = (error as? APIError)?.isTransient ?? (error is URLError)
                if transient && retryCount < 4 {
                    let delay = 1 << retryCount
                    retryCount += 1
                    progressMessage = "连接中断，\(delay) 秒后继续原任务（\(retryCount)/4）…"
                    do { try await Task.sleep(for: .seconds(delay)) }
                    catch { return }
                    continue
                }
                errorMessage = error.localizedDescription
                progressMessage = hasPendingQuery ? "任务已保留，可继续连接" : ""
                return
            }
        }
    }

    private func consumeEvents(api: ServerAPI, session: UserSession, id: String) async throws {
        let bytes = try await api.events(id: id, token: session.accessToken, lastEventId: pending?.lastEventId)
        defer { bytes.task.cancel() }
        var parser = SSEParser()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard let event = try parser.consume(byte: byte) else { continue }
            switch event.name {
            case "auth_expired": throw APIError.unauthorized
            case "expired": throw APIError.taskExpired
            case "stream_error": throw APIError.streamUnavailable
            case "queued", "started", "progress", "completed", "failed":
                let update = try ServerAPI.decode(QueryTaskUpdate.self, from: Data(event.data.utf8))
                guard var state = task else { throw APIError.invalidResponse }
                try state.apply(update)
                task = state
                // 只有完整解析、应用事件后才前移游标，避免丢失未处理事件。
                if let id = event.id { pending?.lastEventId = id }
                savePending()
                progressMessage = state.status == .queued ? "等待执行…" : "正在查询水电余额…"
                if state.status.isTerminal { return }
            default: continue
            }
        }
    }

    private func finish(_ state: QueryTaskState) {
        pending = nil
        savePending()
        finishedTaskId = state.taskId
        switch state.status {
        case .succeeded: progressMessage = "查询完成"
        case .partial: progressMessage = "查询完成，部分项目未成功"
        default:
            progressMessage = "查询未成功"
            errorMessage = state.error ?? "未能完整获取水电余额，可查看历史中的部分结果或稍后重新查询"
        }
    }
}
