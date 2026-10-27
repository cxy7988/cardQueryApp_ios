import SwiftUI
import Foundation

struct SettingsView: View {
    @State private var cardUserId = ""
    @State private var deviceId = Config.deviceId
    @State private var showingSaveAlert = false
    @State private var showingLogoutAlert = false
    @State private var isLoggingOut = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var loginManager: LoginManager

    var body: some View {
        NavigationView {
            Form {
                Section("用户信息") {
                    LabeledContent("登录邮箱", value: loginManager.userEmail)
                    Button(isLoggingOut ? "正在退出…" : "退出登录", role: .destructive) {
                        showingLogoutAlert = true
                    }
                    .disabled(isLoggingOut)
                }

                Section("已绑定宿舍") {
                    if let room = loginManager.session?.room {
                        LabeledContent("楼栋", value: room.buildingName)
                        LabeledContent("楼层", value: room.floorName)
                        LabeledContent("房间", value: room.roomName)
                    }
                    Text("宿舍信息以服务器记录为准，重新登录不会覆盖已绑定的宿舍。如需变更，请联系管理员。")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section {
                    SecureField("饭卡用户ID（可选）", text: $cardUserId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("设备ID", text: $deviceId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("保存饭卡配置") {
                        let value = cardUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                        UserDefaults.standard.set(value, forKey: "cardUserId|\(loginManager.userEmail)")
                        UserDefaults.standard.set(deviceId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "deviceId")
                        showingSaveAlert = true
                    }
                } header: {
                    Text("本机饭卡查询")
                } footer: {
                    Text("饭卡用户ID取自校园官方页面请求 Cookie 的 shiroJID，仅保存在本机，按账号分别保存。未填写时跳过饭卡查询。水电参数由服务器管理。")
                }

                Section("查询服务") {
                    Text(loginManager.api.baseURL.absoluteString)
                        .font(.footnote).textSelection(.enabled)
                    Text("水电查询在服务器后台执行；进度连接中断后可继续原任务。服务器保留水电历史，登录凭据保存在设备钥匙串。")
                        .font(.caption).foregroundColor(.secondary)
                }

                if let errorMessage {
                    Section { Text(errorMessage).font(.footnote).foregroundColor(.red) }
                }
            }
            .navigationTitle("应用设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }.disabled(isLoggingOut)
                }
            }
        }
        .onAppear { cardUserId = Config.cardUserId(for: loginManager.userEmail) ?? "" }
        .alert("保存成功", isPresented: $showingSaveAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("新的饭卡配置将在下次查询时生效")
        }
        .alert("退出登录", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                isLoggingOut = true
                Task {
                    defer { isLoggingOut = false }
                    do {
                        try await loginManager.logout()
                        dismiss()
                    } catch {
                        errorMessage = "退出失败：\(error.localizedDescription)，请恢复连接后重试"
                    }
                }
            }
        } message: {
            Text("退出会撤销当前服务器会话，下次使用需重新验证邮箱。")
        }
    }
}

#Preview {
    SettingsView().environmentObject(LoginManager())
}
