import SwiftUI
import Foundation

struct SettingsView: View {
    @State private var cardUserId: String = Config.cardUserId ?? ""
    @State private var roomUserId: String = Config.roomUserId
    @State private var deviceId: String = Config.deviceId
    @State private var areaId_elec: String = Config.areaId_elec
    @State private var areaId_water: String = Config.areaId_water
    
    @State private var showingSaveAlert = false
    @State private var showingResetAlert = false
    @State private var showingDeveloperMode = false
    @State private var showingLogoutAlert = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var loginManager: LoginManager
    
    var body: some View {
        NavigationView {
            Form {
                // 用户信息Section
                Section(header: Text("用户信息").font(.headline)) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已登录用户")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(loginManager.userEmail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("退出登录") {
                            showingLogoutAlert = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("宿舍信息").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "building.2.fill")
                                .foregroundColor(.accentColor)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("已绑定宿舍")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let buildingCode = Config.buildingCode,
                                   let floorCode = Config.floorCode,
                                   let roomCode = Config.roomCode {
                                    Text("楼栋: \(buildingCode) | 楼层: \(floorCode) | 房间: \(roomCode)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("未绑定宿舍信息")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("宿舍信息绑定说明")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text("宿舍信息在首次登录时绑定，一旦绑定后无法在此修改。如需更改宿舍信息，请退出登录后重新注册。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("高级设置").font(.headline)) {
                    // 开发者模式入口
                    Button(action: {
                        showingDeveloperMode = true
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("开发者模式")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("配置API参数和用户标识")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section {
                    HStack {
                        Button("重置为默认值") {
                            showingResetAlert = true
                        }
                        .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button("保存设置") {
                            saveSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Section(header: Text("使用说明").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("配置说明", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "1.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("**宿舍信息**")
                                    .font(.caption)
                            }
                            Text("宿舍信息在首次登录时已绑定，无法修改")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("**开发者模式**")
                                    .font(.caption)
                            }
                            Text("如需配置API参数，请进入开发者模式")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("**保存设置**")
                                    .font(.caption)
                            }
                            Text("修改开发者配置后请点击保存按钮")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .navigationTitle("应用设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }

        }
        .alert("保存成功", isPresented: $showingSaveAlert) {
            Button("确定") { }
        } message: {
            Text("设置已保存，新的配置将立即生效")
        }
        .alert("重置设置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("确定要将所有设置重置为默认值吗？")
        }
        .alert("退出登录", isPresented: $showingLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("退出", role: .destructive) {
                loginManager.logout()
                dismiss()
            }
        } message: {
            Text("确定要退出登录吗？退出后需要重新验证邮箱才能使用应用。")
        }
        .sheet(isPresented: $showingDeveloperMode) {
            DeveloperModeView(
                cardUserId: $cardUserId,
                roomUserId: $roomUserId,
                deviceId: $deviceId,
                areaId_elec: $areaId_elec,
                areaId_water: $areaId_water
            )
        }
    }
    
    private func saveSettings() {
        // 将设置保存到 UserDefaults
        UserDefaults.standard.set(cardUserId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "cardUserId")
        UserDefaults.standard.set(roomUserId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "roomUserId")
        UserDefaults.standard.set(deviceId.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "deviceId")
        UserDefaults.standard.set(areaId_elec.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "areaId_elec")
        UserDefaults.standard.set(areaId_water.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "areaId_water")
        
        // 显示保存成功提示
        showingSaveAlert = true
    }
    
    private func resetToDefaults() {
        // 清除UserDefaults中的值，这样Config就会使用默认值
        UserDefaults.standard.removeObject(forKey: "cardUserId")
        UserDefaults.standard.removeObject(forKey: "roomUserId")
        UserDefaults.standard.removeObject(forKey: "deviceId")
        UserDefaults.standard.removeObject(forKey: "areaId_elec")
        UserDefaults.standard.removeObject(forKey: "areaId_water")
        
        // 重新加载默认值到State变量
        cardUserId = Config.cardUserId ?? ""
        roomUserId = Config.roomUserId
        deviceId = Config.deviceId
        areaId_elec = Config.areaId_elec
        areaId_water = Config.areaId_water
    }

}

// MARK: - ConfigField 组件
struct ConfigField: View {
    let title: String
    let description: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 开发者模式视图
struct DeveloperModeView: View {
    @Binding var cardUserId: String
    @Binding var roomUserId: String
    @Binding var deviceId: String
    @Binding var areaId_elec: String
    @Binding var areaId_water: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveAlert = false
    
    // 获取默认值用于比较
    private var defaultCardUserId: String { Config.cardUserId ?? "" }
    private var defaultRoomUserId: String { Config.roomUserId }
    private var defaultDeviceId: String { Config.deviceId }
    private var defaultAreaId_elec: String { Config.areaId_elec }
    private var defaultAreaId_water: String { Config.areaId_water }
    
    // 判断是否为默认值的函数
    private func isDefaultValue(_ value: String, defaultValue: String) -> Bool {
        return value == defaultValue && !value.isEmpty
    }
    
    // 获取显示值的函数
    private func getDisplayValue(_ value: String, defaultValue: String) -> String {
        if isDefaultValue(value, defaultValue: defaultValue) {
            return ""
        }
        return value
    }
    
    // 获取占位符的函数
    private func getPlaceholder(_ defaultValue: String, fieldName: String) -> String {
        if !defaultValue.isEmpty {
            return "当前使用默认值，请输入自定义\(fieldName)"
        }
        return "请输入\(fieldName)"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("⚠️ 开发者配置").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("请谨慎修改以下参数")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text("这些参数需要通过抓包获取，错误的配置可能导致查询失败")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("用户标识").font(.headline)) {
                    ConfigField(
                        title: "卡用户ID",
                        description: "用于查询饭卡余额的用户标识",
                        placeholder: getPlaceholder(defaultCardUserId, fieldName: "卡用户ID"),
                        text: Binding(
                            get: { getDisplayValue(cardUserId, defaultValue: defaultCardUserId) },
                            set: { newValue in
                                if newValue.isEmpty {
                                    cardUserId = defaultCardUserId
                                } else {
                                    cardUserId = newValue
                                }
                            }
                        )
                    )
                    
                    ConfigField(
                        title: "房间用户ID", 
                        description: "用于查询电费和水费的用户标识",
                        placeholder: getPlaceholder(defaultRoomUserId, fieldName: "房间用户ID"),
                        text: Binding(
                            get: { getDisplayValue(roomUserId, defaultValue: defaultRoomUserId) },
                            set: { newValue in
                                if newValue.isEmpty {
                                    roomUserId = defaultRoomUserId
                                } else {
                                    roomUserId = newValue
                                }
                            }
                        )
                    )
                    
                    ConfigField(
                        title: "设备ID",
                        description: "设备唯一标识符",
                        placeholder: getPlaceholder(defaultDeviceId, fieldName: "设备ID"), 
                        text: Binding(
                            get: { getDisplayValue(deviceId, defaultValue: defaultDeviceId) },
                            set: { newValue in
                                if newValue.isEmpty {
                                    deviceId = defaultDeviceId
                                } else {
                                    deviceId = newValue
                                }
                            }
                        )
                    )
                }
                
                Section(header: Text("区域配置").font(.headline)) {
                    ConfigField(
                        title: "电费区域ID",
                        description: "用于查询电费的区域标识",
                        placeholder: getPlaceholder(defaultAreaId_elec, fieldName: "电费区域ID"),
                        text: Binding(
                            get: { getDisplayValue(areaId_elec, defaultValue: defaultAreaId_elec) },
                            set: { newValue in
                                if newValue.isEmpty {
                                    areaId_elec = defaultAreaId_elec
                                } else {
                                    areaId_elec = newValue
                                }
                            }
                        )
                    )
                    
                    ConfigField(
                        title: "水费区域ID",
                        description: "用于查询水费的区域标识",
                        placeholder: getPlaceholder(defaultAreaId_water, fieldName: "水费区域ID"),
                        text: Binding(
                            get: { getDisplayValue(areaId_water, defaultValue: defaultAreaId_water) },
                            set: { newValue in
                                if newValue.isEmpty {
                                    areaId_water = defaultAreaId_water
                                } else {
                                    areaId_water = newValue
                                }
                            }
                        )
                    )
                }
                
                Section(header: Text("获取方法").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "1.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("**用户ID**")
                                    .font(.caption)
                            }
                            Text("来自请求头的 Cookie 中的 shiroJID 值")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "2.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("**设备ID**")
                                    .font(.caption)
                            }
                            Text("来自请求参数的 deviceId 或 ymId")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "3.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("**区域ID**")
                                    .font(.caption)
                            }
                            Text("电费和水费可能使用不同的区域ID，来自请求参数的 areaId")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .navigationTitle("开发者模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        showingSaveAlert = true
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("配置已保存", isPresented: $showingSaveAlert) {
            Button("确定") {
                dismiss()
            }
        } message: {
            Text("开发者配置已更新，返回主设置页面保存完整配置")
        }
    }
}

#Preview {
    SettingsView()
}
