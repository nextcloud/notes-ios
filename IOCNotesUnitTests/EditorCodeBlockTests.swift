// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
import UIKit
@testable import iOCNotes

@Suite("Code blocks in the editor")
struct EditorCodeBlockTests {

    private func applyText(_ text: String) -> NSAttributedString {
        let textStorage = MarkdownTextStorage()

        textStorage.beginEditing()
        textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: text)
        textStorage.endEditing()

        return NSAttributedString(attributedString: textStorage)
    }

    private func font(at string: String, in attributedString: NSAttributedString) -> UIFont? {
        let location = (attributedString.string as NSString).range(of: string).location
        guard location != NSNotFound, location < attributedString.length else { return nil }
        return attributedString.attribute(.font, at: location, effectiveRange: nil) as? UIFont
    }

    private func isMonospaced(_ font: UIFont?) -> Bool {
        guard let font else { return false }
        let expected = UIFont(style: .body, design: .monospaced)
            ?? UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        return font.fontName == expected.fontName
    }

    private func isHeading(_ font: UIFont?) -> Bool {
        guard let font else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.traitBold)
            && font.pointSize > UIFont.preferredFont(forTextStyle: .body).pointSize
    }

    @Test("A hash inside a code block is not a heading")
    func hashInsideCodeBlock() {
        let result = applyText("```\n# not a heading\n```")

        #expect(isMonospaced(font(at: "# not a heading", in: result)))
        #expect(!isHeading(font(at: "# not a heading", in: result)))
    }

    @Test("Text below a fence that is still being typed is already code")
    func unclosedFence() {
        let result = applyText("```swift\n# import Foundation")

        #expect(isMonospaced(font(at: "# import Foundation", in: result)))
        #expect(!isHeading(font(at: "# import Foundation", in: result)))
    }

    @Test("A heading outside a code block stays a heading")
    func headingOutsideCodeBlock() {
        let result = applyText("# A heading\n\n```\n# not a heading\n```")

        #expect(isHeading(font(at: "A heading", in: result)))
        #expect(isMonospaced(font(at: "# not a heading", in: result)))
    }

    @Test("Emphasis inside a code block is left alone")
    func emphasisInsideCodeBlock() {
        let text = "```\n**not bold**\n```"
        let result = applyText(text)
        let location = (text as NSString).range(of: "**not bold**").location
        let attributes = result.attributes(at: location, effectiveRange: nil)

        #expect(isMonospaced(attributes[.font] as? UIFont))
    }
}
