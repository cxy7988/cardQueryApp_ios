import SwiftUI
import Foundation

// MARK: - 电费查询响应数据结构
struct ElectricityResponse: Codable {
    let data: ElectricityData?
}

struct ElectricityData: Codable {
    let amount: Double
    let displayRoomName: String
}

// MARK: - 水费查询响应数据结构
struct WaterResponse: Codable {
    let data: WaterData?
}

struct WaterData: Codable {
    let amount: Double
    let displayRoomName: String
}

struct ContentView: View {
    @State private var balanceText: String = "未获取余额"
    @State private var electricityText: String = "未获取电费"
    @State private var waterText: String = "未获取水费"
    @State private var roomNameText: String = "未获取房间信息"  // 新增房间名称状态
    
    var body: some View {
        VStack(spacing: 20) {
            // 房间名称显示
            Text(roomNameText)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            
            
            Text(balanceText)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            
            
            Text(electricityText)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            
            Text(waterText)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            
            Button(action: {
                // 查询卡余额
                getCardMoney { balance in
                    DispatchQueue.main.async {
                        if let balance = balance {
                            balanceText = "卡余额：\(balance) 元"
                        } else {
                            balanceText = "获取失败"
                        }
                    }
                }
                
                // 查询电费
                getElectricityBalance { roomName, amount in
                    DispatchQueue.main.async {
                        if let roomName = roomName, let amount = amount {
                            roomNameText = "\(roomName)"
                            electricityText = "电费余额：\(amount) 元"
                        } else {
                            roomNameText = "获取房间信息失败"
                            electricityText = "获取电费失败"
                        }
                    }
                }
                
                // 查询水费
                getWaterBalance { roomName, amount in
                    DispatchQueue.main.async {
                        if  let amount = amount {
                            waterText = "水费余额：\(amount) 元"
                        } else {
                            waterText = "获取水费失败"
                        }
                    }
                }
            }) {
                Text("查询")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}
    

// 预览
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

