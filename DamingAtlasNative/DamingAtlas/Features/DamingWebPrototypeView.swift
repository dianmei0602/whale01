import SwiftUI
import WebKit

struct DamingWebPrototypeView: View {
    @State private var loadError: String?

    var body: some View {
        ZStack {
            DamingTheme.ground.ignoresSafeArea()

            PrototypeWebContainer(errorMessage: $loadError)

            if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("原型页面未能载入")
                        .font(.headline)
                    Text(loadError)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .background(DamingTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(24)
            }
        }
    }
}

private struct PrototypeWebContainer: UIViewRepresentable {
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(errorMessage: $errorMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(DamingTheme.ground)
        webView.scrollView.backgroundColor = UIColor(DamingTheme.ground)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false

        guard let url = Bundle.main.url(
            forResource: "index",
            withExtension: "html",
            subdirectory: "DamingAtlasWeb"
        ) else {
            errorMessage = "应用内缺少 DamingAtlasWeb/index.html"
            return webView
        }

        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var errorMessage: String?

        init(errorMessage: Binding<String?>) {
            _errorMessage = errorMessage
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            errorMessage = nil
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            errorMessage = error.localizedDescription
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            errorMessage = error.localizedDescription
        }
    }
}
