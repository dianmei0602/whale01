import SwiftUI
import WebKit

struct NewsArticleReader: View {
    let articleTitle: String
    let articleSource: String
    let link: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var state
    @StateObject private var browser = NewsBrowserModel()

    init(article: NewsArticle) {
        articleTitle = article.title
        articleSource = article.source
        link = article.link
    }

    init(title: String, source: String, link: URL) {
        articleTitle = title
        articleSource = source
        self.link = link
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                topBar

                ZStack(alignment: .top) {
                    NewsWebView(webView: browser.webView)

                    if browser.isLoading {
                        ProgressView(value: browser.progress)
                            .tint(CardPalette.accent)
                            .progressViewStyle(.linear)
                    }

                    if let error = browser.errorText {
                        VStack(spacing: 10) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.nomiScaled(size: 24, weight: .semibold))
                            Text("网页没有加载成功")
                                .font(.nomiScaled(size: 16, weight: .semibold))
                            Text(error)
                                .font(.nomiScaled(size: 11.5))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                            Button("重试") {
                                browser.reload()
                            }
                            .font(.nomiScaled(size: 13, weight: .semibold))
                            .foregroundStyle(CardPalette.accent)
                        }
                        .foregroundStyle(CardPalette.ink)
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(CardPalette.solid.opacity(0.94))
                    }
                }

                bottomBar
            }
        }
        .task {
            browser.load(link)
        }
        .preferredColorScheme(state.settings.appearance.colorScheme)
    }

    private var topBar: some View {
        HStack(spacing: 11) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(CardPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(WhalePressStyle())
            .accessibilityLabel("关闭新闻")

            VStack(alignment: .leading, spacing: 2) {
                Text(browser.pageTitle.isEmpty ? articleTitle : browser.pageTitle)
                    .font(.nomiScaled(size: 13, weight: .semibold))
                    .foregroundStyle(CardPalette.ink)
                    .lineLimit(1)

                Text(articleSource)
                    .font(.nomiScaled(size: 9.5))
                    .foregroundStyle(CardPalette.subtle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Rectangle().fill(CardPalette.chrome.opacity(0.96))
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(CardPalette.line).frame(height: 0.6)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            browserButton("chevron.left", label: "后退", enabled: browser.canGoBack) {
                browser.webView.goBack()
            }

            browserButton("chevron.right", label: "前进", enabled: browser.canGoForward) {
                browser.webView.goForward()
            }

            browserButton("arrow.clockwise", label: "刷新", enabled: true) {
                browser.reload()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background {
            Rectangle().fill(CardPalette.chrome.opacity(0.96))
        }
        .overlay(alignment: .top) {
            Rectangle().fill(CardPalette.line).frame(height: 0.6)
        }
    }

    private func browserButton(
        _ symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.nomiScaled(size: 16, weight: .medium))
                .foregroundStyle(enabled ? CardPalette.ink : CardPalette.faint)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

private struct NewsWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

@MainActor
private final class NewsBrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var pageTitle = ""
    @Published private(set) var isLoading = false
    @Published private(set) var progress = 0.0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var errorText: String?

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var currentURL: URL?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        observations.append(webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in self?.pageTitle = webView.title ?? "" }
        })
        observations.append(webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in self?.progress = webView.estimatedProgress }
        })
        observations.append(webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in self?.canGoBack = webView.canGoBack }
        })
        observations.append(webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
            Task { @MainActor in self?.canGoForward = webView.canGoForward }
        })
    }

    func load(_ url: URL) {
        currentURL = url
        errorText = nil
        isLoading = true
        webView.load(URLRequest(url: url, timeoutInterval: 18))
    }

    func reload() {
        errorText = nil
        if let currentURL, webView.url == nil {
            load(currentURL)
        } else {
            webView.reload()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        pageTitle = webView.title ?? pageTitle
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        errorText = error.localizedDescription
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        isLoading = false
        errorText = error.localizedDescription
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
