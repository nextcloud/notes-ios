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
import UniformTypeIdentifiers
import os

typealias LoadCompletion = () -> Void

class PreviewWebView: WKWebView {

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PreviewWebView")
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

    public init(markdown: String, noteId: Int64, completion: LoadCompletion? = nil) throws {

        let bundleUrl = Bundle.main.url(forResource: "Preview", withExtension: "bundle")!
        self.bundle =  Bundle(url: bundleUrl)!

        loadCompletion = completion
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(AttachmentSchemeHandler(), forURLScheme: AttachmentURL.scheme)
        super.init(frame: .zero, configuration: configuration)
        navigationDelegate = self
        do {
            try loadHTML(markdown, noteId: noteId)
        } catch {
            logger.error("Error when loading HTML: \(error, privacy: .public)")
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

private extension PreviewWebView {
    
    func loadHTML(_ markdown: String, noteId: Int64) throws {
        let htmlString = Node(markdown: markdown, options: options, extensions: extensions)?.html ?? markdown
        let attachmentHelper: AttachmentHelper = AttachmentHelper()
        let relPaths = attachmentHelper.extractRelativeAttachmentPaths(from: markdown, removeUrlEncoding: false)
        let htmlRewritten = rewriteAttachmentURLs(in: htmlString, noteId: noteId, relativePaths: relPaths)
        let pageHTMLString = try htmlFromTemplate(htmlRewritten)
        loadHTMLString(pageHTMLString, baseURL: baseURL)
    }

    func htmlFromTemplate(_ htmlString: String) throws -> String {
        let template = try String(contentsOf: baseURL, encoding: .utf8)
        return template.replacingOccurrences(of: "PREVIEW_HTML", with: htmlString)
    }

    enum AttachmentURL {
        static let scheme = "notes-attach"

        static func make(noteId: Int64, relativePath: String) -> URL {
            var comps = URLComponents()
            comps.scheme = scheme
            comps.host = String(noteId)
            comps.path = "/" + relativePath
            return comps.url!
        }
    }
    
    private func rewriteAttachmentURLs(in html: String, noteId: Int64, relativePaths: [String]) -> String {
        var out = html
        var disallowed = CharacterSet.urlPathAllowed
        disallowed.remove(charactersIn: "()")
        for rel in relativePaths {
            let encoded = rel.addingPercentEncoding(withAllowedCharacters: disallowed) ?? rel
            let target = AttachmentURL.make(noteId: noteId, relativePath: rel).absoluteString
            logger.debug("Replacing paths \(rel, privacy: .public) and \(encoded, privacy: .public) with \(target, privacy: .public)")
            out = out.replacingOccurrences(of: "src=\"\(rel)\"", with: "src=\"\(target)\"")
                     .replacingOccurrences(of: "src=\"\(encoded)\"", with: "src=\"\(target)\"")
                     .replacingOccurrences(of: "href=\"\(rel)\"", with: "href=\"\(target)\"")
                     .replacingOccurrences(of: "href=\"\(encoded)\"", with: "href=\"\(target)\"")
        }
        return out
    }

    final class AttachmentSchemeHandler: NSObject, WKURLSchemeHandler {

        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            DispatchQueue.main.async { [weak urlSchemeTask] in
                guard let task = urlSchemeTask else { return }
                guard let url = task.request.url,
                      url.scheme == AttachmentURL.scheme,
                      let noteId = Int(url.host ?? "") else {
                    task.didFailWithError(NSError(domain: "Attachment", code: 400, userInfo: nil))
                    return
                }

                // Extract path and normalize
                let relativePath = String(url.path.dropFirst()) // drop leading "/"
                let encodedPath = relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relativePath
                let fileURL = AttachmentStore.shared.fileURL(noteId: noteId, relativePath: encodedPath)

                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    task.didFailWithError(NSError(domain: "Attachment", code: 404, userInfo: [NSFilePathErrorKey: fileURL.path]))
                    return
                }

                do {
                    let data = try Data(contentsOf: fileURL)
                    let mime = self.mimeType(for: fileURL)
                    let resp = URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: "utf-8")
                    task.didReceive(resp)
                    task.didReceive(data)
                    task.didFinish()
                } catch {
                    task.didFailWithError(error)
                }
            }
        }

        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
            // Do not send anything, the task is stopped
        }

        private func mimeType(for fileURL: URL) -> String {
            if #available(iOS 14.0, *) {
                if let type = UTType(filenameExtension: fileURL.pathExtension),
                   let preferred = type.preferredMIMEType {
                    return preferred
                }
            }
            // Fallbacks
            switch fileURL.pathExtension.lowercased() {
            case "png": return "image/png"
            case "jpg", "jpeg": return "image/jpeg"
            case "gif": return "image/gif"
            case "webp": return "image/webp"
            case "svg": return "image/svg+xml"
            case "pdf": return "application/pdf"
            default: return "application/octet-stream"
            }
        }
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
