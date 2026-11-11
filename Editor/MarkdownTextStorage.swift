// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Peter Hedlund
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

/// A text storage that styles Markdown while the user types.
///
/// The note stays Markdown: the delimiters are part of the text and are only hidden on screen, so the
/// editor reads like a rich text editor, while the server keeps receiving `**bold**`. As soon as the
/// caret enters an element, its delimiters reappear so they can be edited.
public class MarkdownTextStorage: NSTextStorage {

    /// The underlying text storage implementation.
    private var backingStore = NSTextStorage()

    /// The delimiters to hide on screen, collected while styling and applied at the end of the pass.
    private var hiddenMarkers = [NSRange]()

    /// Whether the note shows its Markdown characters. The editor keeps this in sync with the user's setting.
    var showsMarkdownSource = KeychainHelper.showMarkdownSource

    /// The delimiter ranges that are currently invisible, so the caret can step over them.
    private(set) var hiddenDelimiterRanges = [NSRange]()

    ///
    /// Moves a caret that landed inside a hidden delimiter behind it.
    ///
    /// The characters are invisible but still part of the text. Without this, tapping at the end of a bold word
    /// could put the caret between the asterisks and the next typed character would edit the Markdown markup.
    ///
    func caretPosition(for selection: NSRange) -> NSRange {
        guard selection.length == 0, showsMarkdownSource == false else {
            return selection
        }

        for marker in hiddenDelimiterRanges where NSLocationInRange(selection.location, marker) {
            return NSRange(location: NSMaxRange(marker), length: 0)
        }

        return selection
    }

    /// What a hidden delimiter looks like: present in the text, invisible and without width on screen.
    private var hiddenDelimiterAttributes: [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 0.1), .foregroundColor: UIColor.clear]
    }

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

    /// Restyles the whole note, e.g. after the caret moved into or out of an inline element.
    func refreshFormatting() {
        beginEditing()
        applyMarkdownFormatting(NSRange(location: 0, length: backingStore.length))
        endEditing()
    }

    /// Applies Markdown formatting to the specified range.
    /// The delimiters stay in the text and are hidden unless the caret is inside their element.
    private func applyMarkdownFormatting(_ range: NSRange) {
        let text = backingStore.string

        // Reset all formatting to base style
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
        backingStore.setAttributes(baseAttributes, range: range)

        hiddenMarkers.removeAll()

        // Find all fenced code blocks first to exclude from other formatting
        let codeBlockRanges = fencedCodeBlockRanges(in: text)

        // Apply formatting for each markdown element
        applyHeaderFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyBoldFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyUnderlineFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyItalicFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyStrikethroughFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyHighlightFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyLinkFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyBlockQuoteFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyInlineCodeFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyListFormatting(in: text, range: range, excludingRanges: codeBlockRanges)
        applyCheckboxFormatting(in: text, range: range, excludingRanges: codeBlockRanges)

        // Apply code block formatting (this should be last to override other formatting)
        for codeBlockRange in codeBlockRanges {
            applyCodeBlockFormatting(range: codeBlockRange)
        }

        applyHiddenDelimiters()
    }

    /// Hides the Markdown delimiters after all other styling ran, so they never take up space on screen.
    private func applyHiddenDelimiters() {
        // The source mode shows the characters a note is made of, so nothing is hidden there.
        guard showsMarkdownSource == false else {
            hiddenDelimiterRanges.removeAll()
            return
        }

        for marker in hiddenMarkers {
            backingStore.addAttributes(hiddenDelimiterAttributes, range: marker)
        }

        hiddenDelimiterRanges = hiddenMarkers
    }

    ///
    /// The ranges of all fenced code blocks in the note, including a fence that is not closed yet.
    ///
    /// Only the edited lines are restyled after a keystroke, but whether a line is code depends on the fences
    /// around it. Looking at the whole note keeps `#` and `*` inside a code block unformatted, and a fence that
    /// has just been opened already marks the text below it as code, like the web editor and the preview do.
    ///
    private func fencedCodeBlockRanges(in text: String) -> [NSRange] {
        guard text.contains("```") || text.contains("~~~"),
              let fence = try? NSRegularExpression(pattern: #"^ {0,3}(?:```|~~~)"#) else {
            return []
        }

        var ranges = [NSRange]()
        var blockStart: Int?
        var offset = 0

        for line in text.components(separatedBy: "\n") {
            let length = (line as NSString).length

            if fence.firstMatch(in: line, range: NSRange(location: 0, length: length)) != nil {
                if let start = blockStart {
                    ranges.append(NSRange(location: start, length: offset + length - start))
                    blockStart = nil
                } else {
                    blockStart = offset
                }
            }

            offset += length + 1
        }

        // An unclosed fence runs to the end of the note.
        if let start = blockStart {
            ranges.append(NSRange(location: start, length: max((text as NSString).length - start, 0)))
        }

        return ranges
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

                    // The hashtags are syntax, not text: hide them like the inline delimiters.
                    if match.numberOfRanges >= 2 {
                        hiddenMarkers.append(match.range(at: 1))
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
            guard let match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) else {
                return
            }

            applyInlineStyle(match, delimiters: 2) { content in
                let currentFont = backingStore.attribute(.font, at: content.location, effectiveRange: nil) as? UIFont
                    ?? UIFont.preferredFont(forTextStyle: .body)
                backingStore.addAttribute(.font, value: currentFont.bold(), range: content)
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
            guard let match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) else {
                return
            }

            applyInlineStyle(match, delimiters: 2) { content in
                backingStore.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: content)
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
            guard let match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) else {
                return
            }

            applyInlineStyle(match, delimiters: 2) { content in
                backingStore.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
            }
        }
    }

    /// Applies highlight formatting (==text==), as written by Nextcloud Text
    private func applyHighlightFormatting(in text: String, range: NSRange, excludingRanges: [NSRange]) {
        let pattern = "==[^=\\s](?:[^=]*[^=\\s])?=="

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return
        }

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) else {
                return
            }

            applyInlineStyle(match, delimiters: 2) { content in
                backingStore.addAttributes([
                    .backgroundColor: UIColor.systemYellow.withAlphaComponent(0.35),
                    .highlight: true
                ], range: content)
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

                // The quote marker is formatting, so it is hidden in reading mode like the other delimiters.
                if match.numberOfRanges >= 3 {
                    let symbolRange = match.range(at: 1)
                    let contentRange = match.range(at: 2)
                    hiddenMarkers.append(NSRange(location: symbolRange.location,
                                                 length: max(contentRange.location - symbolRange.location, symbolRange.length)))
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
                guard let match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) else {
                    return
                }

                applyInlineStyle(match, delimiters: 1) { content in
                    let currentFont = backingStore.attribute(.font, at: content.location, effectiveRange: nil) as? UIFont
                        ?? UIFont.preferredFont(forTextStyle: .body)
                    backingStore.addAttribute(.font, value: currentFont.italic(), range: content)
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
            guard let match, !isRangeInExcludedRanges(match.range, excludingRanges: excludingRanges) else {
                return
            }

            applyInlineStyle(match, delimiters: 1) { content in
                let monoFont = UIFont(style: .body, design: .monospaced) ?? UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
                backingStore.addAttributes([
                    .font: monoFont,
                    .backgroundColor: UIColor.systemGray6
                ], range: content)
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
                    // A task line is drawn with a checkbox instead of a bullet.
                    guard !isTaskItem(match.range, in: text) else {
                        return
                    }

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

    /// Whether the line is a task list item like `- [ ] Buy milk`.
    private func isTaskItem(_ range: NSRange, in text: String) -> Bool {
        guard let line = Range(range, in: text) else {
            return false
        }

        return text[line].range(of: #"^\s*[-*+]\s+\[[ xX]\]"#, options: .regularExpression) != nil
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
                        let bulletRange = match.range(at: 2)

                        // The dash in front of the checkbox is syntax, so reading mode hides it too.
                        hiddenMarkers.append(NSRange(location: bulletRange.location,
                                                     length: checkboxRange.location - bulletRange.location))

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

    /// Styles the text between an element's delimiters and hides the delimiters while the caret is outside.
    ///
    /// Hiding them keeps the note Markdown on disk and in every request, while the editor shows the result:
    /// `**bold**` reads as **bold** and only shows its asterisks when the user edits that word.
    private func applyInlineStyle(_ match: NSTextCheckingResult, delimiters: Int, _ style: (NSRange) -> Void) {
        let whole = match.range
        let content = NSRange(location: whole.location + delimiters, length: whole.length - 2 * delimiters)

        guard content.length > 0, NSMaxRange(content) <= (backingStore.string as NSString).length else {
            return
        }

        style(content)

        // Hidden at the end of the pass: list and checkbox styling set a font over their whole line,
        // which would otherwise bring the delimiters back.
        hiddenMarkers.append(NSRange(location: whole.location, length: delimiters))
        hiddenMarkers.append(NSRange(location: NSMaxRange(whole) - delimiters, length: delimiters))
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
