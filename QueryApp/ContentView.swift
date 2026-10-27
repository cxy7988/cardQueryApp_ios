import SwiftUI
import Foundation

struct ContentView: View {
    let session: UserSession
    @State private var balanceText = "未获取余额"
    @State private var cardBalance: String? = "未查询"
    @State private var isCardQuerying = false
    @State private var isFinalizing = false
    @State private var completedRecord: ServerHistoryRecord?
    @State private var snapshotReady = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @StateObject private var query = QueryTaskModel()
    @StateObject private var historyManager: HistoryManager
    @EnvironmentObject var loginManager: LoginManager
    @Environment(\.scenePhase) private var scenePhase

    init(session: UserSession) {
        self.session = session
        _historyManager = StateObject(wrappedValue: HistoryManager(scope: session.storageScope, legacyEmail: session.email))
    }

    private var latest: ServerHistoryRecord? { historyManager.serverHistories.first }

    private var waterText: String {
        guard let latest else { return "未获取水费" }
        guard latest.waterSuccess, let balance = latest.waterBalance else { return "最近一次水费查询未成功" }
        return "水费余额：\(balance.formatted()) \(latest.waterUnit)"
    }

    private var electricityText: String {
        guard let latest else { return "未获取电费" }
        guard latest.electricitySuccess, let balance = latest.electricityBalance else { return "最近一次电费查询未成功" }
        return "剩余电量：\(balance.formatted()) \(latest.electricityUnit)"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        InfoCard(icon: "house.fill", iconColor: .green,
                                 text: session.room?.displayName ?? "未绑定宿舍")
                        InfoCard(icon: "creditcard.fill", iconColor: .blue, text: balanceText)
                        InfoCard(icon: "drop.fill", iconColor: .cyan, text: waterText)
                        InfoCard(icon: "bolt.circle.fill", iconColor: .orange, text: electricityText)
                    }
                    .padding(.top, 8)

                    if let latest {
                        Text("最近的水电记录：\(latest.displayTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button(action: startQuery) {
                        HStack(spacing: 8) {
                            if query.isMonitoring {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(query.isMonitoring || isCardQuerying || isFinalizing ? "查询中…" : (query.hasPendingQuery ? "继续连接查询" : "查询"))
                        }
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(query.isMonitoring || isCardQuerying || isFinalizing)

                    if !query.progressMessage.isEmpty {
                        VStack(spacing: 8) {
                            Text(query.progressMessage)
                                .font(.subheadline)
                            if let task = query.task, task.total > 0 {
                                ProgressView(value: Double(task.completed), total: Double(task.total))
                                Text("已完成 \(task.completed)/\(task.total)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    if let error = query.errorMessage {
                        Text(error).font(.footnote).foregroundColor(.red)
                    }
                    if let error = historyManager.syncError {
                        VStack(spacing: 8) {
                            Text("历史记录更新失败：\(error)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Button("重新读取记录") { Task { await refreshHistory() } }
                                .font(.footnote)
                        }
                    }

                    AppGuideView().padding(.top, 12)
                }
                .padding(20)
            }
            .refreshable { await refreshHistory() }
            .navigationTitle("费用查询")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("查询历史")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("应用设置")
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingHistory) {
                HistoryView().environmentObject(historyManager)
            }
        }
        .task {
            query.restore(api: loginManager.api, session: session)
            await refreshHistory()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                query.restore(api: loginManager.api, session: session)
            } else {
                query.suspend()
            }
        }
        .onDisappear { query.suspend() }
        .onChange(of: query.expiredToken) { _, token in
            if let token { loginManager.handle(APIError.unauthorized, token: token) }
        }
        .onChange(of: query.finishedTaskId) { _, id in
            guard id != nil else { return }
            isFinalizing = true
            Task {
                let refreshed = await refreshHistory()
                completedRecord = refreshed && query.task?.status == .succeeded ? latest : nil
                snapshotReady = true
                saveSnapshotIfReady()
            }
        }
    }

    private func startQuery() {
        do {
            let current = try loginManager.requireSession()
            if !query.hasPendingQuery {
                let hasCard = Config.cardUserId(for: current.email) != nil
                cardBalance = hasCard ? nil : "未配置"
                isCardQuerying = hasCard
                balanceText = hasCard ? "正在查询饭卡余额…" : "未配置卡用户ID"
                getCardMoney(email: current.email) { balance in
                    DispatchQueue.main.async {
                        cardBalance = hasCard ? balance : "未配置"
                        isCardQuerying = false
                        if let balance { balanceText = "卡余额：\(balance) 元" }
                        else { balanceText = hasCard ? "饭卡余额查询失败" : "未配置卡用户ID" }
                        saveSnapshotIfReady()
                    }
                }
            }
            query.start(api: loginManager.api, session: current)
        } catch {
            loginManager.handle(error, token: session.accessToken)
        }
    }

    private func saveSnapshotIfReady() {
        guard snapshotReady, !isCardQuerying else { return }
        historyManager.addHistory(roomName: session.room?.displayName, cardBalance: cardBalance,
                                  waterBalance: completedRecord?.waterSuccess == true ? completedRecord?.waterBalance : nil,
                                  electricityBalance: completedRecord?.electricitySuccess == true ? completedRecord?.electricityBalance : nil)
        snapshotReady = false
        completedRecord = nil
        isFinalizing = false
    }

    @discardableResult
    private func refreshHistory() async -> Bool {
        do {
            let current = try loginManager.requireSession()
            try await historyManager.refresh(api: loginManager.api, session: current)
            return true
        } catch {
            if !Task.isCancelled { loginManager.handle(error, token: session.accessToken) }
            return false
        }
    }
}

// MARK: - InfoCard 组件
struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            // 文本
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - AppGuideView
struct AppGuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                Text("使用说明")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            // 使用步骤
            VStack(alignment: .leading, spacing: 16) {
                GuideStep(
                    number: "1",
                    title: "绑定宿舍",
                    description: "首次验证邮箱后选择宿舍，之后登录会自动读取已绑定的宿舍",
                    icon: "house.fill",
                    color: .orange
                )
                
                GuideStep(
                    number: "2",
                    title: "饭卡配置（可选）",
                    description: "在设置中填写饭卡用户ID，未填写时仅查询水电余额",
                    icon: "wrench.fill",
                    color: .purple
                )
                
                GuideStep(
                    number: "3",
                    title: "开始查询",
                    description: "提交后可查看查询进度，暂时离开应用后可继续查看结果",
                    icon: "magnifyingglass",
                    color: .blue
                )
            }
            
            // 配置说明
            VStack(alignment: .leading, spacing: 12) {
                Text("配置说明")
                    .font(.headline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    ConfigInfo(
                        title: "房间配置",
                        description: "必须完成才能查询水电费",
                        status: .required
                    )
                    
                    ConfigInfo(
                        title: "卡用户ID",
                        description: "可选配置，未设置时跳过卡余额查询",
                        status: .optional
                    )
                    
                    ConfigInfo(
                        title: "开发者参数",
                        description: "本机可设置饭卡参数，水电查询配置由服务器管理",
                        status: .advanced
                    )
                }
            }
            
            // 抓包教程
            VStack(alignment: .leading, spacing: 12) {
                Text("参数获取方法")
                    .font(.headline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("1.")
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                            .frame(width: 20, alignment: .leading)
                        Text("下载Fiddler everywhere，手机连接到同一Wi-Fi网络")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("2.")
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                            .frame(width: 20, alignment: .leading)
                        Text("在官方查询页面进行一次查询操作")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Text("3.")
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                            .frame(width: 20, alignment: .leading)
                        Text("从请求头Cookie中获取shiroJID值，从请求参数中获取相应ID")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 隐私说明
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    Text("隐私与安全")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("邮箱、宿舍和水电记录保存在查询服务器，用于身份验证和历史查询")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("登录凭据保存在设备钥匙串，本机记录按账号分别保存")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("水电查询通过查询服务器执行，饭卡查询访问校园官方接口")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - GuideStep
struct GuideStep: View {
    let number: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // 步骤编号和图标
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 32, height: 32)
                    
                    Text(number)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - ConfigInfo
struct ConfigInfo: View {
    let title: String
    let description: String
    let status: ConfigStatus
    
    enum ConfigStatus {
        case required, optional, advanced
        
        var color: Color {
            switch self {
            case .required: return .red
            case .optional: return .orange
            case .advanced: return .purple
            }
        }
        
        var label: String {
            switch self {
            case .required: return "必需"
            case .optional: return "可选"
            case .advanced: return "高级"
            }
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(status.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(status.color.opacity(0.1))
                )
        }
        .padding(.vertical, 4)
    }
}

// 预览
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(session: UserSession(email: "preview@wku.edu.cn", accessToken: "preview",
                                        expiresAt: .distantFuture, serverURL: ServerAPI.live.baseURL, room: nil))
            .environmentObject(LoginManager())
    }
}

