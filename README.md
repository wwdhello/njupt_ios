# 校园网快捷认证 - iOS 版

基于 Android 版 `njupt_v2` 完整移植的 iOS 版本。纯 SwiftUI 实现，零第三方依赖。

---

## 🖥️ Windows 开发 + GitHub 云编译 工作流

```
  Windows (VS Code)         GitHub Actions (macOS)           iPhone
  ┌──────────────┐         ┌─────────────────────┐         ┌────────┐
  │ 编写 Swift 代码 │  push   │ 1. XcodeGen 生成项目  │  download │ 侧载运行 │
  │ git commit    │ ──────▶ │ 2. xcodebuild 编译   │ ───────▶ │  AltStore │
  │ git push      │         │ 3. 打包 .ipa        │         └────────┘
  └──────────────┘         └─────────────────────┘
```

## 📁 项目结构

```
njupt_ios/
├── .github/workflows/build.yml   # CI/CD 云编译流水线
├── project.yml                    # XcodeGen 项目描述（→ 生成 .xcodeproj）
├── njupt_ios/
│   ├── njupt_iosApp.swift        # App 入口
│   ├── ContentView.swift         # 主界面（SwiftUI）
│   ├── TokenProcessor.swift      # AES-GCM 解密 + Token 解析
│   ├── WebViewBridge.swift       # WKWebView 桥接（JS 注入自动登录）
│   └── Info.plist                # App 配置（含 HTTP 白名单）
├── .gitignore
└── README.md
```

## 🚀 快速开始

### 第 1 步：推送到 GitHub

```bash
cd D:\njupt_ios
git init
git add .
git commit -m "iOS 校园网快捷认证 - 初始版本"
git remote add origin https://github.com/你的用户名/njupt_ios.git
git push -u origin main
```

### 第 2 步：触发云编译

推送后 **GitHub Actions 自动开始编译**。也可以手动触发：

1. 打开 GitHub 仓库 → **Actions** 标签页
2. 选择 **Build iOS App** → **Run workflow**

### 第 3 步：下载编译产物

编译完成后（约 3-5 分钟）：

1. GitHub Actions → 完成的 workflow → **Artifacts**
2. 下载 `njupt_ios_unsigned.zip`

---

## 📲 安装到 iPhone

编译产出的 `.app` 文件需要签名才能安装到 iPhone。你有以下几种选择：

### 方案 A：AltStore / SideStore（推荐，免费）

1. 在 iPhone 上安装 [AltStore](https://altstore.io) 或 [SideStore](https://sidestore.io)
2. 将 `.ipa` 文件传到 iPhone（AirDrop / 网盘 / 本地服务器）
3. 在 AltStore/SideStore 中打开 → 用你的 Apple ID 重签名 → 安装
4. ⚠️ 免费 Apple ID 签名的 App **7 天过期**，到期需重签

### 方案 B：配置 CI 自动签名（需 Apple Developer 账号）

在 GitHub 仓库的 **Settings → Secrets and variables → Actions** 添加以下 Secrets：

| Secret 名称 | 说明 |
|---|---|
| `P12_CERTIFICATE_BASE64` | 开发证书 .p12 的 Base64 编码 |
| `P12_PASSWORD` | 证书密码 |
| `PROVISIONING_PROFILE_BASE64` | Provisioning Profile 的 Base64 |
| `DEVELOPMENT_TEAM` | 你的 Team ID（Apple Developer 后台可查） |
| `PROVISIONING_PROFILE_NAME` | Provisioning Profile 名称 |

然后在 Actions 页面手动触发时勾选 **启用签名**。

### 方案 C：找一台 Mac 本地编译

如果你能短期访问一台 Mac（朋友、学校机房、云租用）：

```bash
# 1. 克隆项目
git clone https://github.com/你的用户名/njupt_ios.git
cd njupt_ios

# 2. 安装 XcodeGen 并生成项目
brew install xcodegen
xcodegen generate

# 3. 打开项目，选择你的 Team，直接 Run 到 iPhone
open njupt_ios.xcodeproj
```

---

## 🔧 技术对照（Android → iOS）

| 功能 | Android | iOS |
|---|---|---|
| 解密算法 | `javax.crypto.Cipher` AES-GCM | `CryptoKit` `AES.GCM.SealedBox` |
| Base64 | `android.util.Base64` URL_SAFE | 自定义 Base64 URL-safe 解码 |
| WebView | `android.webkit.WebView` | `WKWebView` (via `UIViewRepresentable`) |
| JS 注入 | `evaluateJavascript()` | `evaluateJavaScript()` |
| 持久存储 | `SharedPreferences` | `@AppStorage` (`UserDefaults`) |
| UI 框架 | XML + Material 3 | SwiftUI |
| HTTP 明文 | 默认允许 | 需 `NSAppTransportSecurity` 白名单 |

---

## 📝 逻辑说明

### Token 解密流程

```
用户粘贴 Token (URL Safe Base64)
  → Base64 解码
  → 提取 Nonce (前12字节)
  → 提取 密文+Tag (剩余字节)
  → AES-GCM 解密 (32字节 XOR 0x8A 密钥)
  → UTF-8 解码
  → 按 | 分割: username|password|运营商|expiry
  → 校验过期时间
  → 拼接运营商后缀 (@telecom/@cmcc/@unicom)
  → 注入到隐藏 WebView
```

### WebView 自动登录

```
加载 http://p.njupt.edu.cn
  → 等待页面 JS 初始化 (500ms)
  → 查找 input[placeholder*="学号"] 填入用户名
  → 查找 input[placeholder*="密码"] 填入密码
  → 等待表单就绪 (300ms)
  → 点击 input[value*="登录"] 提交登录
```

---

## 🔒 安全提醒

- 硬编码密钥已通过 XOR 混淆存储，与 Android 版完全一致
- 如需进一步增强安全性，考虑使用 iOS Keychain 替代 UserDefaults 存储 Token
- App Transport Security 已配置为允许 HTTP（校园网认证页面无 HTTPS）

---

## 📄 License

与原始 Android 项目保持一致。仅供 NJUPT 校园网认证使用。
