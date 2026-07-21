import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    @ObservedObject var manager: YouTubePlayerManager

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "playerReady")
        contentController.add(context.coordinator, name: "titleUpdate")
        contentController.add(context.coordinator, name: "stateChange")
        contentController.add(context.coordinator, name: "playerError")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        manager.webView = webView
        webView.loadHTMLString(manager.playerHTML, baseURL: URL(string: "https://www.youtube.com"))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Updates handled via manager's JS calls
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let manager: YouTubePlayerManager

        init(manager: YouTubePlayerManager) {
            self.manager = manager
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? String else { return }
            switch message.name {
            case "titleUpdate":
                manager.handleTitleUpdate(body)
            case "stateChange":
                manager.handleStateChange(body)
            case "playerReady":
                break
            case "playerError":
                manager.handlePlayerError(body)
            default:
                break
            }
        }
    }
}
