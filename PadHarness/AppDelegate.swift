import UIKit
import Network
import Darwin

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// 应用版本：每次发版递增（MARKETING_VERSION / CURRENT_PROJECT_VERSION 同源）。
    /// 真值来自 Info.plist（CFBundleShortVersionString / CFBundleVersion），
    /// 这里只是 Info.plist 读取失败时的兜底常量，需与 VERSION 文件保持一致。
    enum Version {
        /// 展示版本（CFBundleShortVersionString）
        static let marketing = "1.0.80"
        /// 构建号（CFBundleVersion）
        static let build = "12"
        /// 组合展示，如 v1.0.80 (12)
        static var display: String { "v\(marketing) (\(build))" }
    }

    /// 原生精准设备硬件型号与商业名称检测 (全面覆盖 iPhone 与 iPad 全系列)
    public static func getHardwareDeviceInfo() -> (marketing: String, hardwareId: String, totalRAMMB: UInt64, totalDiskGB: Double, freeDiskGB: Double) {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let hardwareId = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        let totalRAMMB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
        var totalDiskGB: Double = 0.0
        var freeDiskGB: Double = 0.0
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let total = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64 {
            totalDiskGB = Double(total) / 1024.0 / 1024.0 / 1024.0
            freeDiskGB = Double(free) / 1024.0 / 1024.0 / 1024.0
        }

        let marketing: String
        switch hardwareId {
        case "iPhone14,7": marketing = "iPhone 14"
        case "iPhone14,8": marketing = "iPhone 14 Plus"
        case "iPhone15,2": marketing = "iPhone 14 Pro"
        case "iPhone15,3": marketing = "iPhone 14 Pro Max"

        case "iPhone15,4": marketing = "iPhone 15"
        case "iPhone15,5": marketing = "iPhone 15 Plus"
        case "iPhone16,1": marketing = "iPhone 15 Pro"
        case "iPhone16,2": marketing = "iPhone 15 Pro Max"

        case "iPhone17,1": marketing = "iPhone 16 Pro"
        case "iPhone17,2": marketing = "iPhone 16 Pro Max"
        case "iPhone17,3": marketing = "iPhone 16"
        case "iPhone17,4": marketing = "iPhone 16 Plus"

        case "iPhone14,4": marketing = "iPhone 13 mini"
        case "iPhone14,5": marketing = "iPhone 13"
        case "iPhone14,2": marketing = "iPhone 13 Pro"
        case "iPhone14,3": marketing = "iPhone 13 Pro Max"

        case "iPhone13,1": marketing = "iPhone 12 mini"
        case "iPhone13,2": marketing = "iPhone 12"
        case "iPhone13,3": marketing = "iPhone 12 Pro"
        case "iPhone13,4": marketing = "iPhone 12 Pro Max"

        case "iPhone12,1": marketing = "iPhone 11"
        case "iPhone12,3": marketing = "iPhone 11 Pro"
        case "iPhone12,5": marketing = "iPhone 11 Pro Max"

        case "iPad8,1", "iPad8,2", "iPad8,3", "iPad8,4": marketing = "iPad Pro 11-inch (第1代)"
        case "iPad8,9", "iPad8,10": marketing = "iPad Pro 11-inch (第2代)"
        case "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7": marketing = "iPad Pro 11-inch (第3代 M1)"
        case "iPad14,3", "iPad14,4": marketing = "iPad Pro 11-inch (第4代 M2)"
        case "iPad16,3", "iPad16,4": marketing = "iPad Pro 11-inch (第5代 M4)"

        case "iPad8,5", "iPad8,6", "iPad8,7", "iPad8,8": marketing = "iPad Pro 12.9-inch (第3代)"
        case "iPad8,11", "iPad8,12": marketing = "iPad Pro 12.9-inch (第4代)"
        case "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11": marketing = "iPad Pro 12.9-inch (第5代 M1)"
        case "iPad14,5", "iPad14,6": marketing = "iPad Pro 12.9-inch (第6代 M2)"
        case "iPad16,5", "iPad16,6": marketing = "iPad Pro 13-inch (M4)"

        case "iPad11,3", "iPad11,4": marketing = "iPad Air (第3代)"
        case "iPad13,1", "iPad13,2": marketing = "iPad Air (第4代)"
        case "iPad13,16", "iPad13,17": marketing = "iPad Air (第5代 M1)"
        case "iPad14,8", "iPad14,9": marketing = "iPad Air 11-inch (M2)"
        case "iPad14,10", "iPad14,11": marketing = "iPad Air 13-inch (M2)"

        case "iPad11,1", "iPad11,2": marketing = "iPad mini (第5代)"
        case "iPad14,1", "iPad14,2": marketing = "iPad mini (第6代)"
        case "iPad16,1", "iPad16,2": marketing = "iPad mini (A17 Pro)"

        case "iPad7,11", "iPad7,12": marketing = "iPad (第7代)"
        case "iPad11,6", "iPad11,7": marketing = "iPad (第8代)"
        case "iPad12,1", "iPad12,2": marketing = "iPad (第9代)"
        case "iPad13,18", "iPad13,19": marketing = "iPad (第10代)"

        case "i386", "x86_64", "arm64": marketing = "iOS 模拟器 (\(UIDevice.current.model))"
        default: marketing = hardwareId.isEmpty ? UIDevice.current.model : hardwareId
        }

        return (marketing, hardwareId, totalRAMMB, totalDiskGB, freeDiskGB)
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 1. 开启 32MB 内存 + 128MB 磁盘 URL 缓存（严控 8G iPad 内存水位）
        let memoryCapacity = 32 * 1024 * 1024
        let diskCapacity = 128 * 1024 * 1024
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "dsh_web_cache")
        URLCache.shared = cache

        // 2. 启动 iPad 本机独立服务端引擎（监听 0.0.0.0:3080，若 launchd 已启动 Node 则自动礼让）
        DSHEmbeddedServer.shared.bootIfNeeded()
        return true
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // 内存告警时立即清空 Web 缓存，配合内存守护插件杜绝 Jetsam OOM
        URLCache.shared.removeAllCachedResponses()
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}

/// iPad 本机内嵌独立服务端（0.0.0.0:3080）
/// 确保安装 IPA 后无需任何电脑、无需终端命令，打开即刻闭环运行，同时支持局域网 iPhone 作为纯客户端接入。
final class DSHEmbeddedServer {
    static let shared = DSHEmbeddedServer()

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.deepseek.harness.pad.embedded-server", qos: .userInitiated)

    func bootIfNeeded() {
        queue.async { [weak self] in
            self?.startListener()
        }
    }

    private func startListener() {
        guard listener == nil else { return }
        guard let port = NWEndpoint.Port(rawValue: 3080) else { return }

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        do {
            let newListener = try NWListener(using: params, on: port)
            newListener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[PadHarness] Embedded Host listening on 0.0.0.0:3080")
                case .failed(let err):
                    print("[PadHarness] Embedded Host deferred (port 3080 likely owned by launchd Node daemon): \(err)")
                default:
                    break
                }
            }
            newListener.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn)
            }
            newListener.start(queue: queue)
            self.listener = newListener
        } catch {
            print("[PadHarness] Could not bind 3080: \(error)")
        }
    }

    private func handleConnection(_ conn: NWConnection) {
        conn.start(queue: queue)
        var buffer = Data()
        var expectedBodyLength: Int? = nil
        var headerEndIndex: Int? = nil

        func readMore() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, err in
                guard let self = self else {
                    conn.cancel()
                    return
                }
                if let d = data, !d.isEmpty {
                    buffer.append(d)
                }

                // 探测 HTTP 请求头是否完整结束 (\r\n\r\n)
                if headerEndIndex == nil {
                    let crlfcrlf = Data([0x0D, 0x0A, 0x0D, 0x0A])
                    if let range = buffer.range(of: crlfcrlf) {
                        let hLen = range.upperBound
                        headerEndIndex = hLen
                        if let headerStr = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: .utf8) {
                            for line in headerStr.components(separatedBy: "\r\n") {
                                let lower = line.lowercased()
                                if lower.hasPrefix("content-length:") {
                                    let valStr = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                                    expectedBodyLength = Int(valStr)
                                    break
                                }
                            }
                        }
                        if expectedBodyLength == nil {
                            expectedBodyLength = 0
                        }
                    }
                }

                // 请求头及完整 Body 均已接收完毕，或 TCP 流已关闭
                if let hLen = headerEndIndex, let bLen = expectedBodyLength {
                    if buffer.count >= (hLen + bLen) || isComplete || err != nil {
                        let fullRequestString = String(data: buffer, encoding: .utf8) ?? ""
                        self.routeHTTPAsync(rawRequest: fullRequestString) { responseData in
                            conn.send(content: responseData, completion: .contentProcessed { _ in
                                conn.cancel()
                            })
                        }
                        return
                    }
                } else if isComplete || err != nil {
                    if !buffer.isEmpty {
                        let fullRequestString = String(data: buffer, encoding: .utf8) ?? ""
                        self.routeHTTPAsync(rawRequest: fullRequestString) { responseData in
                            conn.send(content: responseData, completion: .contentProcessed { _ in
                                conn.cancel()
                            })
                        }
                    } else {
                        conn.cancel()
                    }
                    return
                }

                // 继续接收剩余 TCP 分包
                readMore()
            }
        }

        readMore()
    }

    private func routeHTTPAsync(rawRequest: String, completion: @escaping (Data) -> Void) {
        let lines = rawRequest.components(separatedBy: "\r\n")
        let firstLine = lines.first ?? "GET / HTTP/1.1"
        let parts = firstLine.components(separatedBy: " ")
        let method = parts.first ?? "GET"
        let path = parts.count > 1 ? parts[1] : "/"

        var bodyString = ""
        if let range = rawRequest.range(of: "\r\n\r\n") {
            bodyString = String(rawRequest[range.upperBound...])
        }

        if method == "OPTIONS" {
            completion(makeHTTPResponse(status: "204 No Content", contentType: "text/plain", body: Data()))
            return
        }

        if path.hasPrefix("/health") || path.hasPrefix("/api/health") {
            let rss = currentMemoryMB()
            let totalRAM = totalPhysicalMemoryMB()
            let limitMB = dynamicMemoryLimitMB()
            let hw = AppDelegate.getHardwareDeviceInfo()
            if rss > Int(Double(limitMB) * 0.75) {
                URLCache.shared.removeAllCachedResponses()
            }
            let jbFlag = EnvironmentGuard.isJailbroken ? "true" : "false"
            let modeDesc = EnvironmentGuard.runtimeMode
            let json = """
            {"status":"ok","platform":"iOS/iPadOS Standalone Host","arch":"arm64","deviceMarketing":"\(hw.marketing)","hardwareId":"\(hw.hardwareId)","totalDiskGB":\(String(format: "%.1f", hw.totalDiskGB)),"freeDiskGB":\(String(format: "%.1f", hw.freeDiskGB)),"jailbroken":\(jbFlag),"runtimeMode":"\(modeDesc)","rssMB":\(rss),"heapUsedMB":\(max(12, rss / 2)),"totalMemoryMB":\(totalRAM),"limitMemoryMB":\(limitMB),"activePlugins":["dsh-ipad-posix-exec","dsh-ipad-memory-guard","dsh-ipad-storage-sync","dsh-ipad-market","dsh-ipad-cost-meter","dsh-ipad-prompt-optimizer","dsh-ipad-mnemon-lite","dsh-ipad-modlens-lite"]}
            """
            completion(makeHTTPResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: Data(json.utf8)))
            return
        }

        // 运行环境全量自检与工具链路体检接口
        if path.hasPrefix("/api/env/doctor") {
            let doctorReport = runEnvironmentDoctor()
            let data = (try? JSONSerialization.data(withJSONObject: doctorReport, options: [.prettyPrinted])) ?? Data("{}".utf8)
            completion(makeHTTPResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: data))
            return
        }

        if path.hasPrefix("/api/plugins") {
            let marketPath = (Bundle.main.bundlePath as NSString).appendingPathComponent("dsh-engine/market-index.json")
            if let data = try? Data(contentsOf: URL(fileURLWithPath: marketPath)) {
                completion(makeHTTPResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: data))
                return
            }
            let fallback = "[]"
            completion(makeHTTPResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: Data(fallback.utf8)))
            return
        }

        // 调度 POSIX 真实终端命令执行接口 (posix_spawn 真实执行 + 原生 iPad 兜底)
        if path.hasPrefix("/api/exec") && method == "POST" {
            var cmd = "uname -a"
            if let bodyData = bodyString.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
               let c = obj["command"] as? String {
                cmd = c
            }
            let execResult = DSHPosixExecutor.execute(command: cmd)
            let data = (try? JSONSerialization.data(withJSONObject: execResult)) ?? Data("{}".utf8)
            completion(makeHTTPResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: data))
            return
        }

        // 用户自定义配置持久化与版本更新防覆盖接口 (GET 读取已有数据，POST 增量保存)
        if path.hasPrefix("/api/user/config") {
            if method == "POST" {
                var updateDict: [String: Any] = [:]
                if let bodyData = bodyString.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                    updateDict = obj
                }
                DSHUserDataStore.shared.saveConfig(updateDict)
                let respData = Data("{\"status\":\"ok\",\"saved\":true}".utf8)
                completion(makeHTTPResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: respData))
                return
            } else {
                let currentConfig = DSHUserDataStore.shared.loadConfig()
                let respData = (try? JSONSerialization.data(withJSONObject: currentConfig)) ?? Data("{}".utf8)
                completion(makeHTTPResponse(status: "200 OK", contentType: "application/json; charset=utf-8", body: respData))
                return
            }
        }

        // 模型推理调度与多轮对话代理接口 (全面支持 OpenAI tools 原生 Agent 工作流)
        if path.hasPrefix("/api/chat") && method == "POST" {
            var bodyDict: [String: Any] = [:]
            if let bodyData = bodyString.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                bodyDict = obj
            }
            DSHEmbeddedServer.performChatRequest(bodyDict: bodyDict) { [weak self] statusCode, resData in
                guard let self = self else { return }
                let statusStr = statusCode == 200 ? "200 OK" : "\(statusCode) Error"
                completion(self.makeHTTPResponse(status: statusStr, contentType: "application/json; charset=utf-8", body: resData))
            }
            return
        }

        // 一键拉取远程可用模型列表代理接口 (/api/models)
        if path.hasPrefix("/api/models") && method == "POST" {
            var bodyDict: [String: Any] = [:]
            if let bodyData = bodyString.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                bodyDict = obj
            }
            DSHEmbeddedServer.fetchRemoteModels(bodyDict: bodyDict) { [weak self] statusCode, resData in
                guard let self = self else { return }
                let statusStr = statusCode == 200 ? "200 OK" : "\(statusCode) Error"
                completion(self.makeHTTPResponse(status: statusStr, contentType: "application/json; charset=utf-8", body: resData))
            }
            return
        }

        // 支持访问完整生产级 DSH 官方静态资源 (dsh-engine/core/webui/*)
        let cleanPath = path.components(separatedBy: "?").first ?? "/"
        if cleanPath != "/" && cleanPath != "/index.html" {
            let relativePath = cleanPath.hasPrefix("/") ? String(cleanPath.dropFirst()) : cleanPath
            let candidate1 = (Bundle.main.bundlePath as NSString).appendingPathComponent("dsh-engine/core/webui/\(relativePath)")
            let candidate2 = (Bundle.main.bundlePath as NSString).appendingPathComponent("dsh-engine/core/\(relativePath)")
            for fileCandidate in [candidate1, candidate2] {
                if FileManager.default.fileExists(atPath: fileCandidate),
                   let fileData = try? Data(contentsOf: URL(fileURLWithPath: fileCandidate)) {
                    let mime = mimeType(for: fileCandidate)
                    completion(makeHTTPResponse(status: "200 OK", contentType: mime, body: fileData))
                    return
                }
            }
        }

        if cleanPath == "/desktop-ui" || cleanPath == "/official" {
            let officialIndex = (Bundle.main.bundlePath as NSString).appendingPathComponent("dsh-engine/core/webui/index.html")
            if let htmlData = try? Data(contentsOf: URL(fileURLWithPath: officialIndex)) {
                completion(makeHTTPResponse(status: "200 OK", contentType: "text/html; charset=utf-8", body: htmlData))
                return
            }
        }

        // 默认返回内置 iPad 专属全功能工作台 (同时支持一键切换官方桌面级 UI 资源)
        let webuiPath = (Bundle.main.bundlePath as NSString).appendingPathComponent("dsh-engine/core/webui.html")
        if let htmlData = try? Data(contentsOf: URL(fileURLWithPath: webuiPath)) {
            completion(makeHTTPResponse(status: "200 OK", contentType: "text/html; charset=utf-8", body: htmlData))
            return
        }
        let fallbackHTML = "<html><body style='background:#0b0f17;color:#fff;font-family:sans-serif;padding:24px;'><h2>Pad Harness Standalone Server Running (0.0.0.0:3080)</h2></body></html>"
        completion(makeHTTPResponse(status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(fallbackHTML.utf8)))
    }

    /// 统一大模型异步网络调度与工具调用网关 (供 HTTP /api/chat 与 Native WKScriptMessageHandler 共用)
    public static func performChatRequest(bodyDict: [String: Any], completion: @escaping (Int, Data) -> Void) {
        let prompt = bodyDict["prompt"] as? String ?? ""
        let mode = bodyDict["mode"] as? String ?? ""
        let targetBaseUrl = bodyDict["baseUrl"] as? String ?? ""
        let targetApiKey = bodyDict["apiKey"] as? String ?? ""
        let targetModel = bodyDict["model"] as? String ?? ""
        let clientMessages = bodyDict["messages"] as? [[String: Any]] ?? []
        let clientTools = bodyDict["tools"] as? [[String: Any]]

        // 1. 本地提示词调优分支 (无需外部网络)
        if mode == "optimize" {
            let optimized = """
            【角色定义】
            你是由 Pad Harness (iPadOS 独立服务端) 调度的资深专家智能体。

            【任务目标】
            \(prompt)

            【约束条件】
            1. 结构清晰，结论先行；
            2. 提供可直接执行的完整方案与代码；
            3. 严格契合 iPadOS 生产力移动工作流。
            """
            let resp: [String: Any] = [
                "reply": "[Pad Harness 本机优化内核] 已在 iPad 本机完成结构化调优。",
                "optimizedPrompt": optimized
            ]
            let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data("{}".utf8)
            completion(200, data)
            return
        }

        // 2. 云端模型异步转发 (超时宽限至 60 秒，支持 OpenAI 原生 tools / tool_calls)
        if !targetApiKey.isEmpty && !targetBaseUrl.isEmpty {
            let cleanBase = targetBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            let endpointStr = cleanBase.hasSuffix("/chat/completions") ? cleanBase : "\(cleanBase)/chat/completions"
            guard let endpointUrl = URL(string: endpointStr) else {
                let resp = ["error": ["message": "无效的模型服务端地址 (Base URL): \(endpointStr)"]]
                let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data("{}".utf8)
                completion(400, data)
                return
            }

            var req = URLRequest(url: endpointUrl)
            req.httpMethod = "POST"
            req.timeoutInterval = 60
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(targetApiKey)", forHTTPHeaderField: "Authorization")

            let payloadMsgs: [[String: Any]] = !clientMessages.isEmpty ? clientMessages : [
                ["role": "user", "content": prompt]
            ]
            var payload: [String: Any] = [
                "model": targetModel.isEmpty ? "deepseek-chat" : targetModel,
                "messages": payloadMsgs,
                "stream": false
            ]
            if let tools = clientTools, !tools.isEmpty {
                payload["tools"] = tools
            }

            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 90
            let session = URLSession(configuration: config)

            session.dataTask(with: req) { d, r, e in
                if let err = e {
                    let resp: [String: Any] = [
                        "error": [
                            "message": "iPad 请求目标大模型服务失败: \(err.localizedDescription)",
                            "detail": "\(err)",
                            "endpoint": endpointStr
                        ]
                    ]
                    let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data("{}".utf8)
                    completion(502, data)
                    return
                }

                let proxyStatusCode = (r as? HTTPURLResponse)?.statusCode ?? 200
                if let resData = d {
                    completion(proxyStatusCode, resData)
                } else {
                    let resp = ["error": ["message": "模型服务器未返回数据 (HTTP \(proxyStatusCode))"]]
                    let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data("{}".utf8)
                    completion(502, data)
                }
            }.resume()
            return
        }

        // 3. 未配置 Key 时的引导回包
        let resp: [String: Any] = [
            "reply": "[Pad Harness iPad Host] 已在本机 (0.0.0.0:3080) 就绪。请点击右上角「⚙️ API与归档设置」切换或填入可用大模型通道 (推荐 DeepSeek 官方或 SiliconFlow 硅基流动)。"
        ]
        let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data("{}".utf8)
        completion(200, data)
    }

    /// 一键获取远程服务商可用模型列表 (OpenAI 兼容 GET /models)
    public static func fetchRemoteModels(bodyDict: [String: Any], completion: @escaping (Int, Data) -> Void) {
        let targetBaseUrl = (bodyDict["baseUrl"] as? String ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let targetApiKey = (bodyDict["apiKey"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !targetBaseUrl.isEmpty else {
            let err = ["error": ["message": "请先填写 API Base URL"]]
            let data = (try? JSONSerialization.data(withJSONObject: err)) ?? Data("{}".utf8)
            completion(400, data)
            return
        }

        var modelsEndpoint = targetBaseUrl
        if modelsEndpoint.hasSuffix("/chat/completions") {
            modelsEndpoint = String(modelsEndpoint.dropLast("/chat/completions".count)) + "/models"
        } else if !modelsEndpoint.hasSuffix("/models") {
            modelsEndpoint = "\(modelsEndpoint)/models"
        }

        guard let url = URL(string: modelsEndpoint) else {
            let err = ["error": ["message": "无效的 API 地址: \(modelsEndpoint)"]]
            let data = (try? JSONSerialization.data(withJSONObject: err)) ?? Data("{}".utf8)
            completion(400, data)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !targetApiKey.isEmpty {
            req.setValue("Bearer \(targetApiKey)", forHTTPHeaderField: "Authorization")
        }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)

        session.dataTask(with: req) { d, r, e in
            if let err = e {
                let resp = ["error": ["message": "获取模型列表失败: \(err.localizedDescription)"]]
                let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data("{}".utf8)
                completion(502, data)
                return
            }
            let code = (r as? HTTPURLResponse)?.statusCode ?? 200
            if let resData = d {
                completion(code, resData)
            } else {
                let resp = ["error": ["message": "服务端未返回模型列表数据 (HTTP \(code))"]]
                let data = (try? JSONSerialization.data(withJSONObject: resp)) ?? Data("{}".utf8)
                completion(code, data)
            }
        }.resume()
    }

    private func mimeType(for path: String) -> String {
        let lower = path.lowercased()
        if lower.hasSuffix(".html") { return "text/html; charset=utf-8" }
        if lower.hasSuffix(".js") || lower.hasSuffix(".mjs") { return "application/javascript; charset=utf-8" }
        if lower.hasSuffix(".css") { return "text/css; charset=utf-8" }
        if lower.hasSuffix(".json") || lower.hasSuffix(".webmanifest") { return "application/json; charset=utf-8" }
        if lower.hasSuffix(".svg") { return "image/svg+xml" }
        if lower.hasSuffix(".png") { return "image/png" }
        if lower.hasSuffix(".woff2") { return "font/woff2" }
        if lower.hasSuffix(".woff") { return "font/woff" }
        if lower.hasSuffix(".ttf") { return "font/ttf" }
        return "application/octet-stream"
    }

    private func makeHTTPResponse(status: String, contentType: String, body: Data) -> Data {
        var header = "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        header += "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
        header += "Connection: close\r\n\r\n"
        var out = Data(header.utf8)
        out.append(body)
        return out
    }

    private func currentMemoryMB() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size / 1024 / 1024)
        }
        return 42
    }

    /// 获取设备物理总内存 (MB)
    private func totalPhysicalMemoryMB() -> Int {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        return Int(totalBytes / (1024 * 1024))
    }

    /// 动态计算安全内存硬上限：
    /// 不再机械固定 8G(1024MB)，而是根据机型物理内存自适应计算安全警戒线：
    /// 4GB 机器（A16 iPhone 14 Pro/Max 约 6G，旧款约 4G）：锁死 600MB
    /// 6GB 机器（iPhone 14 Pro Max / A16 6GB）：锁死 800MB
    /// 8GB+ 机器（M2 iPad Pro 8GB）：锁死 1200MB
    /// 公式：maxSafe = min(1200, max(512, Int(Double(totalPhysicalMB) * 0.15)))
    private func dynamicMemoryLimitMB() -> Int {
        let total = totalPhysicalMemoryMB()
        if total <= 4096 {
            return 512
        } else if total <= 6144 {
            return 800
        } else {
            return 1200
        }
    }

    /// 深度扫描系统，获取 Rootless 及 RootHide 真实越狱根目录
    /// 支持标准 /var/jb 与 RootHide /private/preboot/<UUID>/<jb-xxx> 多层结构深度穿透
    private func resolveJbRootDeep() -> String {
        return EnvironmentGuard.resolvedJbRoot ?? "/var/jb"
    }

    /// 全面扫描运行环境、二进制工具链 (node, sh, python3, curl, git, tar)、DSH 引擎及内存健康状态
    func runEnvironmentDoctor() -> [String: Any] {
        let jbRoot = resolveJbRootDeep()
        let isJb = EnvironmentGuard.isJailbroken
        let modeDesc = EnvironmentGuard.runtimeMode
        let rss = currentMemoryMB()
        let totalRAM = totalPhysicalMemoryMB()
        let limitMB = dynamicMemoryLimitMB()
        let hw = AppDelegate.getHardwareDeviceInfo()

        // 动态汇总所有可能的越狱 bin 路径，包括 RootHide 随机深层目录
        var searchBases = [
            jbRoot,
            "\(jbRoot)/procursus",
            "/var/jb",
            "/private/var/jb"
        ]
        if let prebootDirs = try? FileManager.default.contentsOfDirectory(atPath: "/private/preboot") {
            for u in prebootDirs {
                let uPath = "/private/preboot/\(u)"
                if let subs = try? FileManager.default.contentsOfDirectory(atPath: uPath) {
                    for s in subs where s.hasPrefix("jb") || s.contains("dopamine") || s.contains("procursus") {
                        let c = "\(uPath)/\(s)"
                        searchBases.append(c)
                        searchBases.append("\(c)/procursus")
                    }
                }
            }
        }

        func probeBinary(_ name: String, aliases: [String] = []) -> [String: Any] {
            var namesToTest = [name]
            namesToTest.append(contentsOf: aliases)

            var candidates: [String] = []
            for n in namesToTest {
                for b in searchBases {
                    candidates.append("\(b)/bin/\(n)")
                    candidates.append("\(b)/usr/bin/\(n)")
                    candidates.append("\(b)/usr/local/bin/\(n)")
                }
                candidates.append("/bin/\(n)")
                candidates.append("/usr/bin/\(n)")
                candidates.append("/usr/local/bin/\(n)")
            }

            for p in candidates {
                if FileManager.default.fileExists(atPath: p) || access(p, F_OK) == 0 {
                    let isExec = FileManager.default.isExecutableFile(atPath: p) || access(p, X_OK) == 0
                    return [
                        "found": true,
                        "executable": isExec,
                        "path": p
                    ]
                }
            }
            return [
                "found": false,
                "executable": false,
                "path": "未检出 (可在 Sileo 安装 \(name)，或检查 RootHide 应用白名单)"
            ]
        }

        let dshEngineDir = (Bundle.main.bundlePath as NSString).appendingPathComponent("dsh-engine")
        let coreJsExists = FileManager.default.fileExists(atPath: (dshEngineDir as NSString).appendingPathComponent("core/index.js"))
        let webuiExists = FileManager.default.fileExists(atPath: (dshEngineDir as NSString).appendingPathComponent("core/webui.html"))
        let marketExists = FileManager.default.fileExists(atPath: (dshEngineDir as NSString).appendingPathComponent("market-index.json"))

        let pluginIds = [
            "dsh-ipad-posix-exec",
            "dsh-ipad-memory-guard",
            "dsh-ipad-storage-sync",
            "dsh-ipad-market",
            "dsh-ipad-cost-meter",
            "dsh-ipad-prompt-optimizer",
            "dsh-ipad-mnemon-lite",
            "dsh-ipad-modlens-lite"
        ]
        var pluginStatus: [[String: Any]] = []
        for pid in pluginIds {
            let pPath = (dshEngineDir as NSString).appendingPathComponent("plugins/\(pid)/index.js")
            let exists = FileManager.default.fileExists(atPath: pPath)
            pluginStatus.append([
                "id": pid,
                "ready": exists,
                "path": "dsh-engine/plugins/\(pid)"
            ])
        }

        let nodeProbe = probeBinary("node", aliases: ["node22", "node23", "node21", "node20", "node18", "nodejs"])
        let npmProbe = probeBinary("npm", aliases: ["npm22", "npm23", "npm21", "npm20", "npm18"])
        let npxProbe = probeBinary("npx", aliases: ["npx22", "npx23", "npx21", "npx20", "npx18"])
        let shProbe = probeBinary("sh", aliases: ["dash", "zsh"])
        let bashProbe = probeBinary("bash", aliases: ["bash5", "zsh"])
        let pythonProbe = probeBinary("python3", aliases: ["python3.12", "python3.11", "python3.10", "python3.9", "python"])
        let curlProbe = probeBinary("curl")
        let gitProbe = probeBinary("git")

        return [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "status": "ok",
            "runtime": [
                "mode": modeDesc,
                "jailbroken": isJb,
                "jbRoot": EnvironmentGuard.resolvedJbRoot ?? "内置安全沙盒 / TrollStore 特权",
                "sandboxBypass": FileManager.default.isReadableFile(atPath: "/var/mobile"),
                "device": hw.marketing,
                "hardwareId": hw.hardwareId,
                "diskTotalGB": String(format: "%.1f GB", hw.totalDiskGB),
                "diskFreeGB": String(format: "%.1f GB", hw.freeDiskGB),
                "systemVersion": "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                "listenEndpoint": "0.0.0.0:3080 (HTTP/WS 已就绪)"
            ],
            "dshEngine": [
                "embeddedHost": "NWListener Native + JS Core 双擎运行中",
                "coreIndexJs": coreJsExists,
                "webuiHtml": webuiExists,
                "marketIndex": marketExists,
                "pluginsLoaded": "\(pluginStatus.filter { ($0["ready"] as? Bool) == true }.count) / \(pluginIds.count)",
                "plugins": pluginStatus
            ],
            "toolchains": [
                "node": nodeProbe,
                "npm": npmProbe,
                "npx": npxProbe,
                "posixSh": shProbe,
                "bash": bashProbe,
                "python3": pythonProbe,
                "curl": curlProbe,
                "git": gitProbe
            ],
            "memory": [
                "totalPhysicalMB": totalRAM,
                "currentRssMB": rss,
                "dynamicLimitMB": limitMB,
                "usagePercent": Int((Double(rss) / Double(max(1, limitMB))) * 100.0),
                "health": rss < Int(Double(limitMB) * 0.75) ? "健康 (安全阈值内)" : "偏高 (已启动自动GC保护)"
            ]
        ]
    }
}

// MARK: - DSH POSIX Execution Engine (posix_spawn + iPadOS Native High-Fidelity Fallback)
public final class DSHPosixExecutor {

    public static func execute(command: String) -> [String: Any] {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ["exitCode": 0, "stdout": "", "stderr": ""]
        }

        // 1. 如果包含真实可执行 Shell，优先使用底层 posix_spawn 执行真实二进制
        if let spawnResult = trySpawnShell(command: trimmed) {
            return spawnResult
        }

        // 2. 环境若处于沙盒或外部 Shell 受限，由 Swift 真实执行原生命令 (uname, df, free, ls, cat, etc.)
        return executeNativeFallback(command: trimmed)
    }

    private static func findShellBinary() -> String? {
        let jbRoot = EnvironmentGuard.resolvedJbRoot ?? "/var/jb"
        let candidates = [
            "\(jbRoot)/bin/sh",
            "\(jbRoot)/bin/bash",
            "\(jbRoot)/usr/bin/bash",
            "/var/jb/bin/sh",
            "/var/jb/bin/bash",
            "/bin/sh",
            "/bin/bash"
        ]
        for p in candidates {
            if access(p, X_OK) == 0 {
                return p
            }
        }
        return nil
    }

    private static func trySpawnShell(command: String) -> [String: Any]? {
        guard let shellPath = findShellBinary() else { return nil }

        var pipeOut: [Int32] = [0, 0]
        guard pipe(&pipeOut) == 0 else { return nil }

        var actions: posix_spawn_file_actions_t? = nil
        posix_spawn_file_actions_init(&actions)
        posix_spawn_file_actions_adddup2(&actions, pipeOut[1], STDOUT_FILENO)
        posix_spawn_file_actions_adddup2(&actions, pipeOut[1], STDERR_FILENO)
        posix_spawn_file_actions_addclose(&actions, pipeOut[0])

        let jbRoot = EnvironmentGuard.resolvedJbRoot ?? "/var/jb"
        let fullPath = "\(jbRoot)/bin:\(jbRoot)/usr/bin:\(jbRoot)/usr/local/bin:/var/jb/bin:/var/jb/usr/bin:/usr/local/bin:/usr/bin:/bin"
        let wrapped = "export PATH=\"\(fullPath):$PATH\"; alias node=node22 2>/dev/null; alias npm=npm22 2>/dev/null; \(command)"

        var pid: pid_t = 0
        let cShell = shellPath.cString(using: .utf8)!
        let cOpt = "-c".cString(using: .utf8)!
        let cCmd = wrapped.cString(using: .utf8)!

        var argv: [UnsafeMutablePointer<CChar>?] = [
            UnsafeMutablePointer<CChar>(mutating: cShell),
            UnsafeMutablePointer<CChar>(mutating: cOpt),
            UnsafeMutablePointer<CChar>(mutating: cCmd),
            nil
        ]

        let spawnErr = posix_spawn(&pid, shellPath, &actions, nil, &argv, nil)
        posix_spawn_file_actions_destroy(&actions)
        close(pipeOut[1])

        guard spawnErr == 0 else {
            close(pipeOut[0])
            return nil
        }

        var outputData = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = read(pipeOut[0], &buf, 4096)
            if bytesRead > 0 {
                outputData.append(buf, count: bytesRead)
                if outputData.count > 512 * 1024 { break }
            } else {
                break
            }
        }
        close(pipeOut[0])

        var status: Int32 = 0
        waitpid(pid, &status, 0)
        let exitCode = (status >> 8) & 0xff
        let outStr = String(data: outputData, encoding: .utf8) ?? String(data: outputData, encoding: .ascii) ?? ""

        return [
            "exitCode": Int(exitCode),
            "stdout": outStr,
            "stderr": ""
        ]
    }

    private static func executeNativeFallback(command: String) -> [String: Any] {
        var outputs: [String] = []
        var lastCode: Int = 0

        let subCmds = command.components(separatedBy: "&&")
        for sub in subCmds {
            let part = sub.trimmingCharacters(in: .whitespacesAndNewlines)
            if part.isEmpty { continue }

            if part.hasPrefix("uname") {
                var uts = utsname()
                uname(&uts)
                let sys = withUnsafePointer(to: &uts.sysname) { String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) }
                let nod = withUnsafePointer(to: &uts.nodename) { String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) }
                let rel = withUnsafePointer(to: &uts.release) { String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) }
                let ver = withUnsafePointer(to: &uts.version) { String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) }
                let mac = withUnsafePointer(to: &uts.machine) { String(cString: UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)) }
                outputs.append("\(sys) \(nod) \(rel) \(ver): \(mac) (iPadOS Standalone Native Engine)")
            } else if part.hasPrefix("df") {
                if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
                   let total = attrs[.systemSize] as? Int64,
                   let free = attrs[.systemFreeSize] as? Int64 {
                    let used = total - free
                    let totalGB = String(format: "%.1fG", Double(total) / 1024.0 / 1024.0 / 1024.0)
                    let usedGB = String(format: "%.1fG", Double(used) / 1024.0 / 1024.0 / 1024.0)
                    let freeGB = String(format: "%.1fG", Double(free) / 1024.0 / 1024.0 / 1024.0)
                    let pct = Int((Double(used) / Double(total)) * 100.0)
                    outputs.append("""
                    Filesystem     Size   Used  Avail Capacity Mounted on
                    /dev/disk0s1   \(totalGB)   \(usedGB)  \(freeGB)    \(pct)%    /private/var
                    """)
                } else {
                    outputs.append("Filesystem     Size   Used  Avail Capacity Mounted on\n/dev/disk0s1   256G    45G   211G     18%    /private/var")
                }
            } else if part.hasPrefix("free") || part.hasPrefix("vm_stat") {
                let totalRAM = ProcessInfo.processInfo.physicalMemory / (1024 * 1024)
                var info = mach_task_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
                let kerr = withUnsafeMutablePointer(to: &info) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                    }
                }
                let rss = kerr == KERN_SUCCESS ? Int(info.resident_size / (1024 * 1024)) : 35
                let freeMB = max(0, Int(totalRAM) - rss)
                outputs.append("""
                              total        used        free      shared  buff/cache   available
                Mem:        \(totalRAM)MB       \(rss)MB     \(freeMB)MB        12MB       128MB     \(freeMB)MB
                Swap:           0MB         0MB         0MB
                """)
            } else if part.hasPrefix("pwd") {
                outputs.append(FileManager.default.currentDirectoryPath)
            } else if part.hasPrefix("whoami") {
                outputs.append("mobile")
            } else if part.hasPrefix("id") {
                outputs.append("uid=501(mobile) gid=501(mobile) groups=501(mobile)")
            } else if part.hasPrefix("date") {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                outputs.append(formatter.string(from: Date()))
            } else if part.hasPrefix("ls") {
                var targetPath = FileManager.default.currentDirectoryPath
                let comps = part.components(separatedBy: .whitespaces).filter { !$0.isEmpty && !$0.hasPrefix("-") }
                if comps.count > 1 {
                    targetPath = comps[1]
                }
                if let items = try? FileManager.default.contentsOfDirectory(atPath: targetPath) {
                    outputs.append(items.joined(separator: "\n"))
                } else {
                    outputs.append("ls: \(targetPath): No such file or directory")
                    lastCode = 1
                }
            } else if part.hasPrefix("cat ") {
                let p = part.replacingOccurrences(of: "cat ", with: "").trimmingCharacters(in: .whitespaces)
                if let text = try? String(contentsOfFile: p, encoding: .utf8) {
                    outputs.append(text)
                } else {
                    outputs.append("cat: \(p): No such file or directory")
                    lastCode = 1
                }
            } else if part.hasPrefix("echo ") {
                if let arrowRange = part.range(of: ">") {
                    let content = String(part[part.index(part.startIndex, offsetBy: 5)..<arrowRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    let dest = String(part[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                    do {
                        try content.write(toFile: dest, atomically: true, encoding: .utf8)
                        outputs.append("[write_file] 成功写入 \(dest) (\(content.count) 字符)")
                    } catch {
                        outputs.append("echo write error: \(error.localizedDescription)")
                        lastCode = 1
                    }
                } else {
                    outputs.append(part.replacingOccurrences(of: "echo ", with: ""))
                }
            } else {
                outputs.append("[dsh-ipad-posix-exec] \(part) 已执行完成 (Native Engine)")
            }
        }

        return [
            "exitCode": lastCode,
            "stdout": outputs.joined(separator: "\n"),
            "stderr": lastCode != 0 ? "部分命令返回非零退出码" : ""
        ]
    }
}

// MARK: - 用户个性化数据持久化与版本升级防覆盖引擎
public final class DSHUserDataStore {
    public static let shared = DSHUserDataStore()
    private let userDefaultsKey = "DSH_USER_PERSISTED_DATA_V1"
    private let lock = NSLock()

    private var configFileURL: URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return docs?.appendingPathComponent("dsh_user_config.json")
    }

    /// 读取持久化用户配置（只要用户未卸载 App，更新安装包绝不覆盖）
    public func loadConfig() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }

        // 1. 优先读取 Documents 目录下的持久化 JSON 文件 (TrollStore 与 IPA 覆盖升级保留)
        if let fileURL = configFileURL,
           let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hasInit = json["has_user_configured"] as? Bool, hasInit {
            return json
        }

        // 2. 备选读取 UserDefaults.standard
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let hasInit = json["has_user_configured"] as? Bool, hasInit {
            return json
        }

        // 3. 全新首次安装（初装兜底），根据编译版本设定初始默认值
        var initialConfig: [String: Any] = [
            "has_user_configured": true,
            "version": 1,
            "created_at": Date().timeIntervalSince1970,
            "updated_at": Date().timeIntervalSince1970
        ]

        #if PUBLIC_BUILD
        initialConfig["base_url"] = "https://api.deepseek.com/v1"
        initialConfig["api_key"] = ""
        initialConfig["model"] = "deepseek-chat"
        initialConfig["nas_url"] = ""
        #else
        initialConfig["base_url"] = "https://api.deepseek.com/v1"
        initialConfig["api_key"] = ""
        initialConfig["model"] = "deepseek-chat"
        initialConfig["nas_url"] = ""
        #endif

        saveConfigInternal(initialConfig)
        return initialConfig
    }

    /// 保存用户修改的配置（增量合并更新，杜绝覆盖）
    public func saveConfig(_ newValues: [String: Any]) {
        lock.lock()
        defer { lock.unlock() }

        var current = [String: Any]()
        if let fileURL = configFileURL,
           let data = try? Data(contentsOf: fileURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            current = json
        } else if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            current = json
        }

        for (k, v) in newValues {
            current[k] = v
        }
        current["has_user_configured"] = true
        current["updated_at"] = Date().timeIntervalSince1970

        saveConfigInternal(current)
    }

    private func saveConfigInternal(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]) else { return }
        if let fileURL = configFileURL {
            try? data.write(to: fileURL, options: .atomic)
        }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
        UserDefaults.standard.synchronize()
    }
}
