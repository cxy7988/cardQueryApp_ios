import Foundation

// MARK: - 饭卡本机配置（水电参数由服务器管理）
struct Config {
    static let platform = "WECHAT_H5"
    static let schoolCode = "16405"
    static let thirdAppid = "wx8fddf03d92fd6fa9"
    private static let defaultDeviceId = "2207539894378700812"

    static func cardUserId(for email: String, defaults: UserDefaults = .standard) -> String? {
        let key = "cardUserId|\(email)"
        // 只有旧版记录明确属于当前邮箱时才迁移，避免换号后串用饭卡凭据。
        if defaults.string(forKey: key) == nil,
           defaults.string(forKey: "userEmail")?.lowercased() == email {
            defaults.set(defaults.string(forKey: "cardUserId"), forKey: key)
        }
        let value = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    static var deviceId: String {
        UserDefaults.standard.string(forKey: "deviceId") ?? defaultDeviceId
    }
}
