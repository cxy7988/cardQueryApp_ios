import Combine
import Foundation

// MARK: - 历史记录数据模型
struct QueryHistory: Identifiable, Codable {
    var id = UUID()
    let date: Date
    let roomName: String?
    let cardBalance: String?
    let waterBalance: Double?
    let electricityBalance: Double?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    var cardBalanceText: String {
        if let cardBalance = cardBalance {
            if cardBalance == "未配置" {
                return "未配置卡用户ID"
            }
            return cardBalance
        }
        return "获取失败"
    }

    var waterBalanceText: String {
        if let water = waterBalance {
            return "\(water) 元"
        }
        return "获取失败"
    }

    var electricityBalanceText: String {
        if let electricity = electricityBalance {
            return "\(electricity) 度"
        }
        return "获取失败"
    }
}

// MARK: - 历史记录管理器
@MainActor
class HistoryManager: ObservableObject {
    @Published var histories: [QueryHistory] = []
    @Published private(set) var serverHistories: [ServerHistoryRecord] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var syncError: String?
    private let userDefaults: UserDefaults
    private let historyKey: String
    private var refreshId = UUID()

    init(scope: String = "preview", legacyEmail: String? = nil, defaults: UserDefaults = .standard) {
        userDefaults = defaults
        historyKey = "QueryHistories|\(scope)"
        if defaults.data(forKey: historyKey) == nil, let legacyEmail,
           defaults.string(forKey: "userEmail")?.lowercased() == legacyEmail {
            defaults.set(defaults.data(forKey: "QueryHistories"), forKey: historyKey)
        }
        loadHistories()
    }

    func refresh(api: ServerAPI, session: UserSession) async throws {
        let id = UUID()
        refreshId = id
        isRefreshing = true
        defer { if refreshId == id { isRefreshing = false } }
        do {
            let records = try await api.history(email: session.email, token: session.accessToken)
            try Task.checkCancellation()
            guard refreshId == id else { return }
            serverHistories = records
            syncError = nil
        } catch {
            if refreshId == id, !Task.isCancelled { syncError = error.localizedDescription }
            throw error
        }
    }

    func addHistory(roomName: String?, cardBalance: String?, waterBalance: Double?, electricityBalance: Double?) {
        let newHistory = QueryHistory(
            date: Date(),
            roomName: roomName,
            cardBalance: cardBalance,
            waterBalance: waterBalance,
            electricityBalance: electricityBalance
        )

        histories.insert(newHistory, at: 0) // 最新的记录插入到最前面

        // 保持最多50条记录
        if histories.count > 50 {
            histories = Array(histories.prefix(50))
        }

        saveHistories()
    }

    func clearAllHistories() {
        histories.removeAll()
        saveHistories()
    }

    func saveHistories() {
        if let encoded = try? JSONEncoder().encode(histories) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }

    private func loadHistories() {
        if let data = userDefaults.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([QueryHistory].self, from: data) {
            histories = decoded
        }
    }
}
