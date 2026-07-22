import SwiftUI

struct ContentView: View {

    // MARK: - 状态

    @AppStorage("token") private var savedToken: String = ""
    @State private var token: String = ""
    @State private var logMessages: [String] = []

    // WebView 相关 —— 持久隐藏，通过 loadTrigger 触发加载
    @State private var loadTrigger: Int = 0
    @State private var webUsername: String = ""
    @State private var webPassword: String = ""

    // MARK: - UI

    var body: some View {
        NavigationStack {
            ZStack {
                // 主界面（滚动区域）
                ScrollView {
                    VStack(spacing: 20) {
                        authCard
                        logCard
                    }
                    .padding(24)
                }
                .background(Color(.systemGroupedBackground))

                // 持久隐藏的 WebView（对齐 Android 的 android:visibility="invisible"）
                WebViewBridge(
                    loadTrigger: $loadTrigger,
                    urlString: "http://p.njupt.edu.cn",
                    username: webUsername,
                    password: webPassword
                ) { msg in
                    log(msg)
                }
                .frame(width: 0, height: 0)   // 完全隐藏
                .allowsHitTesting(false)       // 不拦截触摸事件
            }
            .navigationTitle("校园网快捷认证")
            .toolbarTitleDisplayMode(.inline)
            .onAppear {
                if token.isEmpty && !savedToken.isEmpty {
                    token = savedToken
                    log("已加载历史 Token")
                }
            }
        }
    }

    // MARK: - 授权卡片

    private var authCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("授权配置")
                .font(.title2.bold())
                .foregroundStyle(.blue)

            // Token 输入框
            VStack(alignment: .leading, spacing: 6) {
                Text("请粘贴您的专属 Token")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $token)
                    .font(.body.monospaced())
                    .frame(minHeight: 80, maxHeight: 120)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // 一键连接按钮
            Button(action: handleConnect) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("一键连接")
                }
                .font(.title3.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.blue, in: RoundedRectangle(cornerRadius: 28))
            }
        }
        .padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
    }

    // MARK: - 日志卡片

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "terminal")
                    .font(.caption)
                Text("运行日志")
                    .font(.caption.bold())
            }
            .foregroundStyle(.secondary)

            if logMessages.isEmpty {
                Text("等待执行指令...")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logMessages, id: \.self) { msg in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .frame(width: 4, height: 4)
                                .foregroundStyle(.green)
                                .padding(.top, 7)
                            Text(msg)
                                .font(.body.monospaced().size(13))
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - 连接逻辑

    private func handleConnect() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            log("Token 不能为空")
            return
        }

        // 持久化存储
        savedToken = trimmed

        // 解密 + 校验
        guard let info = TokenProcessor.process(token: trimmed) else {
            // 解密失败的错误已在 TokenProcessor 中处理
            log("错误：无效的 Token 或解码失败")
            return
        }

        log("授权通过")

        // 设置凭据并触发 WebView 加载（对齐 Android 的 webView.loadUrl()）
        webUsername = info.username
        webPassword = info.password
        loadTrigger += 1
    }

    // MARK: - 日志帮助方法

    private func log(_ message: String) {
        logMessages.append(message)
        if logMessages.count > 5 {
            logMessages.removeFirst()
        }
    }
}

#Preview {
    ContentView()
}
