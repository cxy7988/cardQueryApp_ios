import Foundation
import Combine
import Security

struct UserSession: Codable, Equatable {
    let email: String
    let accessToken: String
    let expiresAt: Date
    let serverURL: URL
    let room: BoundRoom?

    var isExpired: Bool { expiresAt <= Date() }
    var storageScope: String { "\(serverURL.absoluteString)|\(email)" }
}

protocol SessionStore {
    func load() throws -> UserSession?
    func save(_ session: UserSession) throws
    func clear() throws
}

struct KeychainSessionStore: SessionStore {
    private let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.cardquery.session",
        kSecAttrAccount as String: "server-session"
    ]

    func load() throws -> UserSession? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try check(status)
        guard let data = result as? Data else { throw APIError.invalidResponse }
        return try JSONDecoder().decode(UserSession.self, from: data)
    }

    func save(_ session: UserSession) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(session),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            try check(SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil))
        } else {
            try check(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecItemNotFound { try check(status) }
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "无法访问登录凭据（\(status)），请解锁设备后重试"
            ])
        }
    }
}

@MainActor
class LoginManager: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published var sessionMessage: String?
    let api: ServerAPI
    private let store: SessionStore

    var isLoggedIn: Bool { session?.room != nil }
    var userEmail: String { session?.email ?? "" }

    init(api: ServerAPI = .live, store: SessionStore = KeychainSessionStore()) {
        self.api = api
        self.store = store
        do {
            if let saved = try store.load(), saved.serverURL == api.baseURL, !saved.isExpired {
                session = saved
            }
        } catch {
            sessionMessage = error.localizedDescription
        }
        // 旧版只保存了一个布尔值，它不能作为新版登录凭据。
    }

    func verify(email: String, code: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let response = try await api.verifyCode(email: email, code: code)
        try Task.checkCancellation()
        try accept(response, email: email)
    }

    func bindRoom(_ room: BoundRoom) async throws {
        let current = try requireSession()
        do {
            let response = try await api.bindRoom(room, email: current.email, token: current.accessToken)
            try Task.checkCancellation()
            guard session?.accessToken == current.accessToken else { return }
            try accept(response, email: current.email)
        } catch {
            handle(error, token: current.accessToken)
            throw error
        }
    }

    func logout() async throws {
        guard let current = session else { return }
        do { try await api.logout(token: current.accessToken) }
        catch APIError.unauthorized { /* 已经失效的会话可以直接退出。 */ }
        try Task.checkCancellation()
        guard session?.accessToken == current.accessToken else { return }
        try store.clear()
        session = nil
        sessionMessage = nil
    }

    func requireSession() throws -> UserSession {
        guard let current = session else { throw APIError.unauthorized }
        if current.isExpired {
            handle(APIError.unauthorized, token: current.accessToken)
            throw APIError.unauthorized
        }
        return current
    }

    func expireIfNeeded() {
        if let current = session, current.isExpired {
            handle(APIError.unauthorized, token: current.accessToken)
        }
    }

    func handle(_ error: Error, token: String) {
        guard case APIError.unauthorized = error, session?.accessToken == token else { return }
        try? store.clear()
        session = nil
        sessionMessage = error.localizedDescription
    }

    private func accept(_ response: LoginResponse, email: String) throws {
        guard response.valid, !response.accessToken.isEmpty, response.expiresIn > 0 else {
            throw APIError.invalidResponse
        }
        let value = UserSession(email: email, accessToken: response.accessToken,
                                expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
                                serverURL: api.baseURL, room: response.roomInfo)
        try store.save(value)
        session = value
        sessionMessage = nil
    }
}
