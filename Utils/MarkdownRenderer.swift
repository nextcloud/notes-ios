// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Markdown
import Foundation

/// Renders markdown as HTML while stripping javascript and raw HTML completely to prevent XSS vulnerabilities in note previews.
enum MarkdownRenderer {
    private static let disallowedURLSchemes: Set<String> = [
        "javascript",
        "vbscript",
        "data",
        "file"
    ]

    private struct SanitizingRewriter: MarkupRewriter {
        mutating func visitHTMLBlock(_: HTMLBlock) -> Markup? {
            nil
        }

        mutating func visitInlineHTML(_: InlineHTML) -> Markup? {
            nil
        }

        mutating func visitLink(_ link: Link) -> Markup? {
            var sanitizedLink = link
            if MarkdownRenderer.isDisallowedURL(link.destination) {
                sanitizedLink.destination = nil
            }
            return defaultVisit(sanitizedLink)
        }

        mutating func visitImage(_ image: Image) -> Markup? {
            var sanitizedImage = image
            if MarkdownRenderer.isDisallowedURL(image.source) {
                sanitizedImage.source = nil
            }
            return defaultVisit(sanitizedImage)
        }
    }

    private static func isDisallowedURL(_ rawValue: String?) -> Bool {
        guard let rawValue else {
            return false
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if let scheme = URLComponents(string: trimmed)?.scheme?.lowercased() {
            return disallowedURLSchemes.contains(scheme)
        }

        guard let colonIndex = trimmed.firstIndex(of: ":") else {
            return false
        }

        let rawSchemeSubstring = trimmed[..<colonIndex]
        let invalidSchemeCharacters = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        if rawSchemeSubstring.unicodeScalars.contains(where: { invalidSchemeCharacters.contains($0) }) {
            return true
        }

        let scheme = rawSchemeSubstring.lowercased()
        guard let firstScalar = scheme.unicodeScalars.first,
              CharacterSet.lowercaseLetters.contains(firstScalar)
        else {
            return true
        }

        let allowedSchemeCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789+-.")
        let isValidScheme = scheme.unicodeScalars.allSatisfy { allowedSchemeCharacterSet.contains($0) }
        guard isValidScheme else {
            return true
        }

        return disallowedURLSchemes.contains(String(scheme))
    }

    static func html(from markdown: String) -> String {
        let document = Document(parsing: markdown)
        var sanitizer = SanitizingRewriter()
        guard let sanitizedMarkup = sanitizer.visit(document) else {
            return ""
        }
        return HTMLFormatter.format(sanitizedMarkup)
    }
}
