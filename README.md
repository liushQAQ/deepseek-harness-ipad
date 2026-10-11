# iPadOS DeepSeek Harness (Pad Harness) 自研移植完整技术白皮书 (V1.0 正式版)

- **适配设备**：M2 iPad Pro 11寸 256G（8G 统一内存）
- **越狱环境**：Rootless 越狱（Dopamine / RootHide 兼容）
- **核心定位**：**Pad Harness**（iPadOS 独立闭环生产力工作站与服务端中枢）

---

## 核心架构原则与拓扑定位

### 1. 绝对边界与定位清晰
* **iPad Harness（本项目主体）**：
  * **唯一服务端与内核宿主**：iPad 本机运行完整精简 DSH Host（Node 运行时、Agent 调度引擎、8 大自研轻量插件矩阵、状态机与会话管理）。
  * **独立生产终端**：iPad 本机即是独立生产工具与服务节点，全程直接向外调用 DeepSeek 云端 API，**完全不依赖任何电脑**。
  * **局域网服务节点**：iPad 本机监听 `0.0.0.0:3080`。iPad 本机内置现代化生产力控制台直接使用；同时开放局域网访问，供外部客户端（如 iPhone App）作为纯前端随身连接。
* **iPhone App（外部配套客户端）**：
  * **纯展示与交互客户端**：iPhone 仅作为轻量前端，**绝不运行 DSH 内核**。iPhone 连接 iPad 节点的 `http://<iPad_IP>:3080` 进行移动端交互，所有计算、插件执行与调度全部在 iPad 硬件上物理完成。

```text
+-------------------------------------------------------------------------+
|                   M2 iPad Pro (DSH 核心计算与生产服务节点)                 |
|                                                                         |
| +---------------------------------------------------------------------+ |
| | [iPad 本机前端] Pad Harness App                                     | |
| | +- 独立 BundleID: com.deepseek.harness.pad                          | |
| | +- 专属 iPad 生产力暗金图标 (绝不混淆或覆盖 iPhone 客户端)          | |
| | +- 硬件与动态越狱门禁: 仅限 iPad，动态兼容 Dopamine / RootHide      | |
| | +- 本机内循环交互: 直接访问 http://127.0.0.1:3080                   | |
| +---------------------------------------------------------------------+ |
|                                  |                                      |
| +--------------------------------v------------------------------------+ |
| | [DSH 本机服务端] Node.js 运行时 (监听 0.0.0.0:3080)                  | |
| | +- 系统级守护: launchd (com.dsh.server.plist) 锁屏无限保活          | |
| | +- 运存死锁: --max-old-space-size=1024 + 闲置强制主动 GC            | |
| | +- 核心调度: 完整保留 Agent 状态机、工具分发、会话冷热隔离          | |
| | +- 自研轻量插件矩阵: POSIX真终端、内存监控守护、会话归档等          | |
| +---------------------------------------------------------------------+ |
|                                  |                                      |
| +--------------------------------v------------------------------------+ |
| | [Rootless 底层执行环境] (/var/jb 或 RootHide 动态挂载点)            | |
| | +- 真实终端工具链: sh, bash, python3, git, curl 物理执行            | |
| | +- 闪存分层: 14天活跃热存储，超期自动归档至 NAS/WebDAV              | |
| +---------------------------------------------------------------------+ |
+----------------------------------+--------------------------------------+
                                   |
       +---------------------------+---------------------------+
       | 局域网服务输出 (0.0.0.0:3080)                         |
       v                                                       v
+------------------------------+      +---------------------------------+
| [外部客户端] iPhone App      |      | [云端模型层] DeepSeek 官方 API  |
| +- 纯前端展示与输入          |      | +- deepseek-chat / reasoner     |
| +- 不运行任何 DSH 内核       |      | +- iPad 本机调度器直接云端直连  |
| +- 仅作为随身轻量遥控界面    |      +---------------------------------+
+------------------------------+
```

---

## 一、App 安装前置条件文档（部署规范）

### 1.1 设备硬性条件
* **设备**：M2 iPad Pro 11寸
* **内存**：8GB 统一内存
* **存储**：256GB 闪存
* **系统版本**：iPadOS 16.0 ~ 16.3.1
* **越狱状态**：Rootless 越狱（Dopamine / RootHide）
* **运行底线**：禁止非越狱环境运行服务端内核；依托 TrollStore / Rootless 越狱提供后台长驻与进程派生支持。

### 1.2 越狱环境必须具备能力
1. **后台无限制保活权限**：支持 `keepBackground` 与 `ProcessAssertion`，锁屏与后台切换不被杀。
2. **Node 进程常驻**：系统级 `launchd` 守护进程或 App 内嵌后台任务保证 Node 监听常驻。
3. **本地回环与局域网监听**：允许绑定 `0.0.0.0:3080`，支持本机 `127.0.0.1` 闭环以及外部局域网访问。
4. **沙盒读写豁免**：允许持久化保存会话历史至 Documents 与越狱路径。
5. **本地网络权限描述内置**：已内置 `NSLocalNetworkUsageDescription` 与 ATS 豁免。

### 1.3 部署最终效果
* **开箱即用**：安装 `PadHarness.tipa` 后打开即启动，内置 WebUI 工作台立即就绪。
* **零电脑依赖**：无需数据线连接电脑，无需终端命令配置，iPad 本机即是独立生产力中心。

---

## 二、iPad Harness 整体开发架构文档

### 2.1 核心设计原则
1. **原则 1：业务能力对齐 Windows 原版，功能零降级**
   * 保留完整 Agent 状态机调度、多轮对话上下文管理、提示词拼装与分发。
2. **原则 2：内存绝对控死，严防 Jetsam 杀进程**
   * Node 堆内存硬锁定：`--max-old-space-size=1024`。
   * 闲置强制垃圾回收：每 30 秒自动执行 `global.gc()`。
   * 插件瞬态生命周期：按需加载，执行完毕立即 unmount 销毁，杜绝常驻内存泄露。
   * 会话冷热分离：仅当前活跃会话驻留内存，历史会话读磁盘。
3. **原则 3：剔除官方重插件，换装 iPad 专属轻量插件矩阵**
   * 移除官方 Shell、重型本地代码沙盒、多媒体大模型本地解析器等高耗内存插件。
   * 由 8 大自研轻量插件 1:1 无缝补全能力。

### 2.2 存储分层方案（解决 256G 闪存焦虑）
* **热数据层（iPad 本地）**：仅保存最近 14 天活跃会话，单会话轮次按需分页。
* **冷数据层（自动归档）**：超期历史会话由 `dsh-ipad-storage-sync` 自动打包并上传至配置的 NAS / WebDAV。
* **本地擦除**：归档成功后物理擦除本地历史，保障 256G 闪存常年轻盈。

---

## 三、自研 8 大轻量化插件开发规范

所有自研插件均遵循单任务生命周期：`mount() -> execute() -> unmount()`，峰值内存严控在 15MB 以内。

| 插件标识 | 插件名称 | 对标能力 | 核心实现与防爆机制 |
| :--- | :--- | :--- | :--- |
| `dsh-ipad-posix-exec` | 真 POSIX 终端插件 | Windows cmd/PowerShell 终端执行 | 通过 `/var/jb/bin/sh` 物理执行命令，超时强制 kill，瞬态子进程回收 |
| `dsh-ipad-memory-guard` | 内存 GC 守护插件 | 桌面端资源监视器 | 监控 RSS / Heap 内存水位，闲置主动触发 GC，内存紧张时主动卸载模块 |
| `dsh-ipad-storage-sync` | 闪存分层与 NAS 归档插件 | 本地数据管理与持久化 | 14天活跃轮转，超期历史会话异步同步至 NAS/WebDAV 并清理本地 |
| `dsh-ipad-cost-meter` | Token 计量与成本统计插件 | 官方 Token 计数器 | 轻量规则化核算 DeepSeek-V3 / R1 上下文 Token 与实时账单 |
| `dsh-ipad-prompt-optimizer`| 本地结构化提示词调优插件 | 提示词调优助手 | 纯本地正则规则引擎重写高质量 Prompt，零消耗外部 Token |
| `dsh-ipad-mnemon-lite` | 轻量记忆图谱插件 | dsh-mnemon 记忆插件 | 磁盘 SQLite / JSON 存储与轻量索引，拒绝全文向量常驻内存 |
| `dsh-ipad-modlens-lite` | 轻量多模态转接插件 | modlens 截图与图像解析 | 分块流式读取与下采样压缩，严防大图片爆内存 |
| `dsh-ipad-market` | 内置轻量插件市场 | 插件热插拔与扩展 | 直连 GitHub 市场清单，支持轻量插件动态拉取与状态切换 |

---

## 四、双端身份隔离与工程结构

为确保 iPad 端服务端与 iPhone 客户端互不覆盖、互不冲突，已建立彻底的工程与身份隔离：

* **应用显示名**：`Pad Harness`（专属暗金徽章，区分手机版）
* **专属 Bundle Identifier**：`com.deepseek.harness.pad`
* **设备门禁**：`UIDeviceFamily = 2`（iPad 专属）
* **默认访问端点**：`http://127.0.0.1:3080/`（iPad 本机闭环）与 `0.0.0.0:3080`（局域网开放）

```text
deepseek-harness-ipad/
├── PadHarness/                # Swift 宿主工程 (iPad 专属)
│   ├── AppDelegate.swift      # 内嵌 DSHEmbeddedServer (0.0.0.0:3080)
│   ├── ViewController.swift   # WKWebView 核心交互工作台
│   ├── SettingsViewController.swift # 局域网/外网节点快速切换
│   ├── DSHConnectionManager.swift   # 高可用长连接状态机
│   └── Info.plist             # iPad 专属配置与后台权限声明
├── core/                      # DSH 精简核心内核
│   ├── index.js               # 服务端核心调度与路由 (0.0.0.0:3080)
│   ├── webui.html             # 内置现代化响应式生产力工作台
│   └── package.json           # 零冗余依赖清单
├── plugins/                   # 8 大自研轻量插件矩阵
│   ├── dsh-ipad-posix-exec/
│   ├── dsh-ipad-memory-guard/
│   ├── dsh-ipad-storage-sync/
│   ├── dsh-ipad-cost-meter/
│   ├── dsh-ipad-prompt-optimizer/
│   ├── dsh-ipad-mnemon-lite/
│   ├── dsh-ipad-modlens-lite/
│   └── dsh-ipad-market/
├── daemon/                    # launchd 系统级锁屏常驻守护
│   └── com.dsh.server.plist
├── server/                    # 服务端一键部署与管理脚本
│   └── install.sh
├── market-index.json          # 插件市场元数据索引
└── .github/workflows/         # CI/CD 自动化流水线
    └── build-ipa.yml          # GitHub Actions 自动编译 unsigned .tipa/.ipa
```

---

## 五、依赖管理、更新机制与运维规范

### 5.1 依赖管理策略
* **运行时依赖锁死**：Node 核心与插件依赖全部使用 Node 内置模块（`http`, `fs`, `path`, `child_process`, `crypto`），外部依赖为 0，杜绝 `node_modules` 膨胀。
* **Web 静态资源固化**：WebUI 工作台全量内嵌本地，零 CDN 依赖，断网也能秒开。

### 5.2 故障与 Bug 修复分级 (SLA)
* **P0（致命）**：进程 OOM、Jetsam 强杀、会话数据损坏。
  * 响应：立即通过 `dsh-ipad-memory-guard` 下调堆上限，增加闲置 GC 频次。
* **P1（严重缺陷）**：插件返回结构与 Windows 不对齐、云端 API 调用失败、NAS 归档中断。
  * 响应：以热插拔形式更新单个插件，不影响核心调度。
* **P2（常规体验）**：UI 适配与提示词优化规则扩充。

---

## 六、构建与交付说明

本项目已配置完整的 GitHub Actions CI/CD 流水线，每次代码提交均会自动编译并生成以下安装包：

1. **`PadHarness-personal.tipa`**：个人完整版（包含内网穿透与全部预置配置，TrollStore 一键安装）。
2. **`PadHarness-public.tipa`**：公开发行版（纯净版，剔除个人网络配置与密钥）。

两份产物均直接打包了 `dsh-engine` 核心与 8 大轻量插件，安装后打开即用，iPad 即刻化身独立闭环的生产力旗舰中枢！
