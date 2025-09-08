//
//  MarkdownTextStorage.swift
//  iOCNotes
//
//  Created by Copilot on 2025-01-15.
//  Copyright © 2025 Peter Hedlund. All rights reserved.
//

import UIKit

/// A text storage implementation that applies Xcode-style markdown formatting
/// Shows raw markdown characters but applies appropriate styling
public class MarkdownTextStorage: NSTextStorage {
    
    /// The underlying text storage implementation.
    private var backingStore = NSTextStorage()
    
    override public var string: String {
        get {
            return backingStore.string
        }
    }
    
    override public init() {
        super.init()
    }
    
    override public init(attributedString attrStr: NSAttributedString) {
        super.init(attributedString: attrStr)
        backingStore.setAttributedString(attrStr)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(itemProviderData data: Data, typeIdentifier: String) throws {
        fatalError("init(itemProviderData:typeIdentifier:) has not been implemented")
    }
    
    override public func attributes(at location: Int, longestEffectiveRange range: NSRangePointer?, in rangeLimit: NSRange) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, longestEffectiveRange: range, in: rangeLimit)
    }
    
    override public func replaceCharacters(in range: NSRange, with str: String) {
        self.beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        let len = (str as NSString).length
        let change = len - range.length
        self.edited([.editedCharacters, .editedAttributes], range: range, changeInLength: change)
        self.endEditing()
    }
    
    public override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        self.beginEditing()
        backingStore.setAttributes(attrs, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
        self.endEditing()
    }
    
    public override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    override public func processEditing() {
        let backingString = backingStore.string
        if let nsRange = backingString.range(from: NSMakeRange(NSMaxRange(editedRange), 0)) {
            let indexRange = backingString.lineRange(for: nsRange)
            let extendedRange: NSRange = NSUnionRange(editedRange, backingString.nsRange(from: indexRange))
            applyMarkdownFormatting(extendedRange)
        }
        super.processEditing()
    }
    
    /// Applies Xcode-style markdown formatting to the specified range
    /// Shows raw markdown characters but applies appropriate styling
    private func applyMarkdownFormatting(_ range: NSRange) {
        let text = backingStore.string
        
        // Reset all formatting to base style
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
        backingStore.setAttributes(baseAttributes, range: range)
        
        // Find all fenced code blocks first to exclude from other formatting
        let codeBlockRanges = findFencedCodeBlocks(in: text, range: range)
        
        // Apply formatting for each markdown element
        applyHeaderFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyBoldFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyUnderlineFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyItalicFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyStrikethroughFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyLinkFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyBlockQuoteFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyInlineCodeFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyListFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyCheckboxFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        
        // Apply code block formatting (this should be last to override other formatting)
        for codeBlockRange in codeBlockRanges {
            applyCodeBlockFormatting(range: codeBlockRange)
        }
    }
    
    /// Finds all fenced code block ranges (```...```)
    private func findFencedCodeBlocks(in text: String, range: NSRange) -> [NSRange] {
        var codeBlockRanges: [NSRange] = []
        
        // Pattern: ```(optional language)\n(content)\n```
        // More robust pattern that handles edge cases
        let pattern = "```[^\\r\\n]*[\\r\\n][\\s\\S]*?[\\r\\n]```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return codeBlockRanges
        }
        
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match {
                // Include the entire code block (including backticks) for monospaced formatting
                codeBlockRanges.append(match.range)
            }
        }
        
        return codeBlockRanges
    }
    
    /// Applies header formatting (larger font sizes)
    private func applyHeaderFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let headerPatterns = [
            ("^(#{1})\\s+(.*)$", UIFont.TextStyle.title1),
            ("^(#{2})\\s+(.*)$", UIFont.TextStyle.title2),
            ("^(#{3})\\s+(.*)$", UIFont.TextStyle.title3),
            ("^(#{4})\\s+(.*)$", UIFont.TextStyle.headline),
            ("^(#{5})\\s+(.*)$", UIFont.TextStyle.subheadline),
            ("^(#{6})\\s+(.*)$", UIFont.TextStyle.callout)
        ]
        
        for (pattern, textStyle) in headerPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                continue
            }
            
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                    // Apply bold font with larger size for the entire header
                    let font = UIFont.preferredFont(forTextStyle: textStyle).bold()
                    backingStore.addAttribute(.font, value: font, range: match.range)
                    
                    // Apply faded color to the hashtag symbols only
                    if match.numberOfRanges >= 2 {
                        let hashtagRange = match.range(at: 1)
                        let fadedColor = UIColor.label.withAlphaComponent(0.5)
                        backingStore.addAttribute(.foregroundColor, value: fadedColor, range: hashtagRange)
                    }
                }
            }
        }
    }
    
    /// Applies bold formatting (**text**)
    private func applyBoldFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let pattern = "\\*\\*[^*\\s][^*]*[^*\\s]\\*\\*"  // **bold** only
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }
        
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                let currentFont = backingStore.attribute(.font, at: match.range.location, effectiveRange: nil) as? UIFont
                    ?? UIFont.preferredFont(forTextStyle: .body)
                let boldFont = currentFont.bold()
                backingStore.addAttribute(.font, value: boldFont, range: match.range)
            }
        }
    }
    
    /// Applies underline formatting (__text__)
    private func applyUnderlineFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let pattern = "__[^_\\s][^_]*[^_\\s]__"  // __underline__
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }
        
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                backingStore.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }
    }
    
    /// Applies strikethrough formatting (~~text~~)
    private func applyStrikethroughFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let pattern = "~~[^~\\s][^~]*[^~\\s]~~"  // ~~strikethrough~~
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }
        
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                backingStore.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
        }
    }
    
    /// Applies link formatting ([text](url) and ![alt](src))
    private func applyLinkFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let patterns = [
            "!?\\[[^\\]]*\\]\\([^\\)]*\\)"  // [text](url) and ![alt](src)
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                    // Apply blue color and underline for links
                    backingStore.addAttributes([
                        .foregroundColor: UIColor.systemBlue,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ], range: match.range)
                }
            }
        }
    }
    
    /// Applies block quote formatting (> text)
    private func applyBlockQuoteFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let pattern = "^(>+)\\s*(.*)$"  // > blockquote
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return
        }
        
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                let fadedColor = UIColor.label.withAlphaComponent(0.6)
                
                // Apply faded color to the entire block quote
                backingStore.addAttribute(.foregroundColor, value: fadedColor, range: match.range)
                
                // Apply even more faded color to the > symbol
                if match.numberOfRanges >= 2 {
                    let quoteSymbolRange = match.range(at: 1)
                    let symbolFadedColor = UIColor.label.withAlphaComponent(0.4)
                    backingStore.addAttribute(.foregroundColor, value: symbolFadedColor, range: quoteSymbolRange)
                }
            }
        }
    }
    
    /// Applies italic formatting (*text* or _text_)
    private func applyItalicFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let patterns = [
            "(?<!\\*)\\*[^*\\s][^*]*[^*\\s]\\*(?!\\*)",  // *italic* (not **bold**)
            "(?<!_)_[^_\\s][^_]*[^_\\s]_(?!_)"           // _italic_ (not __bold__)
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }
            
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                    let currentFont = backingStore.attribute(.font, at: match.range.location, effectiveRange: nil) as? UIFont
                        ?? UIFont.preferredFont(forTextStyle: .body)
                    let italicFont = currentFont.italic()
                    backingStore.addAttribute(.font, value: italicFont, range: match.range)
                }
            }
        }
    }
    
    /// Applies inline code formatting (`code`)
    private func applyInlineCodeFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let pattern = "`[^`\\r\\n]+`"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }
        
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                let monoFont = UIFont(style: .body, design: .monospaced) ?? UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
                let bgColor = UIColor.systemGray6
                backingStore.addAttributes([
                    .font: monoFont,
                    .backgroundColor: bgColor
                ], range: match.range)
            }
        }
    }
    
    /// Applies code block formatting (monospaced font)
    private func applyCodeBlockFormatting(range: NSRange) {
        let monoFont = UIFont(style: .body, design: .monospaced) ?? UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        let bgColor = UIColor.systemGray6
        backingStore.addAttributes([
            .font: monoFont,
            .backgroundColor: bgColor,
            .foregroundColor: UIColor.label
        ], range: range)
    }
    
    /// Applies list formatting for both ordered and unordered lists
    private func applyListFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let patterns = [
            "^(\\s*)([-*+])\\s+(.*)$",  // Unordered lists
            "^(\\s*)(\\d+\\.)\\s+(.*)$" // Ordered lists
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                continue
            }
            
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                    // Apply styling to the entire list item but keep it readable
                    let font = UIFont.preferredFont(forTextStyle: .body)
                    backingStore.addAttribute(.font, value: font, range: match.range)
                    
                    // Add special attribute for list items - apply to the bullet character itself
                    // so the LayoutManager can replace it with the appropriate glyph
                    if match.numberOfRanges >= 3 {
                        let bulletRange = match.range(at: 2)
                        if pattern.contains("[-*+]") {
                            backingStore.addAttribute(.listItemUnordered, value: true, range: bulletRange)
                        } else {
                            backingStore.addAttribute(.listItemOrdered, value: true, range: bulletRange)
                        }
                    }
                }
            }
        }
    }
    
    /// Applies checkbox formatting for task lists
    private func applyCheckboxFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let patterns = [
            "^(\\s*)([-*+])\\s+(\\[ ])(.*)$",   // Unchecked checkbox
            "^(\\s*)([-*+])\\s+(\\[[xX]])(.*)$" // Checked checkbox
        ]
        
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                continue
            }
            
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) {
                    // Apply styling to the entire checkbox line
                    let font = UIFont.preferredFont(forTextStyle: .body)
                    backingStore.addAttribute(.font, value: font, range: match.range)
                    
                    // Add special attributes for checkboxes
                    if match.numberOfRanges >= 4 {
                        let checkboxRange = match.range(at: 3)
                        let contentRange = match.range(at: 4)
                        
                        if index == 0 { // Unchecked
                            backingStore.addAttribute(.checkBoxOpen, value: true, range: checkboxRange)
                        } else { // Checked
                            backingStore.addAttribute(.checkBoxChecked, value: true, range: checkboxRange)
                            // Strike through completed tasks
                            backingStore.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                            backingStore.addAttribute(.foregroundColor, value: UIColor.systemGray, range: contentRange)
                        }
                    }
                }
            }
        }
    }
    
    /// Checks if a range overlaps with any of the excluded ranges
    private func isRangeInExcludedRanges(_ range: NSRange, excludingRanges: [NSRange]) -> Bool {
        for excludedRange in excludingRanges {
            if NSIntersectionRange(range, excludedRange).length > 0 {
                return true
            }
        }
        return false
    }
}
