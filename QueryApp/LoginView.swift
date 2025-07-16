import SwiftUI
import Foundation

// MARK: - 登录API服务
class LoginService: ObservableObject {
    private let baseURL = "https://wkuquery.asia:5000"  // 使用域名
    
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
    @EnvironmentObject var loginManager: LoginManager
    
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var currentStep: LoginStep = .enterEmail
    @State private var countdown = 0
    @State private var timer: Timer?
    
    enum LoginStep {
        case enterEmail
        case enterCode
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
                            } else {
                                // 验证和登录按钮
                                Button(action: verifyCodeAndLogin) {
                                    HStack {
                                        if loginService.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(loginService.isLoading ? "验证中..." : "验证并登录")
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
    
    private func verifyCodeAndLogin() {
        guard !verificationCode.isEmpty else {
            showAlert(title: "输入错误", message: "请输入验证码")
            return
        }
        
        loginService.verifyCode(email: email.lowercased(), code: verificationCode) { success, message in
            if success {
                loginManager.login(email: email.lowercased())
                showAlert(title: "登录成功", message: "欢迎使用费用查询系统")
            } else {
                showAlert(title: "验证失败", message: message ?? "未知错误")
            }
        }
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