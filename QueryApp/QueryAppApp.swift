import SwiftUI
import Foundation


@main
struct QueryAppApp: App {
    @StateObject private var loginManager = LoginManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            if let session = loginManager.session, session.room != nil {
                ContentView(session: session)
                    .id(loginManager.session?.accessToken)
                    .environmentObject(loginManager)
            } else {
                LoginView()
                    .environmentObject(loginManager)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loginManager.expireIfNeeded() }
        }
    }
}

/// 异步请求卡余额，完成后通过 completion 返回 String?（balance）
func getCardMoney(email: String, completion: @escaping (String?) -> Void) {
    // 检查卡用户ID是否已设置
    guard let cardUserId = Config.cardUserId(for: email) else {
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
