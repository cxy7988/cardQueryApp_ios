import Foundation

// 测试JSON解析
if let path = Bundle.main.path(forResource: "rooms_data", ofType: "json") {
    print("JSON文件路径找到: \(path)")
    
    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
        print("JSON数据加载成功，大小: \(data.count) bytes")
        
        // 尝试解析为基本的JSON对象
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            print("JSON解析成功，包含 \(jsonObject.keys.count) 个楼栋")
            
            // 打印前几个楼栋的信息
            let sortedKeys = jsonObject.keys.sorted()
            for (index, key) in sortedKeys.enumerated() {
                if index < 3, let building = jsonObject[key] as? [String: Any] {
                    print("楼栋 \(key): \(building["buildingName"] ?? "未知")")
                }
            }
        }
    }
} else {
    print("JSON文件路径未找到")
}
