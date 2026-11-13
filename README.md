# Battery Drain 使用说明

Battery Drain 是一个通过 CPU 运算与 GPU 粒子动画增加设备负载的耗电工具。项目包含 iPhone 原生应用和网页版两个独立版本。

> 运行会增加耗电和发热，请保持设备散热，避免无人看管或长时间持续运行。设备明显发热时应手动停止。原生版使用系统热状态进行保护，但这不代表可以避免所有过热情况；网页版没有自动温度保护。

## 版本区别

| 功能 | iPhone 原生版 | 网页版 |
| --- | --- | --- |
| 技术 | SwiftUI + Metal | HTML、CSS、JavaScript + WebGL |
| 电量显示 | 支持 | 未实现 |
| 电量目标停止 | 支持，5%～50%，每次调整 5% | 未实现 |
| CPU 运算 | 固定 3 个工作任务 | 默认 3 个 Worker，CPU+ 模式为 5 个 |
| GPU 动画 | 24,000 个三角形粒子 | 26,000 个点粒子 |
| 帧率 | 请求 120 FPS，界面显示的是目标值 | 显示运行中的实际统计 FPS |
| 温度保护 | 系统热状态 serious 时降低 CPU 运算频率，critical 时停止 | 未实现 |
| 保持屏幕常亮 | 运行时禁用自动锁屏 | 尝试申请屏幕唤醒锁，取决于浏览器支持及权限 |
| 离开应用或页面 | 离开活跃状态时停止 | 页面隐藏时停止 |

实际耗电速度和帧率取决于设备性能、屏幕刷新率、系统调度和温度，不能保证达到 120 FPS 或在固定时间内消耗指定电量。

## 目录结构

```text
IOS费电软件/
├── README.md
├── BatteryDrain.xcodeproj/       # Xcode 工程
├── BatteryDrain/
│   ├── BatteryDrainApp.swift     # 应用入口
│   ├── ContentView.swift         # 界面与前后台状态处理
│   ├── DrainController.swift     # CPU 运算、电量和温度监控
│   ├── MetalParticleView.swift   # Metal 粒子渲染
│   └── Assets.xcassets/          # 资源目录
└── web/
    ├── index.html               # 网页入口
    ├── styles.css               # 页面样式
    ├── app.js                   # WebGL、Worker 与运行控制
    └── manifest.webmanifest     # 网页应用显示配置
```

## iPhone 原生版

### 准备环境

- 一台可以运行 Xcode 的 Mac。
- 支持本项目 Swift 语法的 Xcode / Swift 工具链。源码使用了 `nonisolated(unsafe)`，旧版编译器可能不支持。
- iOS 17.0 或以上的 iPhone，或对应版本的 iOS 模拟器。
- 安装到真实 iPhone 时，需要在 Xcode 中配置 Apple 开发签名。

Windows 可以查看和编辑源码，但不能直接用 Xcode 构建此 iOS 工程。模拟器适合查看界面，不能代表真实 iPhone 的耗电表现。

### 编译和安装

1. 将整个项目目录复制到 Mac。
2. 用 Xcode 打开 `BatteryDrain.xcodeproj`。
3. 选择 `BatteryDrain` Target，进入 **Signing & Capabilities**。
4. 选择你的开发团队（Team）。工程目前未填写开发团队；如遇 Bundle Identifier 冲突，将 `local.personal.BatteryDrain` 改成自己的唯一标识。
5. 连接 iPhone，在 Xcode 中选择该设备作为运行目标，并按设备提示完成信任或开发者模式设置。
6. 点击 Xcode 的 **Run** 按钮，编译并安装应用。

### 使用步骤

1. 打开应用，查看当前电量和状态。
2. 用 **Target** 滑块选择停止电量，范围为 5%～50%，默认 10%。运行中不能调整。
3. 点击 **Start** 开始 CPU 运算和 GPU 动画。
4. 保持应用在前台；可随时点击 **Stop** 停止。
5. 达到停止电量或系统热状态达到 critical 时，程序会自动停止。

如果当前电量已经小于或等于设定目标，应用不会启动；系统热状态为 critical 时也不会启动。电量与热状态在运行中约每 2 秒检查一次，停止时的电量可能略低于设定值。

### 界面说明

| 字段 | 含义 |
| --- | --- |
| Battery | 当前电量；无法获取时显示 `--` |
| Target | 自动停止的电量阈值 |
| FPS | 请求的目标帧率 120，并非实时测量结果 |
| CPU | 当前 CPU 工作任务数量；运行时为 3，停止后为 0 |
| Heat：OK | 系统热状态正常 |
| Heat：Warm | 系统热状态 fair |
| Heat：Limit | 系统热状态 serious，CPU 运算间加入休眠 |
| Heat：Stop | 系统热状态 critical，停止运行或禁止启动 |

常见状态文字：

- `Ready`：准备就绪。
- `Running GPU particles + CPU work`：正在运行。
- `Running, CPU throttled by heat`：热状态为 serious，正在降低 CPU 运算频率。
- `Already below target`：当前电量已达到或低于目标。
- `Target reached`：达到停止电量。
- `Too hot to start` / `Stopped: too hot`：系统热状态过高，禁止启动或已停止。
- `Paused`：应用离开活跃状态，负载已停止；返回后需手动重新开始。

## 网页版

网页版是独立的静态网页，不需要构建前端依赖，也不需要安装原生应用。

### 在 Windows 本机打开

如果电脑已安装 Python，在 PowerShell 中运行：

```powershell
Set-Location -LiteralPath 'D:\CodeX项目\IOS费电软件\web'
python -m http.server 8000 --bind 127.0.0.1
```

然后在这台电脑的浏览器中访问：

```text
http://127.0.0.1:8000
```

保持终端运行。结束服务时，在终端按 `Ctrl+C`。

本机打开会增加当前电脑的负载，不会消耗另一台 iPhone 的电量。要在 iPhone 上使用，必须在 iPhone 的浏览器里打开页面。

### 在同一局域网的 iPhone 上打开

1. 将电脑和 iPhone 连接到同一局域网。
2. 在电脑终端进入 `web` 目录并启动服务：

   ```powershell
   Set-Location -LiteralPath 'D:\CodeX项目\IOS费电软件\web'
   python -m http.server 8000 --bind 0.0.0.0
   ```

3. 在电脑运行 `ipconfig`，查找当前网络适配器的 IPv4 地址。
4. 在 iPhone 的 Safari 中访问 `http://电脑IPv4地址:8000`，例如 `http://192.168.1.100:8000`。示例地址需要替换成电脑的实际地址。
5. 如果无法连接，检查两台设备是否在同一网络、路由器是否隔离客户端，以及 Windows 防火墙是否允许该服务在当前专用网络中接收连接。

此服务会让局域网中的其他设备访问 `web` 目录，使用完后应按 `Ctrl+C` 关闭。它适合临时预览；需要长期访问时，可将 `web` 目录部署到支持 HTTPS 的静态网站托管服务。

普通局域网 HTTP 页面可能无法使用屏幕唤醒锁。需要验证自动常亮功能时，应使用 HTTPS，并确认浏览器支持该 API。

### 使用步骤

1. 打开页面后，点击 **Start**。
2. 页面开始粒子渲染和 CPU 运算，并显示累计运行时间与 FPS。
3. 点击 **CPU+** 切换加强模式：CPU Worker 从 3 个增加至 5 个，且每轮计算量增加。再次点击恢复默认模式。
4. 点击 **Stop** 停止。再次开始会继续累计运行时间；刷新页面会重置。
5. 切换到其他页面、应用或锁屏导致页面隐藏时，程序会停止。返回页面后需要手动点击 **Start**。

### 界面说明

| 字段 | 含义 |
| --- | --- |
| Runtime | 累计运行时间 |
| FPS | 运行时统计的帧率；未运行时显示 `120 target`，不代表实际已达到 120 FPS |
| CPU | 当前选择的 Worker 数量；停止时仍会显示所选模式的数量，并非后台仍在运行 |
| Wake：idle | 未持有屏幕唤醒锁 |
| Wake：on | 已申请到屏幕唤醒锁 |
| Wake：manual | 浏览器不支持、申请失败或运行中唤醒锁被释放，需要手动保持屏幕亮起 |

如果自动常亮不可用，可在 iPhone 的“设置 → 显示与亮度 → 自动锁定”中临时调整锁屏时间（如果设备允许），使用后恢复原设置。

### 添加到主屏幕

可以尝试在 Safari 的分享菜单中选择“添加到主屏幕”。项目包含网页应用显示配置，但未实现 Service Worker 离线缓存，不能保证离线打开；当前也未配置应用图标。

## 常见问题

### 为什么切到后台后不继续耗电？

两个版本都主动在离开前台时停止负载。它们目前不是后台运行工具。

### 为什么网页版不能设置剩余电量自动停止？

当前网页版没有实现电量读取和目标电量控制。该功能只在原生版中提供。

### 为什么显示 WebGL unavailable？

当前浏览器未能创建 WebGL 上下文，程序会禁用开始按钮。检查浏览器的 WebGL 支持及图形加速设置，或换用支持 WebGL 的浏览器。

### 点击 Start 后没有动画怎么办？

检查浏览器开发者工具中的错误信息。当前网页的着色器编译或链接失败会抛出错误，没有完整的页面错误提示；出现问题时可先刷新并换浏览器验证。

### 为什么达不到 120 FPS？

原生版只请求目标帧率；网页版通过 `requestAnimationFrame` 绘制。设备刷新率、系统限制、温度和负载都会影响实际帧率。

### 可以直接在 Windows 上生成 iPhone 安装包吗？

本项目没有配置 Windows 构建或云端打包流程。原生版需要在 Mac 上使用兼容的 Xcode 编译，并配置相应签名。

## 当前项目状态

- 已有原生版及网页版源码。
- 未附带 README 以外的运行文档、自动化测试或持续集成配置。
- 原生版开发团队为空，需要自行设置签名。
- 未提供可直接安装的 IPA 文件。
- 本说明根据当前源码编写，不代表已完成 Xcode 编译、真机耗电测试或各浏览器兼容性验证。
