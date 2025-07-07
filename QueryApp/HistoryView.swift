import SwiftUI
import Foundation

// MARK: - 历史记录数据模型
struct QueryHistory: Identifiable, Codable {
    let id = UUID()
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
        return cardBalance ?? "获取失败"
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
class HistoryManager: ObservableObject {
    @Published var histories: [QueryHistory] = []
    private let userDefaults = UserDefaults.standard
    private let historyKey = "QueryHistories"
    
    init() {
        loadHistories()
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

// MARK: - 历史查询界面
struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager()
    @State private var showingClearAlert = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if historyManager.histories.isEmpty {
                    // 空状态视图
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("暂无查询历史")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("进行查询后，历史记录将显示在这里")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 历史记录列表
                    List {
                        ForEach(historyManager.histories) { history in
                            HistoryRowView(history: history)
                        }
                        .onDelete(perform: deleteHistories)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("查询历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !historyManager.histories.isEmpty {
                        Button("清空") {
                            showingClearAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .alert("清空历史记录", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                historyManager.clearAllHistories()
            }
        } message: {
            Text("确定要清空所有历史记录吗？此操作无法撤销。")
        }
    }
    
    private func deleteHistories(offsets: IndexSet) {
        historyManager.histories.remove(atOffsets: offsets)
        historyManager.saveHistories()
    }
}

// MARK: - 历史记录行视图
struct HistoryRowView: View {
    let history: QueryHistory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 时间和房间信息
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(history.formattedDate)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let roomName = history.roomName {
                        Text(roomName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 状态指示器
                Circle()
                    .fill(getStatusColor())
                    .frame(width: 8, height: 8)
            }
            
            // 余额信息
            VStack(spacing: 8) {
                // 第一行：卡余额
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text("卡余额")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(history.cardBalanceText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(history.cardBalance != nil ? .primary : .red)
                    }
                    
                    Spacer()
                }
                
                // 第二行：水费和电费
                HStack(spacing: 20) {
                    // 水费余额
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.cyan)
                                .font(.caption)
                            Text("水费")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(history.waterBalanceText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(history.waterBalance != nil ? .primary : .red)
                    }
                    
                    // 分隔线
                    Divider()
                        .frame(height: 30)
                    
                    // 电费余额
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "bolt.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("剩余电量")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(history.electricityBalanceText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(history.electricityBalance != nil ? .primary : .red)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }
    
    private func getStatusColor() -> Color {
        let hasCardBalance = history.cardBalance != nil
        let hasWaterBalance = history.waterBalance != nil
        let hasElectricityBalance = history.electricityBalance != nil
        
        let successCount = [hasCardBalance, hasWaterBalance, hasElectricityBalance].filter { $0 }.count
        
        if successCount == 3 {
            return .green
        } else if successCount >= 1 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    HistoryView()
}
