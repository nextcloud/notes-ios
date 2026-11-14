// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 s17sh70x2jfl031ag
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
import UIKit
@testable import iOCNotes

/// Drives the editor's `UITextViewDelegate` the way UIKit does for a single key press.
@MainActor
@Suite("Editor editing")
struct EditorEditingTests {
    private func press(_ replacement: String, at location: Int, in text: String) -> String {
        let textView = UITextView()
        textView.text = text
        let deleting = replacement.isEmpty
        let range = deleting ? NSRange(location: location - 1, length: 1) : NSRange(location: location, length: 0)

        if EditorViewController().textView(textView, shouldChangeTextIn: range, replacementText: replacement) {
            textView.text = (text as NSString).replacingCharacters(in: range, with: replacement)
        }

        return textView.text
    }

    @Test("Backspace at the start of a line after a numbered item keeps that line's text")
    func backspaceKeepsText() {
        let text = "1. foo\nImportant paragraph"
        #expect(press("", at: ("1. foo\n" as NSString).length, in: text) == "1. fooImportant paragraph")
    }

    @Test("Backspace on an empty line after a numbered item still removes it")
    func backspaceRemovesEmptyLine() {
        #expect(press("", at: ("1. foo\n" as NSString).length, in: "1. foo\n") == "1. foo")
    }

    @Test("Renumbering changes the list marker only")
    func renumberingKeepsItemText() {
        let text = "1. milk\n2. buy 2 pears"
        #expect(press("\n", at: ("1. milk" as NSString).length, in: text) == "1. milk\n2. \n3. buy 2 pears")
    }

    @Test("Enter in a numbered list keeps CRLF line breaks")
    func keepsCRLF() {
        let text = "Shopping\r\nmilk\r\n1. eggs"
        #expect(press("\n", at: (text as NSString).length, in: text) == "Shopping\r\nmilk\r\n1. eggs\n2. ")
    }

    @Test("Enter at the end of a list item with emoji continues the list", arguments: ["1. 😀😀", "- 😀😀😀😀", "- [ ] 😀😀"])
    func emojiListItem(text: String) {
        let result = press("\n", at: (text as NSString).length, in: text)
        #expect(result.hasPrefix(text + "\n"))
    }

    @Test("A checkbox is found by its UTF-16 index after emoji")
    func checkBoxAfterEmoji() {
        let text = String(repeating: "Trip 😀😀😀😀😀😀\n", count: 3) + "- [ ] buy milk"
        let bracket = (text as NSString).range(of: "[").location

        #expect(CheckBoxTapHandler.isCheckBoxCharacter(in: text, at: bracket))
        #expect(CheckBoxTapHandler.isCheckBoxCharacter(in: text, at: bracket + 1))
        #expect(!CheckBoxTapHandler.isCheckBoxCharacter(in: text, at: (text as NSString).range(of: "b").location))
        #expect(!CheckBoxTapHandler.isCheckBoxCharacter(in: text, at: 10_000))
    }

    @Test("A first line without spaces still gives a title", arguments: [
        ("https://example.com/some/really/long/path/without/any/spaces.html", "https://example.com/some/really/long/path/without/…"),
        ("Meeting notes for the quarterly planning session with the team", "Meeting notes for the quarterly planning session …"),
        ("Short title", "Short title")
    ])
    func truncate(input: String, expected: String) {
        #expect(input.truncate(length: 50) == expected)
    }

    @Test("The throttler runs while calls keep coming")
    func throttlerRunsDuringContinuousCalls() async {
        let throttler = Throttler(minimumDelay: 0.1)
        var runs = 0

        for _ in 0..<25 {
            throttler.throttle { runs += 1 }
            try? await Task.sleep(nanoseconds: 40_000_000)
        }

        // About one second of calls every 40 ms: the old check never ran the work before the calls stopped.
        #expect(runs >= 4)
    }
}
