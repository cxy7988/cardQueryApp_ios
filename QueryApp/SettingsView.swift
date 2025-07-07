import SwiftUI
import Foundation

// MARK: - 房间数据结构
struct RoomDataModel: Codable {
    let buildings: [String: BuildingData]
    
    private enum CodingKeys: String, CodingKey {
        case buildings = ""
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        var buildingsDict: [String: BuildingData] = [:]
        
        for key in container.allKeys {
            let buildingData = try container.decode(BuildingData.self, forKey: key)
            buildingsDict[key.stringValue] = buildingData
        }
        
        self.buildings = buildingsDict
    }
}

struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct BuildingData: Codable {
    let buildingName: String
    let floors: [String: FloorData]
    
    private enum CodingKeys: String, CodingKey {
        case buildingName, floors
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        buildingName = try container.decode(String.self, forKey: .buildingName)
        
        let floorsContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .floors)
        var floorsDict: [String: FloorData] = [:]
        
        for key in floorsContainer.allKeys {
            let floorData = try floorsContainer.decode(FloorData.self, forKey: key)
            floorsDict[key.stringValue] = floorData
        }
        
        self.floors = floorsDict
    }
}

struct FloorData: Codable {
    let floorName: String
    let rooms: [RoomData]
}

struct RoomData: Codable {
    let roomName: String
    let roomCode: String
}

// MARK: - UI 数据模型
struct BuildingInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: BuildingInfo, rhs: BuildingInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct FloorInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FloorInfo, rhs: FloorInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct RoomInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let code: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: RoomInfo, rhs: RoomInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 房间数据管理器
class RoomDataManager: ObservableObject {
    @Published var buildings: [BuildingInfo] = []
    @Published var floors: [FloorInfo] = []
    @Published var rooms: [RoomInfo] = []
    
    private var roomDataModel: RoomDataModel?
    
    init() {
        loadRoomData()
    }
    
    private func loadRoomData() {
        guard let url = Bundle.main.url(forResource: "rooms_data", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load rooms_data.json")
            // 提供一些默认数据以防JSON文件不存在
            buildings = [
                BuildingInfo(id: "237", name: "4号楼(菊苑)", code: "237")
            ]
            return
        }
        
        do {
            let roomData = try JSONDecoder().decode(RoomDataModel.self, from: data)
            self.roomDataModel = roomData
            
            // 构建楼栋列表
            buildings = roomData.buildings.map { (code, building) in
                BuildingInfo(id: code, name: building.buildingName, code: code)
            }.sorted { $0.name < $1.name }
        } catch {
            print("Failed to decode rooms_data.json: \(error)")
            // 提供默认数据
            buildings = [
                BuildingInfo(id: "237", name: "4号楼(菊苑)", code: "237")
            ]
        }
    }
    
    func loadFloorsForBuilding(_ buildingCode: String) {
        guard let roomData = roomDataModel,
              let building = roomData.buildings[buildingCode] else {
            floors = []
            return
        }
        
        floors = building.floors.map { (code, floor) in
            FloorInfo(id: code, name: floor.floorName, code: code)
        }.sorted { $0.name < $1.name }
    }
    
    func loadRoomsForFloor(_ buildingCode: String, _ floorCode: String) {
        guard let roomData = roomDataModel,
              let building = roomData.buildings[buildingCode],
              let floor = building.floors[floorCode] else {
            rooms = []
            return
        }
        
        rooms = floor.rooms.enumerated().map { (index, room) in
            RoomInfo(id: "\(floorCode)_\(index)", name: room.roomName, code: room.roomCode)
        }.sorted { $0.name < $1.name }
    }
    
    private func generateRoomCode(buildingCode: String, floorCode: String, roomName: String) -> String {
        // 这个方法现在不再需要，因为JSON中已经包含了roomCode
        return "10\(floorCode)\(String(roomName.dropFirst()))"
    }
    
    func findBuilding(byCode code: String) -> BuildingInfo? {
        return buildings.first { $0.code == code }
    }
    
    func findFloor(byCode code: String, inBuilding buildingCode: String) -> FloorInfo? {
        loadFloorsForBuilding(buildingCode)
        return floors.first { $0.code == code }
    }
    
    func findRoom(byCode code: String, inBuilding buildingCode: String, inFloor floorCode: String) -> RoomInfo? {
        loadRoomsForFloor(buildingCode, floorCode)
        return rooms.first { $0.code == code }
    }
}

struct SettingsView: View {
    @State private var cardUserId: String = Config.cardUserId ?? ""
    @State private var roomUserId: String = Config.roomUserId
    @State private var deviceId: String = Config.deviceId
    @State private var areaId_elec: String = Config.areaId_elec
    @State private var areaId_water: String = Config.areaId_water
    
    // 下拉选择相关状态
    @StateObject private var roomDataManager = RoomDataManager()
    @State private var selectedBuilding: BuildingInfo?
    @State private var selectedFloor: FloorInfo?
    @State private var selectedRoom: RoomInfo?
    
    @State private var showingSaveAlert = false
    @State private var showingResetAlert = false
    @State private var showingDeveloperMode = false
    @Environment(\.dismiss) private var dismiss
    
    // 初始化选择项
    init() {
        // 由于需要在 onAppear 中处理异步加载，这里不设置初始值
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("房间配置").font(.headline)) {
                    // 楼栋选择
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("楼栋")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("选择您的宿舍楼栋")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("楼栋", selection: $selectedBuilding) {
                            Text("请选择楼栋").tag(BuildingInfo?(nil))
                            ForEach(roomDataManager.buildings) { building in
                                Text(building.name).tag(BuildingInfo?(building))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: selectedBuilding) { _, newBuilding in
                            selectedFloor = nil
                            selectedRoom = nil
                            if let building = newBuilding {
                                roomDataManager.loadFloorsForBuilding(building.code)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 楼层选择
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("楼层")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("选择您的楼层")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("楼层", selection: $selectedFloor) {
                            Text("请选择楼层").tag(FloorInfo?(nil))
                            ForEach(roomDataManager.floors) { floor in
                                Text(floor.name).tag(FloorInfo?(floor))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(selectedBuilding == nil)
                        .onChange(of: selectedFloor) { _, newFloor in
                            selectedRoom = nil
                            if let building = selectedBuilding,
                               let floor = newFloor {
                                roomDataManager.loadRoomsForFloor(building.code, floor.code)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 房间选择
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("房间")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("选择您的房间号")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Picker("房间", selection: $selectedRoom) {
                            Text("请选择房间").tag(RoomInfo?(nil))
                            ForEach(roomDataManager.rooms) { room in
                                Text(room.name).tag(RoomInfo?(room))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .disabled(selectedFloor == nil)
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
                        Label("请先选择您的宿舍房间信息", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "1.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("**选择房间**")
                                    .font(.caption)
                            }
                            Text("依次选择您的楼栋、楼层和房间号")
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
                            Text("设置完成后请点击保存按钮")
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
            .onAppear {
                initializeRoomSelection()
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
        
        // 保存选择的楼栋、楼层、房间代码
        if let building = selectedBuilding {
            UserDefaults.standard.set(building.code, forKey: "buildingCode")
        }
        if let floor = selectedFloor {
            UserDefaults.standard.set(floor.code, forKey: "floorCode")
        }
        if let room = selectedRoom {
            UserDefaults.standard.set(room.code, forKey: "roomCode")
        }
        
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
        UserDefaults.standard.removeObject(forKey: "buildingCode")
        UserDefaults.standard.removeObject(forKey: "floorCode")
        UserDefaults.standard.removeObject(forKey: "roomCode")
        
        // 重新加载默认值到State变量
        cardUserId = Config.cardUserId ?? ""
        roomUserId = Config.roomUserId
        deviceId = Config.deviceId
        areaId_elec = Config.areaId_elec
        areaId_water = Config.areaId_water
        
        // 重新初始化房间选择
        initializeRoomSelection()
    }
    
    private func initializeRoomSelection() {
        // 根据当前配置找到对应的选择项
        guard let currentBuildingCode = Config.buildingCode,
              let currentFloorCode = Config.floorCode,
              let currentRoomCode = Config.roomCode else {
            // 如果房间配置不完整，清空选择
            selectedBuilding = nil
            selectedFloor = nil
            selectedRoom = nil
            return
        }
        
        // 找到对应的楼栋
        selectedBuilding = roomDataManager.findBuilding(byCode: currentBuildingCode)
        
        if let building = selectedBuilding {
            // 加载楼层并找到对应的楼层
            roomDataManager.loadFloorsForBuilding(building.code)
            selectedFloor = roomDataManager.findFloor(byCode: currentFloorCode, inBuilding: building.code)
            
            if let floor = selectedFloor {
                // 加载房间并找到对应的房间
                roomDataManager.loadRoomsForFloor(building.code, floor.code)
                selectedRoom = roomDataManager.findRoom(byCode: currentRoomCode, inBuilding: building.code, inFloor: floor.code)
            }
        }
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
                        placeholder: "请输入卡用户ID",
                        text: $cardUserId
                    )
                    
                    ConfigField(
                        title: "房间用户ID", 
                        description: "用于查询电费和水费的用户标识",
                        placeholder: "请输入房间用户ID",
                        text: $roomUserId
                    )
                    
                    ConfigField(
                        title: "设备ID",
                        description: "设备唯一标识符",
                        placeholder: "请输入设备ID", 
                        text: $deviceId
                    )
                }
                
                Section(header: Text("区域配置").font(.headline)) {
                    ConfigField(
                        title: "电费区域ID",
                        description: "用于查询电费的区域标识",
                        placeholder: "请输入电费区域ID",
                        text: $areaId_elec
                    )
                    
                    ConfigField(
                        title: "水费区域ID",
                        description: "用于查询水费的区域标识",
                        placeholder: "请输入水费区域ID",
                        text: $areaId_water
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
