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

// MARK: - 登录API服务
class LoginService: ObservableObject {
    let baseURL = "https://wkuquery.asia:5000"  // 使用域名
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func sendVerificationCode(email: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/send_code") else {
            completion(false, "无效的服务器地址")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "数据格式错误")
            return
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    completion(false, "网络错误：\(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "服务器响应错误")
                    return
                }
                
                if httpResponse.statusCode == 202 {
                    completion(true, "验证码已发送")
                } else {
                    // 解析错误信息
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMsg = json["error"] as? String {
                        completion(false, errorMsg)
                    } else {
                        completion(false, "发送失败，请稍后重试")
                    }
                }
            }
        }.resume()
    }
    
    func verifyCode(email: String, code: String, completion: @escaping (Bool, String?) -> Void) {
        guard let url = URL(string: "\(baseURL)/api/verify_code") else {
            completion(false, "无效的服务器地址")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "code": code]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(false, "数据格式错误")
            return
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    completion(false, "网络错误：\(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "服务器响应错误")
                    return
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if httpResponse.statusCode == 200,
                       let valid = json["valid"] as? Bool,
                       valid {
                        completion(true, "登录成功")
                    } else {
                        let errorMsg = json["error"] as? String ?? "验证失败"
                        completion(false, errorMsg)
                    }
                } else {
                    completion(false, "验证失败，请稍后重试")
                }
            }
        }.resume()
    }
}

// MARK: - 登录管理器
class LoginManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String = ""
    
    private let userDefaultsKey = "isLoggedIn"
    private let emailKey = "userEmail"
    
    init() {
        loadLoginState()
    }
    
    private func loadLoginState() {
        isLoggedIn = UserDefaults.standard.bool(forKey: userDefaultsKey)
        userEmail = UserDefaults.standard.string(forKey: emailKey) ?? ""
    }
    
    func login(email: String) {
        isLoggedIn = true
        userEmail = email
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
        UserDefaults.standard.set(email, forKey: emailKey)
    }
    
    func logout() {
        isLoggedIn = false
        userEmail = ""
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
    }
}

// MARK: - 登录界面
struct LoginView: View {
    @StateObject private var loginService = LoginService()
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
                                .disabled(currentStep == .enterCode)
                                .opacity(currentStep == .enterCode ? 0.6 : 1.0)
                        }
                        
                        // 验证码输入（仅在第二步显示）
                        if currentStep == .enterCode {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("验证码")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                TextField("请输入6位验证码", text: $verificationCode)
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
                                        if loginService.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(loginService.isLoading ? "发送中..." : "发送验证码")
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
                                .disabled(email.isEmpty || loginService.isLoading || !isValidEmail(email))
                            } else if currentStep == .enterCode {
                                // 验证码确认按钮
                                Button(action: verifyCodeAndProceed) {
                                    HStack {
                                        if loginService.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(loginService.isLoading ? "验证中..." : "验证并继续")
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
                                .disabled(verificationCode.isEmpty || loginService.isLoading)
                                
                                // 重新发送验证码按钮
                                Button(action: sendVerificationCode) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text(countdown > 0 ? "重新发送(\(countdown)s)" : "重新发送验证码")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.accentColor)
                                }
                                .disabled(countdown > 0 || loginService.isLoading)
                                
                                // 返回修改邮箱按钮
                                Button(action: backToEmailStep) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("修改邮箱地址")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
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
                                .disabled(selectedRoom == nil)
                                
                                // 返回验证码步骤按钮
                                Button(action: backToCodeStep) {
                                    HStack {
                                        Image(systemName: "chevron.left")
                                        Text("返回上一步")
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
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
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@wku\.edu\.cn$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private func sendVerificationCode() {
        guard !email.isEmpty && isValidEmail(email) else {
            showAlert(title: "输入错误", message: "请输入有效的 @wku.edu.cn 邮箱地址")
            return
        }
        
        loginService.sendVerificationCode(email: email.lowercased()) { success, message in
            if success {
                currentStep = .enterCode
                startCountdown()
                showAlert(title: "发送成功", message: message ?? "验证码已发送，请检查您的邮箱")
            } else {
                showAlert(title: "发送失败", message: message ?? "未知错误")
            }
        }
    }
    
    private func verifyCodeAndProceed() {
        guard !verificationCode.isEmpty else {
            showAlert(title: "输入错误", message: "请输入验证码")
            return
        }
        
        loginService.verifyCode(email: email.lowercased(), code: verificationCode) { success, message in
            if success {
                currentStep = .selectRoom
            } else {
                showAlert(title: "验证失败", message: message ?? "未知错误")
            }
        }
    }
    
    private func completeLoginWithRoom() {
        guard let building = selectedBuilding,
              let floor = selectedFloor,
              let room = selectedRoom else {
            showAlert(title: "选择错误", message: "请完整选择楼栋、楼层和房间")
            return
        }
        
        guard !verificationCode.isEmpty else {
            showAlert(title: "验证错误", message: "验证码丢失，请重新获取验证码")
            backToCodeStep()
            return
        }
        
        // 向服务器发送验证码和宿舍信息
        loginService.isLoading = true
        
        guard let url = URL(string: "\(loginService.baseURL)/api/verify_code_with_room") else {
            loginService.isLoading = false
            showAlert(title: "错误", message: "无效的服务器地址")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email.lowercased(),
            "code": verificationCode,
            "room_info": [
                "building_code": building.code,
                "building_name": building.name,
                "floor_code": floor.code,
                "floor_name": floor.name,
                "room_code": room.code,
                "room_name": room.name
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            loginService.isLoading = false
            showAlert(title: "错误", message: "数据格式错误")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.loginService.isLoading = false
                
                if let error = error {
                    self?.showAlert(title: "网络错误", message: "网络错误：\(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.showAlert(title: "服务器错误", message: "服务器响应错误")
                    return
                }
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if httpResponse.statusCode == 200,
                       let valid = json["valid"] as? Bool,
                       valid {
                        // 保存房间信息到本地
                        UserDefaults.standard.set(building.code, forKey: "buildingCode")
                        UserDefaults.standard.set(floor.code, forKey: "floorCode")
                        UserDefaults.standard.set(room.code, forKey: "roomCode")
                        
                        // 完成登录
                        self?.loginManager.login(email: self?.email.lowercased() ?? "")
                        self?.showAlert(title: "注册成功", message: "欢迎使用费用查询系统！您的宿舍信息已绑定：\(building.name) \(floor.name) \(room.name)")
                    } else {
                        let errorMsg = json["error"] as? String ?? "验证失败"
                        self?.showAlert(title: "验证失败", message: errorMsg)
                    }
                } else {
                    self?.showAlert(title: "验证失败", message: "验证失败，请稍后重试")
                }
            }
        }.resume()
    }
    
    private func backToCodeStep() {
        currentStep = .enterCode
    }
    
    private func backToEmailStep() {
        currentStep = .enterEmail
        verificationCode = ""
        timer?.invalidate()
        countdown = 0
    }
    
    private func startCountdown() {
        countdown = 60
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