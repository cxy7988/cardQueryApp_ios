import SwiftUI
import Foundation

// MARK: - 水费查询响应数据结构
struct WaterResponse: Codable {
    let data: WaterData?
}

struct WaterData: Codable {
    let surplus: Double  // 水费返回的是surplus字段
    let displayRoomName: String
}

// MARK: - 电费查询响应数据结构
struct ElectricityResponse: Codable {
    let data: ElectricityData?
}

struct ElectricityData: Codable {
    let amount: Double  // 电费返回的是amount字段
    let displayRoomName: String
}


struct ContentView: View {
    @State private var balanceText: String = "未获取余额"
    @State private var waterText: String = "未获取水费"
    @State private var electricityText: String = "未获取电费"
    @State private var roomNameText: String = "未获取房间信息"  // 新增房间名称状态
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var isQuerying = false
    @StateObject private var historyManager = HistoryManager()
    
    // 使用@AppStorage来监听UserDefaults的变化
    @AppStorage("buildingCode") private var buildingCode: String?
    @AppStorage("floorCode") private var floorCode: String?
    @AppStorage("roomCode") private var roomCode: String?
    
    // 计算属性来判断房间是否配置完整
    private var isRoomConfigured: Bool {
        return buildingCode != nil && floorCode != nil && roomCode != nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 信息卡片区域
                    VStack(spacing: 16) {
                        // 房间名称显示
                        InfoCard(
                            icon: "house.fill",
                            iconColor: .green,
                            text: roomNameText
                        )
                        
                        // 卡余额显示
                        InfoCard(
                            icon: "creditcard.fill",
                            iconColor: .blue,
                            text: balanceText
                        )
                        
                        // 水费显示
                        InfoCard(
                            icon: "drop.fill",
                            iconColor: .cyan,
                            text: waterText
                        )
                        
                        // 电费显示
                        InfoCard(
                            icon: "bolt.circle.fill",
                            iconColor: .orange,
                            text: electricityText
                        )
                    }
                    .padding(.top, 8)
                    
                    // 房间配置检查和查询按钮
                    if !isRoomConfigured {
                        // 房间未配置时的提示
                        VStack(spacing: 12) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("请先配置房间信息")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            Text("需要在设置中选择您的楼栋、楼层和房间")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("前往设置") {
                                showingSettings = true
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        // 查询按钮
                        Button(action: {
                            if !isQuerying {
                                queryAllData()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isQuerying {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                Text(isQuerying ? "查询中..." : "查询")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        isQuerying ? Color.gray : Color.accentColor,
                                        isQuerying ? Color.gray.opacity(0.8) : Color.accentColor.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: (isQuerying ? Color.gray : Color.accentColor).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isQuerying)
                        .scaleEffect(isQuerying ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: isQuerying)
                    }
                    
                    // 应用说明区域
                    AppGuideView()
                        .padding(.top, 20)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("费用查询")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingHistory = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.accentColor)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView()
                    .environmentObject(historyManager)
            }
        }
    }
    
    private func queryAllData() {
        isQuerying = true
        var currentRoomName: String?
        var currentCardBalance: String?
        var currentWaterBalance: Double?
        var currentElectricityBalance: Double?
        var completedQueries = 0
        let totalQueries = 3
        
        // 查询卡余额
        if Config.cardUserId != nil {
            getCardMoney { balance in
                DispatchQueue.main.async {
                    if let balance = balance {
                        balanceText = "卡余额：\(balance) 元"
                        currentCardBalance = balance
                    } else {
                        balanceText = "获取失败"
                        currentCardBalance = nil
                    }
                    
                    completedQueries += 1
                    if completedQueries == totalQueries {
                        saveToHistory(roomName: currentRoomName, cardBalance: currentCardBalance, waterBalance: currentWaterBalance, electricityBalance: currentElectricityBalance)
                        isQuerying = false
                    }
                }
            }
        } else {
            // 卡用户ID未配置，跳过查询
            DispatchQueue.main.async {
                balanceText = "未配置卡用户ID"
                currentCardBalance = "未配置"
                
                completedQueries += 1
                if completedQueries == totalQueries {
                    saveToHistory(roomName: currentRoomName, cardBalance: currentCardBalance, waterBalance: currentWaterBalance, electricityBalance: currentElectricityBalance)
                    isQuerying = false
                }
            }
        }

        // 查询水费
        getWaterBalance { roomName, surplus in
            DispatchQueue.main.async {
                if let roomName = roomName, let surplus = surplus {
                    roomNameText = "\(roomName)"
                    waterText = "水费余额：\(surplus) 元"
                    currentRoomName = roomName
                    currentWaterBalance = surplus
                } else {
                    roomNameText = "获取房间信息失败"
                    waterText = "获取水费失败"
                }
                
                completedQueries += 1
                if completedQueries == totalQueries {
                    saveToHistory(roomName: currentRoomName, cardBalance: currentCardBalance, waterBalance: currentWaterBalance, electricityBalance: currentElectricityBalance)
                    isQuerying = false
                }
            }
        }
        
        // 查询电费
        getElectricityBalance { roomName, amount in
            DispatchQueue.main.async {
                if let amount = amount {
                    electricityText = "剩余电量：\(amount) 度"
                    currentElectricityBalance = amount
                    // 如果水费查询失败但电费成功，也更新房间名称
                    if currentRoomName == nil, let roomName = roomName {
                        roomNameText = "\(roomName)"
                        currentRoomName = roomName
                    }
                } else {
                    electricityText = "获取电量失败"
                }
                
                completedQueries += 1
                if completedQueries == totalQueries {
                    saveToHistory(roomName: currentRoomName, cardBalance: currentCardBalance, waterBalance: currentWaterBalance, electricityBalance: currentElectricityBalance)
                    isQuerying = false
                }
            }
        }
    }

    private func saveToHistory(roomName: String?, cardBalance: String?, waterBalance: Double?, electricityBalance: Double?) {
        historyManager.addHistory(
            roomName: roomName,
            cardBalance: cardBalance,
            waterBalance: waterBalance,
            electricityBalance: electricityBalance
        )
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
                    title: "配置房间信息",
                    description: "点击设置按钮，选择您的楼栋、楼层和房间号",
                    icon: "house.fill",
                    color: .orange
                )
                
                GuideStep(
                    number: "2",
                    title: "开发者模式（可选）",
                    description: "如需自定义API参数，进入设置中的开发者模式",
                    icon: "wrench.fill",
                    color: .purple
                )
                
                GuideStep(
                    number: "3",
                    title: "开始查询",
                    description: "配置完成后点击查询按钮获取实时数据",
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
                        description: "高级用户可自定义API接口参数",
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
                        Text("所有数据本地存储，不上传至第三方服务器")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("敏感配置信息仅在设备本地保存")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("网络请求仅访问官方查询接口")
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
        ContentView()
    }
}

