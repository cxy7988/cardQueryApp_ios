import SwiftUI
import Foundation


// MARK: - 配置结构体
struct Config {

    // MARK: - 固定变量
    static let platform = "WECHAT_H5"
    static let schoolCode = "16405"   // wku代码
    static let thirdAppid = "wx8fddf03d92fd6fa9"   // 微信小程序的appid

    // MARK: - 个性化变量,需要抓包获取
    // 默认值，如果UserDefaults中没有保存的值则使用这些默认值
    // 卡用户ID不设默认值，未设置时不查询卡余额
    private static let defaultRoomUserId = "fd755fb9-120c-4196-aa0f-1f5d022e9760"
    private static let defaultDeviceId = "2207539894378700812"
    private static let defaultAreaId_elec = "1912101703037172"
    private static let defaultAreaId_water = "1912101709517173"
    // 房间相关配置不设默认值，强制用户在设置中选择
    
    // 从UserDefaults读取或使用默认值
    static var cardUserId: String? {
        return UserDefaults.standard.string(forKey: "cardUserId")
    }
    
    static var roomUserId: String {
        return UserDefaults.standard.string(forKey: "roomUserId") ?? defaultRoomUserId
    }
    
    static var deviceId: String {
        return UserDefaults.standard.string(forKey: "deviceId") ?? defaultDeviceId
    }
    
    static var areaId_elec: String {
        return UserDefaults.standard.string(forKey: "areaId_elec") ?? defaultAreaId_elec
    }
    
    static var areaId_water: String {
        return UserDefaults.standard.string(forKey: "areaId_water") ?? defaultAreaId_water
    }
    
    static var buildingCode: String? {
        return UserDefaults.standard.string(forKey: "buildingCode")
    }
    
    static var floorCode: String? {
        return UserDefaults.standard.string(forKey: "floorCode")
    }
    
    static var roomCode: String? {
        return UserDefaults.standard.string(forKey: "roomCode")
    }
    
    // 检查房间配置是否完整
    static var isRoomConfigured: Bool {
        return buildingCode != nil && floorCode != nil && roomCode != nil
    }
}

@main
struct QueryAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// 异步请求卡余额，完成后通过 completion 返回 String?（balance）
func getCardMoney(completion: @escaping (String?) -> Void) {
    // 检查卡用户ID是否已设置
    guard let cardUserId = Config.cardUserId else {
        completion(nil)
        return
    }
    
    // 构造 URLRequest（示例复用之前的逻辑）
    guard let url = URL(string: "https://webapp.xiaofubao.com/card/getCardMoney") else {
        completion(nil)
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    let headers = [
        "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
        "Accept": "application/json, text/plain, */*",
        "X-Requested-With": "XMLHttpRequest",
        "Sec-Fetch-Site": "same-origin",
        "Accept-Language": "zh-CN,zh-Hans;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Sec-Fetch-Mode": "cors",
        "Origin": "https://webapp.xiaofubao.com",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X)…",
        "Sec-Fetch-Dest": "empty",
        "Referer": "https://webapp.xiaofubao.com/webapp/card/card_remain.shtml?platform=\(Config.platform)&schoolCode=\(Config.schoolCode)&thirdAppid=\(Config.thirdAppid)",
        "Cookie": "shiroJID=\(cardUserId)"
    ]
    headers.forEach { key, value in
        request.setValue(value, forHTTPHeaderField: key)
    }
    let bodyString = "platform=\(Config.platform)&deviceld=\(Config.deviceId)"
    request.httpBody = bodyString.data(using: .utf8)

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard
            error == nil,
            let data = data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let balance = json["data"] as? String
        else {
            completion(nil)
            return
        }
        completion(balance)
    }
    .resume()
}

/// 异步请求水费余额，完成后通过 completion 返回 (roomName, amount)
func getWaterBalance(completion: @escaping (String?, Double?) -> Void) {
    // 检查房间配置是否完整
    guard Config.isRoomConfigured,
          let buildingCode = Config.buildingCode,
          let floorCode = Config.floorCode,
          let roomCode = Config.roomCode else {
        completion(nil, nil)
        return
    }
    
    guard let url = URL(string: "https://application.xiaofubao.com/app/electric/queryRoomSurplus") else {
        completion(nil, nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let headers = [
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
        "Accept": "*/*",
        "X-Requested-With": "XMLHttpRequest",
        "Sec-Fetch-Site": "same-origin",
        "Priority": "u=3, i",
        "Accept-Language": "zh-CN,zh-Hans;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Sec-Fetch-Mode": "cors",
        "Origin": "https://application.xiaofubao.com",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.60(0x18003c32) NetType/WIFI Language/zh_CN",
        "Referer": "https://application.xiaofubao.com/",
        "Sec-Fetch-Dest": "empty",
        "Cookie": "shiroJID=\(Config.roomUserId)"
    ]

    headers.forEach { key, value in
        request.setValue(value, forHTTPHeaderField: key)
    }

    let bodyString = "areaId=\(Config.areaId_water)&buildingCode=\(buildingCode)&floorCode=\(floorCode)&roomCode=\(roomCode)&ymId=\(Config.deviceId)&platform=\(Config.platform)"
    request.httpBody = bodyString.data(using: .utf8)

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard
            error == nil,
            let data = data
        else {
            completion(nil, nil)
            return
        }

        do {
            let waterResponse = try JSONDecoder().decode(WaterResponse.self, from: data)
            if let waterData = waterResponse.data {
                completion(waterData.displayRoomName, waterData.amount)
            } else {
                completion(nil, nil)
            }
        } catch {
            // 如果解码失败，尝试使用原始JSON解析方式
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let amount = dataDict["amount"] as? Double,
               let roomName = dataDict["displayRoomName"] as? String {
                completion(roomName, amount)
            } else {
                completion(nil, nil)
            }
        }
    }
    .resume()
}

/// 异步请求电费余额，完成后通过 completion 返回 (roomName, surplus)
func getElectricityBalance(completion: @escaping (String?, Double?) -> Void) {
    // 检查房间配置是否完整
    guard Config.isRoomConfigured,
          let buildingCode = Config.buildingCode,
          let floorCode = Config.floorCode,
          let roomCode = Config.roomCode else {
        completion(nil, nil)
        return
    }
    
    guard let url = URL(string: "https://application.xiaofubao.com/app/electric/queryRoomSurplus") else {
        completion(nil, nil)
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let headers = [
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
        "Accept": "*/*",
        "X-Requested-With": "XMLHttpRequest",
        "Sec-Fetch-Site": "same-origin",
        "Priority": "u=3, i",
        "Accept-Language": "zh-CN,zh-Hans;q=0.9",
        "Accept-Encoding": "gzip, deflate, br",
        "Sec-Fetch-Mode": "cors",
        "Origin": "https://application.xiaofubao.com",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.60(0x18003c32) NetType/WIFI Language/zh_CN",
        "Referer": "https://application.xiaofubao.com/",
        "Sec-Fetch-Dest": "empty",
        "Cookie": "shiroJID=\(Config.roomUserId)"
    ]

    headers.forEach { key, value in
        request.setValue(value, forHTTPHeaderField: key)
    }

    let bodyString = "areaId=\(Config.areaId_elec)&buildingCode=\(buildingCode)&floorCode=\(floorCode)&roomCode=\(roomCode)&ymId=\(Config.deviceId)&platform=\(Config.platform)"
    request.httpBody = bodyString.data(using: .utf8)

    URLSession.shared.dataTask(with: request) { data, response, error in
        guard
            error == nil,
            let data = data
        else {
            completion(nil, nil)
            return
        }

        do {
            let electricityResponse = try JSONDecoder().decode(ElectricityResponse.self, from: data)
            if let electricityData = electricityResponse.data {
                completion(electricityData.displayRoomName, electricityData.surplus)
            } else {
                completion(nil, nil)
            }
        } catch {
            // 如果解码失败，尝试使用原始JSON解析方式
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let surplus = dataDict["surplus"] as? Double,
               let roomName = dataDict["displayRoomName"] as? String {
                completion(roomName, surplus)
            } else {
                completion(nil, nil)
            }
        }
    }
    .resume()
}




