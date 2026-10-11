import UIKit
import MachO

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let root = ViewController()
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
        // 环境检测：硬件硬性锁定 iPad，权限硬性锁定 TrollStore 或 越狱（严禁 iPhone 与纯证书自签运行）
        EnvironmentGuard.enforceEnvironmentGate(window: window)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}


// MARK: - Pad Harness Environment Guard (Compatible with Standard Rootless & RootHide Dynamic Random Paths)
enum GuardError: String {
    case notIPad = "设备类型错误：当前设备不是 iPad。本应用为 Pad Harness 专属，仅允许在 iPad 设备上运行。"
    case notJailbroken = "越狱环境缺失：未检测到有效越狱环境（如 Dopamine、RootHide 或 TrollStore 权限环境）。Pad Harness 需要越狱环境以解除进程常驻、端口监听与底层调用限制。"
    case missingNode = "核心组件缺失：未检测到 Node.js 运行时环境（node）。请在 Sileo / Zebra 中安装 nodejs 软件包。"
    case missingSh = "终端工具缺失：未检测到基础 POSIX Shell 解释器（sh/bash）。请在越狱包管理器中安装 bash 软件包。"
    case missingDaemon = "后台守护缺失：未安装 Pad Harness 系统级守护配置（com.dsh.server.plist）。Pad Harness 需要该守护配置以实现 iPad 锁屏保活。"
}

final class EnvironmentGuard {

    /// 动态缓存检测到的真实 jb 根目录（标准为 /var/jb，roothide 为 /private/preboot/<UUID>/jb-* 等动态路径）
    static var resolvedJbRoot: String? = nil
    /// 是否处于越狱环境（有底层外部 Shell 执行能力）
    static var isJailbroken: Bool = false
    /// 当前运行模式描述
    static var runtimeMode: String = "TrollStore / 纯净自签模式 (内置沙盒闭环)"

    /// 启动自适应环境门禁：解除纯 iPad 硬件限制，支持 iPhone/iPad 双端运行；检测到低配旧款 iPhone 弹出友好性能提醒
    static func enforceEnvironmentGate(window: UIWindow?) {
        // 门禁 1：设备性能与旧款 iPhone 检测提示 (解除硬性阻断，但对旧款/低系统 iPhone 给予告警与建议)
        checkDevicePerformanceAdvisory(window: window)

        // 门禁 2：特权环境识别（支持 Dopamine/RootHide 动态越狱 与 TrollStore 巨魔；自签环境友好降级或提示）
        let jbRoot = detectJailbreakRoot()
        resolvedJbRoot = jbRoot
        let isTroll = isTrollStoreEnvironment()

        if let root = jbRoot {
            isJailbroken = true
            runtimeMode = "iOS 越狱增强模式 (根目录: \(root))"
            print("[PadHarness EnvironmentGuard] ✅ 探测到越狱环境: \(root)，具备全量底层权限。")
        } else if isTroll {
            isJailbroken = false
            runtimeMode = "TrollStore 巨魔独立模式 (满血持久保活)"
            print("[PadHarness EnvironmentGuard] ✅ 探测到 TrollStore/沙盒穿透环境，具备后台常驻与免沙盒杀进程特权。")
        } else {
            #if !PUBLIC_BUILD
            // 个人版：开发与实测阶段绝不阻断，自动切换到内置独立服务端模式
            isJailbroken = false
            runtimeMode = "本机独立服务端模式 (RootHide/沙盒保护环境)"
            print("[PadHarness EnvironmentGuard] ℹ️ 个人版优先保障运行：已就绪于独立模式。")
            #else
            // 公开版：严苛拦截纯证书自签
            terminateWithAlert(
                title: "❌ 运行权限不足拦截",
                message: "【iOS Harness】是无需电脑的本机独立 DSH 服务端，必须依赖系统底层特权（无限后台常驻保活、端口常驻监听、防止锁屏杀进程）。\n\n检测到当前为「普通个人/企业证书自签名安装」：\n由于 iOS 原生沙盒的物理封锁，纯证书自签无法保活。为保障体验完整性，本应用严禁在纯证书环境下运行。\n\n请使用 TrollStore (巨魔) 安装，或在 Dopamine / RootHide 越狱环境下使用！",
                window: window
            )
            return
            #endif
        }
    }

    /// 检测是否为低系统或旧款低配 iPhone，若是则弹出温馨提示（建议不使用，可能出现卡顿）
    private static func checkDevicePerformanceAdvisory(window: UIWindow?) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }

        let hwInfo = AppDelegate.getHardwareDeviceInfo()
        let hwId = hwInfo.hardwareId // 例如 "iPhone11,8", "iPhone14,2"
        let marketing = hwInfo.marketing
        let totalRAMMB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024))
        let sysVerStr = UIDevice.current.systemVersion
        let majorVer = Int(sysVerStr.components(separatedBy: ".").first ?? "16") ?? 16

        var isOldPhoneModel = false
        if hwId.hasPrefix("iPhone") {
            let numPart = hwId.replacingOccurrences(of: "iPhone", with: "")
            if let majorModel = Int(numPart.components(separatedBy: ",").first ?? "99"), majorModel <= 13 {
                // iPhone13,x 为 iPhone 12 系列，<=13 涵盖 iPhone 12 及更早机型 (iPhone 11/X/XR/XS/8 等)
                isOldPhoneModel = true
            }
        }

        let isLowSystem = majorVer < 16
        let isLowMemory = totalRAMMB < 4500

        if isOldPhoneModel || isLowSystem || isLowMemory {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = UIAlertController(
                    title: "⚠️ 硬件与系统性能提示",
                    message: """
                    检测到当前设备为：\(marketing) (\(hwId))
                    系统版本：iOS \(sysVerStr)
                    物理运存：\(totalRAMMB) MB

                    【iOS Harness】内置完整 Node.js / DSH 独立服务端与多轮智能体调度引擎。当前设备属于旧款机型或低版本系统（运存较小），在本机承载服务端高负载工作流时可能会出现发热或界面卡顿。

                    💡 建议：为获得最佳生产力体验，建议在 M 系列 iPad 或 iPhone 13 Pro / 14 Pro 及以上高配设备上使用；在当前设备上建议优先使用纯文本轻量模式。
                    """,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "我已知晓，继续使用", style: .default, handler: nil))
                if let rootVC = window?.rootViewController {
                    rootVC.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    /// 严格检测是否具备 TrollStore (巨魔) 特权 或 越狱下的逃逸沙盒能力
    private static func isTrollStoreEnvironment() -> Bool {
        // 特征 1：沙盒逃逸能力检测（普通自签无法读取沙盒外文件，巨魔和越狱则畅行无阻）
        let testPaths = [
            "/var/mobile/Library/Preferences",
            "/var/mobile/Media",
            "/var/mobile/Containers",
            "/var/mobile"
        ]
        for p in testPaths {
            if FileManager.default.isReadableFile(atPath: p) {
                return true
            }
        }

        // 特征 2：TrollStore / 越狱持久标记
        let trollStorePaths = [
            "/var/containers/Bundle/trollstore.app",
            "/var/mobile/Library/TrollStore",
            "/Applications/TrollStore.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app"
        ]
        for path in trollStorePaths {
            if FileManager.default.fileExists(atPath: path) || access(path, F_OK) == 0 {
                return true
            }
        }

        // 特征 3：检测环境变量中的特殊标志
        if ProcessInfo.processInfo.environment["TROLLSTORE"] != nil ||
           ProcessInfo.processInfo.environment["SIMULATE_ROOT"] != nil {
            return true
        }

        return false
    }

    /// 动态探测越狱根目录与特权环境（完全对标 RootHide 官方 libroothide/common.h & Bootstrap/utils.m）：
    /// RootHide 官方规范：
    /// - JB_ROOT_PARENT = "/var/containers/Bundle/Application"
    /// - JB_ROOT_PREFIX = ".jbroot-" (后面跟 16 位十六进制 jbrand 校验值，如 .jbroot-125AADABA42C78BE)
    /// - 备选目录：/private/preboot/<UUID>/jb-* 与标准 Rootless /var/jb
    private static func detectJailbreakRoot() -> String? {
        // 候选 0：优先尝试 dlsym 调用已注入的 libroothide / libroot C API
        if let handle = dlopen(nil, RTLD_NOW) {
            typealias JbRootFn = @convention(c) (UnsafePointer<CChar>?) -> UnsafePointer<CChar>?
            if let sym = dlsym(handle, "jbroot") ?? dlsym(handle, "jbroot_alloc") {
                let fn = unsafeBitCast(sym, to: JbRootFn.self)
                if let cStr = fn("/") {
                    let path = String(cString: cStr)
                    if !path.isEmpty && path != "/" {
                        return path.hasSuffix("/") ? String(path.dropLast()) : path
                    }
                }
            }
        }

        // 候选 1：RootHide 官方核心路径 `/var/containers/Bundle/Application/.jbroot-<16位HEX>`
        // 对标 roothide/Bootstrap/utils.m -> find_jbroot()
        let jbRootParentPaths = [
            "/var/containers/Bundle/Application",
            "/private/var/containers/Bundle/Application",
            "/var/mobile/Containers/Shared/AppGroup"
        ]
        for parent in jbRootParentPaths {
            // 使用 POSIX opendir/readdir 底层扫描，防止 NSFileManager 忽略以 "." 开头的隐藏目录 (.jbroot-*)
            if let dir = opendir(parent) {
                defer { closedir(dir) }
                while let entry = readdir(dir) {
                    let name = withUnsafePointer(to: &entry.pointee.d_name) {
                        $0.withMemoryRebound(to: CChar.self, capacity: Int(entry.pointee.d_namlen) + 1) {
                            String(cString: $0)
                        }
                    }
                    if name.hasPrefix(".jbroot-") || name == ".jbroot" {
                        let full = "\(parent)/\(name)"
                        if access("\(full)/usr/bin", F_OK) == 0 || access("\(full)/bin", F_OK) == 0 || FileManager.default.fileExists(atPath: full) {
                            return full
                        }
                    }
                }
            }
            // 同时遍历 App 容器内可能由 dpkg/roothide 生成的 `.jbroot` 符号链接
            if let items = try? FileManager.default.contentsOfDirectory(atPath: parent) {
                for item in items {
                    if item.hasPrefix(".jbroot-") {
                        return "\(parent)/\(item)"
                    }
                    let dotJbroot = "\(parent)/\(item)/.jbroot"
                    if access(dotJbroot, F_OK) == 0 {
                        if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: dotJbroot), !dest.isEmpty {
                            return dest.hasPrefix("/") ? dest : "\(parent)/\(item)/\(dest)"
                        }
                        return dotJbroot
                    }
                }
            }
        }

        // 候选 2：检查当前 App Bundle 自身目录下的 `.jbroot` 符号链接（RootHide 注入 App 时会自动生成）
        let bundleJbroot = (Bundle.main.bundlePath as NSString).appendingPathComponent(".jbroot")
        if access(bundleJbroot, F_OK) == 0 {
            if let dest = try? FileManager.default.destinationOfSymbolicLink(atPath: bundleJbroot), !dest.isEmpty {
                return dest
            }
            return bundleJbroot
        }

        // 候选 3：探测环境变量与动态库注入（RootHide / ElleKit 注入的动态库路径直接包含 .jbroot-XXXX）
        if let insertLibs = ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"], !insertLibs.isEmpty {
            let parts = insertLibs.components(separatedBy: ":")
            for lib in parts {
                if let range = lib.range(of: ".jbroot-[0-9A-Fa-f]{16}", options: .regularExpression) {
                    let prefixEnd = lib.index(range.upperBound, offsetBy: 0)
                    return String(lib[..<prefixEnd])
                }
                if lib.contains("/jb") || lib.contains("procursus") {
                    let url = URL(fileURLWithPath: lib)
                    return url.deletingLastPathComponent().deletingLastPathComponent().path
                }
            }
        }
        // 遍历当前进程已加载的所有 dyld image 路径，查找是否包含 `.jbroot-`
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let cName = _dyld_get_image_name(i) {
                let imgPath = String(cString: cName)
                if let range = imgPath.range(of: ".jbroot-[0-9A-Fa-f]{16}", options: .regularExpression) {
                    return String(imgPath[..<range.upperBound])
                }
            }
        }

        // 候选 4：深度遍历 /private/preboot/ 下的动态随机目录 (Dopamine / RootHide 辅助区)
        let prebootPath = "/private/preboot"
        if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: prebootPath) {
            for dir in subdirs {
                let candidateBase = "\(prebootPath)/\(dir)"
                if let innerDirs = try? FileManager.default.contentsOfDirectory(atPath: candidateBase) {
                    for inner in innerDirs {
                        let fullCandidate = "\(candidateBase)/\(inner)"
                        if inner.hasPrefix(".jbroot-") || inner.hasPrefix("jb-") || inner.hasPrefix("dopamine-") {
                            if access("\(fullCandidate)/procursus", F_OK) == 0 {
                                return "\(fullCandidate)/procursus"
                            }
                            return fullCandidate
                        }
                        let tests = [
                            "\(fullCandidate)/procursus/bin/node22",
                            "\(fullCandidate)/procursus/bin/node",
                            "\(fullCandidate)/procursus/bin/sh",
                            "\(fullCandidate)/procursus/bin/bash",
                            "\(fullCandidate)/procursus/usr/bin",
                            "\(fullCandidate)/bin/node22",
                            "\(fullCandidate)/bin/node",
                            "\(fullCandidate)/bin/sh",
                            "\(fullCandidate)/bin/bash",
                            "\(fullCandidate)/usr/bin"
                        ]
                        for t in tests {
                            if FileManager.default.fileExists(atPath: t) || access(t, F_OK) == 0 {
                                if FileManager.default.fileExists(atPath: "\(fullCandidate)/procursus") {
                                    return "\(fullCandidate)/procursus"
                                }
                                return fullCandidate
                            }
                        }
                    }
                }
            }
        }

        // 候选 5：标准 Rootless 符号链接与环境变量
        if let envJb = ProcessInfo.processInfo.environment["JB_ROOT"], FileManager.default.fileExists(atPath: envJb) {
            return envJb
        }
        let roothideSymlinks = [
            "/var/jb",
            "/private/var/jb",
            "/var/run/jbroot",
            "/var/mobile/Library/jbroot"
        ]
        for sym in roothideSymlinks {
            if FileManager.default.fileExists(atPath: sym) || access(sym, F_OK) == 0 {
                return sym
            }
        }

        return nil
    }

    /// 在动态 jb 根目录及系统 PATH 中检测二进制是否存在
    private static func checkBinaryExists(name: String, underJb jbRoot: String) -> Bool {
        let candidates = [
            "\(jbRoot)/bin/\(name)",
            "\(jbRoot)/usr/bin/\(name)",
            "\(jbRoot)/usr/local/bin/\(name)",
            "/var/jb/bin/\(name)",
            "/var/jb/usr/bin/\(name)",
            "/bin/\(name)",
            "/usr/bin/\(name)"
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) || access(path, F_OK) == 0 {
                return true
            }
        }
        return false
    }

    private static func terminateWithAlert(title: String, message: String, window: UIWindow?) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            let messageAttributedString = NSAttributedString(
                string: message,
                attributes: [
                    .paragraphStyle: paragraphStyle,
                    .font: UIFont.systemFont(ofSize: 13)
                ]
            )
            alert.setValue(messageAttributedString, forKey: "attributedMessage")

            alert.addAction(UIAlertAction(title: "确定并退出", style: .destructive) { _ in
                exit(0)
            })

            let rootVC = window?.rootViewController ?? UIViewController()
            if window?.rootViewController == nil {
                window?.rootViewController = rootVC
                window?.makeKeyAndVisible()
            }
            rootVC.present(alert, animated: true, completion: nil)
        }
    }
}