import SwiftUI
import WebKit

/// 将 UIKit WKWebView 桥接到 SwiftUI，持久隐藏，仅用于后台 JS 注入
struct WebViewBridge: UIViewRepresentable {

    /// 递增此值来触发 WebView 加载（对齐 Android 的 webView.loadUrl()）
    @Binding var loadTrigger: Int

    let urlString: String
    let username: String
    let password: String
    let onLog: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLog: onLog)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isHidden = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 更新注入凭据
        context.coordinator.credentials = (username, password)

        // loadTrigger 变化 → 加载页面
        if context.coordinator.lastLoadTrigger != loadTrigger {
            context.coordinator.lastLoadTrigger = loadTrigger
            if let url = URL(string: urlString) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {

        var credentials: (username: String, password: String) = ("", "")
        var lastLoadTrigger: Int = -1
        private let onLog: (String) -> Void
        private var hasInjectedForCurrentLoad = false

        init(onLog: @escaping (String) -> Void) {
            self.onLog = onLog
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url?.absoluteString,
                  url.contains("p.njupt.edu.cn"),
                  !hasInjectedForCurrentLoad else { return }

            hasInjectedForCurrentLoad = true

            let user = credentials.username
            let pass = credentials.password

            // 与 Android 版完全一致的延迟 + JS 注入逻辑
            let jsCode = """
            (function() {
                setTimeout(function() {
                    var u = document.querySelector('input[placeholder*="学号"]');
                    var p = document.querySelector('input[placeholder*="密码"]');
                    var b = document.querySelector('input[value*="登录"]');
                    if (u && p && b) {
                        u.value = '\(user)';
                        p.value = '\(pass)';
                        setTimeout(function() { b.click(); }, 300);
                    }
                }, 500);
            })();
            """

            webView.evaluateJavaScript(jsCode) { _, error in
                if let error = error {
                    self.onLog("JS 注入失败: \(error.localizedDescription)")
                } else {
                    self.onLog("认证指令已发送")
                }
            }
        }
    }
}
