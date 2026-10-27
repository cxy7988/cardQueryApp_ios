import SwiftUI
import Foundation

// MARK: - 房间数据结构 (从SettingsView移动过来)
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
}

// MARK: - 登录界面
struct LoginView: View {
    @State private var isLoading = false
    @StateObject private var roomDataManager = RoomDataManager()
    @EnvironmentObject var loginManager: LoginManager
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var currentStep: LoginStep = .enterEmail
    @State private var countdown = 0
    @State private var timer: Timer?
    
    // 房间选择相关状态
    @State private var selectedBuilding: BuildingInfo?
    @State private var selectedFloor: FloorInfo?
    @State private var selectedRoom: RoomInfo?
    
    enum LoginStep {
        case enterEmail
        case enterCode
        case selectRoom
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // 头部图标和标题
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.accentColor)
                        
                        VStack(spacing: 8) {
                            Text("登录验证")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("请使用您的 @wku.edu.cn 邮箱登录")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 40)
                    
                    // 登录表单
                    VStack(spacing: 20) {
                        // 邮箱输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text("邮箱地址")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            TextField("请输入您的邮箱", text: $email)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .disabled(currentStep != .enterEmail || isLoading)
                                .opacity(currentStep != .enterEmail ? 0.6 : 1.0)
                        }
                        
                        // 验证码输入（仅在第二步显示）
                        if currentStep == .enterCode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("验证码")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                TextField("请输入6位验证码", text: $verificationCode)
                                    .textContentType(.oneTimeCode)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                    .autocorrectionDisabled()
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // 房间选择（仅在第三步显示）
                        if currentStep == .selectRoom {
                            VStack(spacing: 16) {
                                Text("绑定宿舍信息")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.accentColor)
                                
                                Text("请选择您的宿舍楼栋、楼层和房间号")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                VStack(spacing: 12) {
                                    // 楼栋选择
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("楼栋")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
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
                                    
                                    // 楼层选择
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("楼层")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
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
                                    
                                    // 房间选择
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("房间")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
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
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // 操作按钮
                        VStack(spacing: 12) {
                            if currentStep == .enterEmail {
                                // 发送验证码按钮
                                Button(action: sendVerificationCode) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(isLoading ? "发送中..." : (countdown > 0 ? "请在 \(countdown) 秒后重试" : "发送验证码"))
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.accentColor, .accentColor.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                .disabled(email.isEmpty || isLoading || countdown > 0 || !isValidEmail(email))
                            } else if currentStep == .enterCode {
                                // 验证码确认按钮
                                Button(action: verifyCodeAndProceed) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(isLoading ? "验证中..." : "验证并继续")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.green, .green.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                .disabled(verificationCode.count != 6 || isLoading)
                                
                                // 重新发送验证码按钮
                                Button(action: sendVerificationCode) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text(countdown > 0 ? "重新发送(\(countdown)s)" : "重新发送验证码")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                                }
                                .disabled(countdown > 0 || isLoading)
                                
                                // 返回修改邮箱按钮
                                Button(action: backToEmailStep) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("修改邮箱地址")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                .disabled(isLoading)
                            } else {
                                // 房间选择步骤的按钮
                                Button(action: completeLoginWithRoom) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("完成注册")
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                }
                                .disabled(selectedRoom == nil || isLoading)
                                
                                // 返回验证码步骤按钮
                                Button(action: restartLogin) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("重新验证邮箱")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                .disabled(isLoading)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 使用提示
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用说明")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.accentColor)
                                Text("只允许使用 @wku.edu.cn 结尾的邮箱地址")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.accentColor)
                                Text("验证码有效期为5分钟，请及时输入")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.accentColor)
                                Text("验证成功后将自动登录系统")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
        .onAppear {
            if let session = loginManager.session, session.room == nil {
                email = session.email
                currentStep = .selectRoom
            }
            if let message = loginManager.sessionMessage {
                showAlert(title: "登录提示", message: message)
                loginManager.sessionMessage = nil
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: loginManager.session) { _, session in
            if session == nil && currentStep == .selectRoom { backToEmailStep() }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.range(of: #"^[a-z0-9._%+-]+@wku\.edu\.cn$"#, options: .regularExpression) != nil
    }

    private func sendVerificationCode() {
        guard !isLoading, isValidEmail(email) else { return }
        email = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await loginManager.api.sendCode(email: email)
                currentStep = .enterCode
                startCountdown()
                showAlert(title: "发送成功", message: "验证码发送任务已提交，请检查您的邮箱")
            } catch {
                if case APIError.http(429, _, let seconds, _) = error, let seconds {
                    startCountdown(seconds: seconds)
                }
                showAlert(title: "发送失败", message: error.localizedDescription)
            }
        }
    }

    private func verifyCodeAndProceed() {
        guard !isLoading, verificationCode.range(of: #"^[0-9]{6}$"#, options: .regularExpression) != nil else {
            showAlert(title: "输入错误", message: "请输入六位数字验证码")
            return
        }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await loginManager.verify(email: email, code: verificationCode)
                verificationCode = ""
                if !loginManager.isLoggedIn { currentStep = .selectRoom }
            } catch {
                showAlert(title: "验证失败", message: error.localizedDescription)
            }
        }
    }

    private func completeLoginWithRoom() {
        guard !isLoading, let building = selectedBuilding,
              let floor = selectedFloor, let room = selectedRoom else { return }
        let boundRoom = BoundRoom(buildingCode: building.code, buildingName: building.name,
                                  floorCode: floor.code, floorName: floor.name,
                                  roomCode: room.code, roomName: room.name)
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                // 验证码已在第二步消费；绑定宿舍只使用服务器颁发的 Bearer 会话。
                try await loginManager.bindRoom(boundRoom)
            } catch {
                if loginManager.session == nil { backToEmailStep() }
                showAlert(title: "绑定失败", message: error.localizedDescription)
            }
        }
    }

    private func restartLogin() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await loginManager.logout()
                backToEmailStep()
            } catch {
                showAlert(title: "操作失败", message: error.localizedDescription)
            }
        }
    }

    private func backToEmailStep() {
        currentStep = .enterEmail
        verificationCode = ""
        timer?.invalidate()
        countdown = 0
    }

    private func startCountdown(seconds: Int = 60) {
        timer?.invalidate()
        countdown = seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

// 预览
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(LoginManager())
    }
}
