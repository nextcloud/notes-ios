//
//  AttachmentHelper.swift
//  iOCNotes
//
//  Created by oli-ver on 16/08/2025.
//  Copyright © 2025 Nextcloud GmbH. All rights reserved.
//

import Foundation
import os

class AttachmentHelper{
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AttachmentHelper")

    public func extractRelativeAttachmentPaths(from markdown: String, removeUrlEncoding: Bool) -> [String] {
        logger.notice("Parsing markdown: \(markdown, privacy: .sensitive)")
        // Parse markdown attachments: ![alt](path "optional title")
        let mdImage = try! NSRegularExpression(
            pattern: #"""
            !\[
                [^\]]*              # alt text (everything until closing square bracket)
            \]
            \(
                \s*
                (?<url>[^)\s]+)     # URL: until closing paranthesis or first space
                (?:\s+["'][^"']*["'])?  # optional title in '...' or "..."
                \s*
            \)
            """#,
            options: [.allowCommentsAndWhitespace]
        )

        // Parse HTML images: <img src = "path"> or <img src='path'>
        let htmlImg = try! NSRegularExpression(
            pattern: #"<img\b[^>]*\bsrc\s*=\s*(['"])(?<url>.*?)\1"#,
            options: [.caseInsensitive]
        )
        
        func matches(_ regex: NSRegularExpression, in s: String) -> [String] {
            let ns = s as NSString
            return regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap {
                let r = $0.range(withName: "url")
                guard r.location != NSNotFound else { return nil }
                return ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // collect download candidates
        let candidates = matches(mdImage, in: markdown) + matches(htmlImg, in: markdown)
        logger.notice("Found the following path candidates: \(candidates, privacy: .public)")

        // only retain relative paths
        
        let filteredCandidates = candidates.filter { raw in
            let urlString = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if urlString.isEmpty { return false }
            if urlString.hasPrefix("/") { return false }
            if urlString.lowercased().hasPrefix("http://") { return false }
            if urlString.lowercased().hasPrefix("https://") { return false }
            if urlString.lowercased().hasPrefix("data:") { return false }
            // Remove schemas if any
            if let colon = urlString.firstIndex(of: ":"), urlString[..<colon].contains(where: { $0 == "/" }) == false {
                return false
            }
            return true
        }
        logger.notice("Path candidates after filtering: \(filteredCandidates, privacy: .public)")
        
        if removeUrlEncoding {
            let normalized: [String] = filteredCandidates.map { raw in
                let decoded = raw.removingPercentEncoding ?? raw
                return decoded
            }
            
            return normalized
        }
        
        return filteredCandidates
        
        
    }

}

