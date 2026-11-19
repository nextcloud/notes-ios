// SPDX-FileCopyrightText: 2021 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import WebKit

typealias LoadCompletion = () -> Void
typealias CheckBoxTapHandlerBlock = (PreviewCheckBoxes.CheckBox) -> Void

class PreviewWebView: WKWebView {

    let bundle: Bundle

    private lazy var baseURL: URL = {
        return self.bundle.url(forResource: "index", withExtension: "html")!
    }()

    private var loadCompletion: LoadCompletion?

    /// Called when a checkbox in the rendered note has been tapped.
    var onCheckBoxTapped: CheckBoxTapHandlerBlock?

    /// The scroll position to restore once a reloaded page has finished rendering.
    private var pendingScrollOffset: CGPoint?

    public init(markdown: String, completion: LoadCompletion? = nil) throws {

        let bundleUrl = Bundle.main.url(forResource: "Preview", withExtension: "bundle")!
        self.bundle =  Bundle(url: bundleUrl)!

        loadCompletion = completion
        
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        navigationDelegate = self

        // The page paints its own background, which follows the appearance. An opaque web view would
        // show a white flash while the first page is still loading, in dark mode most noticeably.
        isOpaque = false
        backgroundColor = .clear
        scrollView.backgroundColor = .clear
        underPageBackgroundColor = .clear

        do {
            try loadHTML(markdown)
        } catch {
            //
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Renders `markdown` again without reloading the page.
    ///
    /// Replacing the body of the living page leaves the scroll position untouched, which matters
    /// when a checkbox far down a long list is ticked. Reloading instead would throw the reader
    /// back to the top, because a freshly loaded page has no height yet and any restored offset is
    /// clamped away.
    ///
    /// The script is run by the app in its own content world, so note content still cannot execute
    /// anything: the page keeps its `script-src 'none'` policy.
    func update(markdown: String) {
        let html = MarkdownRenderer.html(from: markdown, tappableCheckBoxes: true)
        guard let literal = javaScriptLiteral(for: html) else {
            reload(markdown: markdown)
            return
        }
        evaluateJavaScript("document.body.innerHTML = \(literal);", in: nil, in: .defaultClient) { [weak self] result in
            if case .failure = result {
                // Whatever went wrong, the reader should still see the change.
                self?.reload(markdown: markdown)
            }
        }
    }

    /// Loads the page again, restoring the scroll position as far as the new layout allows.
    private func reload(markdown: String) {
        pendingScrollOffset = scrollView.contentOffset
        do {
            try loadHTML(markdown)
        } catch {
            //
        }
    }

    /// `html` as a quoted and escaped JavaScript string.
    private func javaScriptLiteral(for html: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: [html]),
              let array = String(data: data, encoding: .utf8) else {
            return nil
        }
        // JSONSerialization only encodes top level containers, so the string travels inside an
        // array and is unwrapped again in JavaScript.
        return "\(array)[0]"
    }

}

extension PreviewWebView {

    fileprivate func loadHTML(_ markdown: String) throws {
        let htmlString = MarkdownRenderer.html(from: markdown, tappableCheckBoxes: true)
        let pageHTMLString = try htmlFromTemplate(htmlString)
        loadHTMLString(pageHTMLString, baseURL: baseURL)
    }

    fileprivate func htmlFromTemplate(_ htmlString: String) throws -> String {
        let template = try String(contentsOf: baseURL, encoding: .utf8)
        return template.replacingOccurrences(of: "PREVIEW_HTML", with: htmlString)
    }

}

extension PreviewWebView: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            return decisionHandler(.allow)
        }

        // A checkbox is a link, because note content may not run the script that would otherwise
        // report the tap. The navigation never happens; it only carries the tap into the app.
        if let checkBox = PreviewCheckBoxes.target(of: url) {
            decisionHandler(.cancel)
            onCheckBoxTapped?(checkBox)
            return
        }

        switch navigationAction.navigationType {
        case .linkActivated:
            if let scheme = url.scheme, configuration.urlSchemeHandler(forURLScheme: scheme) != nil {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        default:
            decisionHandler(.allow)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let offset = pendingScrollOffset {
            pendingScrollOffset = nil
            scrollView.setContentOffset(offset, animated: false)
        }
        loadCompletion?()
    }

}

private extension WKNavigationDelegate {

    /// A wrapper for `UIApplication.shared.openURL` so that an empty default
    /// implementation is available in app extensions
    func openURL(url: URL) {}

}
