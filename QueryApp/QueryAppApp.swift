import SwiftUI
import Foundation

// 假设你已经在项目中定义好了 Config 和 getCardMoney(completion:) 函数
// 下面示例中我们直接在同文件里给出一个简单实现

// MARK: - 配置结构体
struct Config {

    // MARK: - 固定变量
    static let platform = "WECHAT_H5"
    static let schoolCode = "16405"   // wku代码
    static let thirdAppid = "wx8fddf03d92fd6fa9"   // 微信小程序的appid

    // MARK: - 个性化变量,需要抓包获取
    static let cardUserId = "710d0450-2103-42ff-9445-8c2705e68923"   // shiroJID可以通过抓包获取，猜测和账号有关
    static let roomUserId = "fd755fb9-120c-4196-aa0f-1f5d022e9760"   // shiroJID可以通过抓包获取，猜测和账号有关
    static let deviceId = "2207539894378700812"   // deviceld暂且未知，猜测是和手机有关
    static let areaId = "1912101709517173"
    static let buildingCode = "237"  // Building 4
    static let floorCode = "254"    // Floor 6
    static let roomCode = "10254401"  // Room 601
}

@main
struct QueryAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView() // 👈 这里决定了启动时加载 ContentView
        }
    }
}

/// 异步请求卡余额，完成后通过 completion 返回 String?（balance）
func getCardMoney(completion: @escaping (String?) -> Void) {
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
        "Cookie": "shiroJID=\(Config.cardUserId)"
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

/// 异步请求电费余额，完成后通过 completion 返回 (roomName, amount)
func getElectricityBalance(completion: @escaping (String?, Double?) -> Void) {
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

    let bodyString = "areaId=\(Config.areaId)&buildingCode=\(Config.buildingCode)&floorCode=\(Config.floorCode)&roomCode=\(Config.roomCode)&ymId=\(Config.deviceId)&platform=\(Config.platform)"
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
                completion(electricityData.displayRoomName, electricityData.amount)
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

/// 异步请求水费余额，完成后通过 completion 返回 (roomName, amount)
func getWaterBalance(completion: @escaping (String?, Double?) -> Void) {
    guard let url = URL(string: "https://application.xiaofubao.com/app/water/queryRoomSurplus") else {
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

    let bodyString = "areaId=\(Config.areaId)&buildingCode=\(Config.buildingCode)&floorCode=\(Config.floorCode)&roomCode=\(Config.roomCode)&ymId=\(Config.deviceId)&platform=\(Config.platform)"
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



