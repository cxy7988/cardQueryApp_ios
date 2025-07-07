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
    
    var body: some View {
        NavigationView {
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
                
                Spacer()
                
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
                
                Spacer()
                    .frame(height: 20)
            }
            .padding(.horizontal, 20)
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
        getCardMoney { balance in
            DispatchQueue.main.async {
                if let balance = balance {
                    balanceText = "卡余额：\(balance) 元"
                    currentCardBalance = balance
                } else {
                    balanceText = "获取失败"
                }
                
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

// 预览
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

