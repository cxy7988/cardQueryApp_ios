// swift-tools-version: 6.0
import PackageDescription

// 同一份网络、登录和任务代码可在 macOS 测试，无需安装 iOS 模拟器。
let package = Package(
    name: "CardQueryClientTests",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "QueryApp",
            path: "QueryApp",
            exclude: ["ContentView.swift", "HistoryView.swift", "LoginView.swift", "QueryAppApp.swift",
                      "SettingsView.swift", "Info.plist", "Assets.xcassets", "rooms_data.json"],
            sources: ["AppConfiguration.swift", "ServerAPI.swift", "LoginManager.swift",
                      "QueryTaskModel.swift", "HistoryManager.swift"]
        ),
        .testTarget(name: "QueryAppTests", dependencies: ["QueryApp"], path: "QueryAppTests")
    ],
    swiftLanguageModes: [.v5]
)
