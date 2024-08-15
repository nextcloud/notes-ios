//
//  PreviewWebView.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/25/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import cmark_gfm_swift
import UIKit
import WebKit

typealias LoadCompletion = () -> Void

class PreviewWebView: WKWebView {

    let bundle: Bundle

    private lazy var baseURL: URL = {
        return self.bundle.url(forResource: "index", withExtension: "html")!
    }()

    private var loadCompletion: LoadCompletion?

    // List of markdown options
    var options: [MarkdownOption] = [
      .footnotes // Footnote syntax
    ]

    // List of markdown extensions
    var extensions: [MarkdownExtension] = [
      .emoji,        // GitHub emojis
      .table,        // Tables
      .autolink,     // Autolink URLs
      .mention,      // GitHub @ mentions
      .checkbox,     // Checkboxes
      .wikilink,     // WikiLinks
      .strikethrough // Strikethrough
    ]

    public init(markdown: String, completion: LoadCompletion? = nil) throws {

        let bundleUrl = Bundle.main.url(forResource: "Preview", withExtension: "bundle")!
        self.bundle =  Bundle(url: bundleUrl)!

        loadCompletion = completion
        
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        navigationDelegate = self
        do {
            try loadHTML(markdown)
        } catch {
            //
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

private extension PreviewWebView {

    func loadHTML(_ markdown: String) throws {
        let htmlString = Node(markdown: markdown, options: options, extensions: extensions)?.html

        let pageHTMLString = try htmlFromTemplate(htmlString ?? markdown)
        loadHTMLString(pageHTMLString, baseURL: baseURL)
    }

    func htmlFromTemplate(_ htmlString: String) throws -> String {
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
        loadCompletion?()
    }

}

private extension WKNavigationDelegate {

    /// A wrapper for `UIApplication.shared.openURL` so that an empty default
    /// implementation is available in app extensions
    func openURL(url: URL) {}

}
