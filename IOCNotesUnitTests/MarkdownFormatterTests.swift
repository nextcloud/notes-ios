// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

@Suite("MarkdownFormatter Tests")
struct MarkdownFormatterTests {

    /// Input and output mark the selection: `|` for a caret, `[[…]]` for a range.
    private func apply(_ format: (String, NSRange) -> MarkdownFormatter.Edit, to marked: String) -> String {
        let (text, selection) = parse(marked)
        let edit = format(text, selection)
        let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.replacement)

        return render(result, selection: edit.selection)
    }

    private func parse(_ marked: String) -> (String, NSRange) {
        let string = marked as NSString
        let caret = string.range(of: "|")

        if caret.location != NSNotFound {
            return (string.replacingCharacters(in: caret, with: ""), NSRange(location: caret.location, length: 0))
        }

        let open = string.range(of: "[[").location
        let close = string.range(of: "]]").location
        let text = string.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")

        return (text, NSRange(location: open, length: close - open - 2))
    }

    private func render(_ text: String, selection: NSRange) -> String {
        let string = text as NSString

        guard selection.length > 0 else {
            return string.replacingCharacters(in: selection, with: "|")
        }

        return string.substring(to: selection.location) + "[[" + string.substring(with: selection) + "]]" + string.substring(from: NSMaxRange(selection))
    }

    private let bullet = { MarkdownFormatter.toggleLineStyle(.bullet, in: $0, selection: $1) }
    private let checkbox = { MarkdownFormatter.toggleLineStyle(.checkbox, in: $0, selection: $1) }
    private let ordered = { MarkdownFormatter.toggleLineStyle(.ordered, in: $0, selection: $1) }
    private let highlight = { MarkdownFormatter.toggleWrap("==", in: $0, selection: $1) }
    private let h2 = { MarkdownFormatter.toggleHeading(2, in: $0, selection: $1) }
    private let fence = { MarkdownFormatter.wrapLines(open: "```", close: "```", in: $0, selection: $1) }

    // MARK: - Emphasis

    @Test("Bold wraps and unwraps a selection")
    func bold() {
        #expect(apply(MarkdownFormatter.toggleBold, to: "a [[word]] b") == "a **[[word]]** b")
        #expect(apply(MarkdownFormatter.toggleBold, to: "a **[[word]]** b") == "a [[word]] b")
        #expect(apply(MarkdownFormatter.toggleBold, to: "a [[**word**]] b") == "a [[word]] b")
    }

    @Test("Bold on a caret inserts markers around it, a second tap removes them")
    func boldCaret() {
        #expect(apply(MarkdownFormatter.toggleBold, to: "a |") == "a **|**")
        #expect(apply(MarkdownFormatter.toggleBold, to: "a **|**") == "a |")
    }

    @Test("Italic and bold combine and come apart independently")
    func italicAndBold() {
        #expect(apply(MarkdownFormatter.toggleItalic, to: "[[word]]") == "*[[word]]*")
        #expect(apply(MarkdownFormatter.toggleItalic, to: "*[[word]]*") == "[[word]]")
        #expect(apply(MarkdownFormatter.toggleItalic, to: "**[[word]]**") == "***[[word]]***")
        #expect(apply(MarkdownFormatter.toggleBold, to: "***[[word]]***") == "*[[word]]*")
        #expect(apply(MarkdownFormatter.toggleItalic, to: "***[[word]]***") == "**[[word]]**")
    }

    @Test("Other markers wrap and unwrap, selected along with the text or around it")
    func wrap() {
        #expect(apply(highlight, to: "a [[word]]") == "a ==[[word]]==")
        #expect(apply(highlight, to: "a ==[[word]]==") == "a [[word]]")
        #expect(apply(highlight, to: "a [[==word==]]") == "a [[word]]")
        #expect(apply(highlight, to: "|") == "==|==")
        #expect(apply(highlight, to: "==|==") == "|")
    }

    @Test("A link uses the selection as its text, or the URL without one")
    func link() {
        let link = { MarkdownFormatter.insertLink("https://nextcloud.com", in: $0, selection: $1) }

        #expect(apply(link, to: "see [[this]]") == "see [this](https://nextcloud.com)|")
        #expect(apply(link, to: "see |") == "see [https://nextcloud.com](https://nextcloud.com)|")
    }

    // MARK: - Lines

    @Test("Ordered lists number the selected lines and skip blank ones")
    func orderedList() {
        #expect(apply(ordered, to: "[[a\n\nb]]") == "[[1. a\n\n2. b]]")
        #expect(apply(ordered, to: "- it|em") == "1. it|em")
        #expect(apply(ordered, to: "1. it|em") == "it|em")
    }

    @Test("Headings set, change and remove the level")
    func headings() {
        #expect(apply(h2, to: "Tit|le") == "## Tit|le")
        #expect(apply(h2, to: "# Tit|le") == "## Tit|le")
        #expect(apply(h2, to: "## Tit|le") == "Tit|le")
        #expect(apply(h2, to: "#hashtag|") == "## #hashtag|")
    }

    @Test("Quotes toggle on every selected line")
    func quote() {
        #expect(apply(MarkdownFormatter.toggleQuote, to: "[[a\nb]]") == "[[> a\n> b]]")
        #expect(apply(MarkdownFormatter.toggleQuote, to: "> a|") == "a|")
    }

    @Test("Line state reports heading, list and quote of the caret's line")
    func lineState() {
        let state = { (marked: String) -> MarkdownFormatter.LineState in
            let (text, selection) = parse(marked)
            return MarkdownFormatter.lineState(in: text, selection: selection)
        }

        #expect(state("a\n### Ti|tle") == .init(heading: 3))
        #expect(state("    - [x] do|ne\nb") == .init(list: .checkbox))
        #expect(state("12. i|tem") == .init(list: .ordered))
        #expect(state("> quo|te") == .init(isQuote: true))
        #expect(state("plain|") == .init())
    }

    @Test("Bullet and checkbox toggle on the current line and keep the caret in the text")
    func lineStyleCaret() {
        #expect(apply(bullet, to: "it|em") == "- it|em")
        #expect(apply(bullet, to: "- it|em") == "it|em")
        #expect(apply(checkbox, to: "it|em") == "- [ ] it|em")
        #expect(apply(checkbox, to: "- it|em") == "- [ ] it|em")
        #expect(apply(checkbox, to: "- [x] it|em") == "it|em")
        #expect(apply(bullet, to: "- [ ] it|em") == "- it|em")
        #expect(apply(bullet, to: "1. it|em") == "- it|em")
        #expect(apply(checkbox, to: "|") == "- [ ] |")
    }

    @Test("Bullet and checkbox keep indentation and the bullet character")
    func lineStyleIndentation() {
        #expect(apply(checkbox, to: "    * it|em") == "    * [ ] it|em")
        #expect(apply(bullet, to: "    * [ ] it|em") == "    * it|em")
    }

    @Test("Line styles apply to every selected line and skip blank ones")
    func lineStyleSelection() {
        #expect(apply(checkbox, to: "[[a\n\nb]]\nc") == "[[- [ ] a\n\n- [ ] b]]\nc")
        #expect(apply(checkbox, to: "[[- [ ] a\nb]]") == "[[- [ ] a\n- [ ] b]]")
        #expect(apply(checkbox, to: "[[- [ ] a\n- [x] b]]") == "[[a\nb]]")
    }

    @Test("Only the lines touched by the selection change")
    func lineStyleLeavesOtherLines() {
        #expect(apply(bullet, to: "a\nb|\nc") == "a\n- b|\nc")
    }

    @Test("Emphasis-looking text is not mistaken for a bullet")
    func notABullet() {
        #expect(apply(bullet, to: "*word* te|xt") == "- *word* te|xt")
    }

    // MARK: - Indentation

    @Test("Indent and outdent move lines by four spaces and keep the caret in the text")
    func indentation() {
        #expect(apply(MarkdownFormatter.indent, to: "- [ ] it|em") == "    - [ ] it|em")
        #expect(apply(MarkdownFormatter.outdent, to: "    - [ ] it|em") == "- [ ] it|em")
        #expect(apply(MarkdownFormatter.outdent, to: "  - it|em") == "- it|em")
        #expect(apply(MarkdownFormatter.outdent, to: "\t- it|em") == "- it|em")
        #expect(apply(MarkdownFormatter.outdent, to: "- it|em") == "- it|em")
    }

    // MARK: - Blocks

    @Test("Blocks wrap the selected lines or start empty with the caret inside")
    func blocks() {
        #expect(apply(fence, to: "a\nb|") == "a\n```\nb|\n```")
        #expect(apply(fence, to: "|") == "```\n|\n```")
        #expect(apply(fence, to: "[[a\nb]]\nc") == "```\na\nb|\n```\nc")
    }

    @Test("Tables go on a blank line, or below the current one, with the caret in the first cell")
    func table() {
        let table = "|  |  |  |\n| --- | --- | --- |\n|  |  |  |"

        #expect(MarkdownFormatter.insertTable(in: "", selection: NSRange(location: 0, length: 0))
                == .init(range: NSRange(location: 0, length: 0), replacement: table, selection: NSRange(location: 2, length: 0)))
        #expect(MarkdownFormatter.insertTable(in: "text", selection: NSRange(location: 4, length: 0))
                == .init(range: NSRange(location: 0, length: 4), replacement: "text\n\n" + table, selection: NSRange(location: 8, length: 0)))
    }

    @Test("Indent applies to every selected line and leaves blank lines empty")
    func indentSelection() {
        #expect(apply(MarkdownFormatter.indent, to: "[[- a\n\n- b]]") == "[[    - a\n\n    - b]]")
        #expect(apply(MarkdownFormatter.outdent, to: "[[    - a\n        - b]]") == "[[- a\n    - b]]")
    }
}
