import SwiftUI
import Foundation

// MARK: - 历史查询界面
struct HistoryView: View {
    @EnvironmentObject var historyManager: HistoryManager
    @EnvironmentObject var loginManager: LoginManager
    @State private var showingClearAlert = false
    @State private var source = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Picker("记录来源", selection: $source) {
                    Text("服务器水电记录").tag(0)
                    Text("本机查询记录").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                List {
                    if source == 0 {
                        if let error = historyManager.syncError {
                            Text("更新失败：\(error)")
                                .font(.footnote).foregroundColor(.red)
                        }
                        if historyManager.serverHistories.isEmpty {
                            Text(historyManager.isRefreshing ? "正在读取…" : "暂无水电查询记录")
                                .foregroundColor(.secondary)
                        }
                        ForEach(historyManager.serverHistories) { record in
                            ServerHistoryRow(record: record)
                        }
                        Section {
                            Text("服务器最多返回最近 30 条每日记录；饭卡余额仅保存在本机记录中。")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    } else {
                        if historyManager.histories.isEmpty {
                            Text("暂无本机记录").foregroundColor(.secondary)
                        }
                        ForEach(historyManager.histories) { history in
                            HistoryRowView(history: history)
                        }
                        .onDelete { offsets in
                            historyManager.histories.remove(atOffsets: offsets)
                            historyManager.saveHistories()
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await refresh() }
            }
            .navigationTitle("查询历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if source == 1 && !historyManager.histories.isEmpty {
                        Button("清空本机记录") { showingClearAlert = true }
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .task { await refresh() }
        .alert("清空本机记录", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) { historyManager.clearAllHistories() }
        } message: {
            Text("将清空当前账号在此设备上的查询记录，服务器记录仍会保留。")
        }
    }

    private func refresh() async {
        guard let session = loginManager.session else { return }
        do { try await historyManager.refresh(api: loginManager.api, session: session) }
        catch { loginManager.handle(error, token: session.accessToken) }
    }
}

private struct ServerHistoryRow: View {
    let record: ServerHistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(record.displayTime).font(.subheadline).fontWeight(.medium)
            if let room = record.roomName { Text(room).font(.caption).foregroundColor(.secondary) }
            HStack {
                Label("水费", systemImage: "drop.fill").foregroundColor(.cyan)
                Spacer()
                if record.waterSuccess, let balance = record.waterBalance {
                    Text("\(balance.formatted()) \(record.waterUnit)")
                } else {
                    Text("查询失败").foregroundColor(.red)
                }
            }
            HStack {
                Label("剩余电量", systemImage: "bolt.fill").foregroundColor(.orange)
                Spacer()
                if record.electricitySuccess, let balance = record.electricityBalance {
                    Text("\(balance.formatted()) \(record.electricityUnit)")
                } else {
                    Text("查询失败").foregroundColor(.red)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 8)
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
                            .foregroundColor({
                                if let cardBalance = history.cardBalance {
                                    return cardBalance == "未配置" ? .orange : .primary
                                } else {
                                    return .red
                                }
                            }())
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
        
        // 计算成功或有配置的项目数量
        let validCount = [hasCardBalance, hasWaterBalance, hasElectricityBalance].filter { $0 }.count
        
        if validCount == 3 {
            return .green
        } else if validCount >= 1 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(HistoryManager())
        .environmentObject(LoginManager())
}
