// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import iOCNotes

///
/// The formatted reading mode and the Markdown source mode of the editor.
///
/// The note stays Markdown in the text storage. Reading mode only hides the delimiters on screen, so these
/// tests check the presentation, the caret behaviour and that switching between the modes never changes the text.
///
@Suite("Reading mode")
struct ReadingModeTests {
    private func storage(_ text: String, source: Bool = false) -> MarkdownTextStorage {
        let storage = MarkdownTextStorage()
        storage.showsMarkdownSource = source
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        storage.endEditing()
        storage.refreshFormatting()
        return storage
    }

    private func isHidden(_ location: Int, in storage: MarkdownTextStorage) -> Bool {
        let font = storage.attributes(at: location, effectiveRange: nil)[.font] as? UIFont
        return (font?.pointSize ?? 12) < 1
    }

    @Test("The delimiters are invisible but still in the text")
    func delimitersStayInTheText() {
        let text = "a **bold** b"
        let storage = storage(text)

        #expect(storage.string == text, "Reading mode must not remove characters")
        #expect(isHidden(2, in: storage), "The opening ** must be invisible")
        #expect(isHidden(3, in: storage), "The opening ** must be invisible")
        #expect(!isHidden(4, in: storage), "The bold word must stay visible")
        #expect(isHidden(8, in: storage), "The closing ** must be invisible")
    }

    @Test("The caret steps over an invisible delimiter")
    func caretSkipsHiddenDelimiters() {
        let storage = storage("a **bold** b")

        // Indices: a=0, space=1, **=2…3, bold=4…7, **=8…9, space=10, b=11.
        #expect(storage.caretPosition(for: NSRange(location: 2, length: 0)) == NSRange(location: 4, length: 0))
        #expect(storage.caretPosition(for: NSRange(location: 3, length: 0)) == NSRange(location: 4, length: 0))
        #expect(storage.caretPosition(for: NSRange(location: 4, length: 0)) == NSRange(location: 4, length: 0))
        #expect(storage.caretPosition(for: NSRange(location: 8, length: 0)) == NSRange(location: 10, length: 0))
    }

    @Test("The source mode keeps the caret where it is")
    func sourceModeKeepsTheCaret() {
        let storage = storage("a **bold** b", source: true)

        #expect(!isHidden(2, in: storage), "Source mode shows the delimiters")
        #expect(storage.caretPosition(for: NSRange(location: 3, length: 0)) == NSRange(location: 3, length: 0))
    }

    @Test("Headings hide their hashes in reading mode")
    func headingHashesAreHidden() {
        let storage = storage("# Heading\n\nText")

        #expect(storage.string == "# Heading\n\nText")
        #expect(isHidden(0, in: storage))
        #expect(!isHidden(2, in: storage))
    }

    @Test("Task lists draw a checkbox instead of a bullet")
    func taskLinesHaveNoBullet() {
        let storage = storage("- [ ] Milk\n- [x] Bread\n- Plain item")

        // "- [ ] Milk": the dash is at 0 and the checkbox at 2.
        #expect(storage.attributes(at: 0, effectiveRange: nil)[.listItemUnordered] == nil)
        #expect(storage.attributes(at: 2, effectiveRange: nil)[.checkBoxOpen] as? Bool == true)

        let checked = storage.string.range(of: "[x]")!.lowerBound
        let checkedOffset = storage.string.distance(from: storage.string.startIndex, to: checked)
        #expect(storage.attributes(at: checkedOffset, effectiveRange: nil)[.checkBoxChecked] as? Bool == true)

        let plain = storage.string.range(of: "- Plain")!.lowerBound
        let plainOffset = storage.string.distance(from: storage.string.startIndex, to: plain)
        #expect(storage.attributes(at: plainOffset, effectiveRange: nil)[.listItemUnordered] as? Bool == true)
    }

    @Test("Block quotes hide their marker in reading mode")
    func quoteMarkerIsHidden() {
        let storage = storage("> quoted")

        #expect(storage.string == "> quoted")
        #expect(isHidden(0, in: storage), "The > marker must be invisible")
        #expect(!isHidden(2, in: storage), "The quoted text must stay visible")
    }

    @Test("Switching the mode twice keeps the note")
    func switchingModesKeepsTheText() {
        let text = "# Title\n\nA **bold** word and a\n- [ ] task\n\n> quote"
        let storage = storage(text)

        storage.showsMarkdownSource = true
        storage.refreshFormatting()
        #expect(storage.string == text)

        storage.showsMarkdownSource = false
        storage.refreshFormatting()
        #expect(storage.string == text)
        #expect(isHidden(0, in: storage))
    }

    @Test("A new editor picks up the stored display mode")
    func storedModeIsUsed() {
        let previous = KeychainHelper.showMarkdownSource
        defer { KeychainHelper.showMarkdownSource = previous }

        KeychainHelper.showMarkdownSource = true
        #expect(MarkdownTextStorage().showsMarkdownSource, "The stored setting must survive a new editor")

        KeychainHelper.showMarkdownSource = false
        #expect(!MarkdownTextStorage().showsMarkdownSource)
    }
}
