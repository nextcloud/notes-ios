// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Julian Schneider
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

@Suite("Tappable Checkboxes In The Preview")
struct PreviewCheckBoxesTests {

    @Test("Every checkbox is found, including indented and quoted ones")
    func findsCheckBoxes() {
        let content = """
        # List

        - [ ] Bread
        - [x] Milk
          - [ ] Whole milk
        > - [x] Quoted

        ```
        - [ ] In a code block
        ```
        """

        let checkBoxes = PreviewCheckBoxes.checkBoxes(in: content)

        #expect(checkBoxes.map(\.line) == [2, 3, 4])
        #expect(checkBoxes.map(\.checked) == [false, true, false])
        #expect(checkBoxes.map(\.label) == ["Bread", "Milk", "Whole milk"])
    }

    @Test("A checkbox in a fenced code block is not a checkbox")
    func ignoresCodeBlocks() {
        #expect(PreviewCheckBoxes.checkBoxes(in: "```\n- [ ] Leave alone\n```").isEmpty)
    }

    @Test("Rendered checkboxes are wrapped in links carrying their source line")
    func wrapsCheckBoxesInLinks() {
        let html = MarkdownRenderer.html(from: "- [ ] Bread\n- [x] Milk", tappableCheckBoxes: true)

        #expect(html.contains("href=\"notes-checkbox:0:open\""))
        #expect(html.contains("href=\"notes-checkbox:1:checked\""))
        #expect(html.contains("class=\"task-toggle\""))
    }

    @Test("A linked checkbox is announced as the checkbox it stands for")
    func describesCheckBoxesForAssistiveTechnology() {
        let html = MarkdownRenderer.html(from: "- [x] Milk & \"cream\"", tappableCheckBoxes: true)

        #expect(html.contains("role=\"checkbox\""))
        #expect(html.contains("aria-checked=\"true\""))
        #expect(html.contains("aria-label=\"Milk &amp; &quot;cream&quot;\""))
        #expect(html.contains("<input aria-hidden=\"true\""), "The disabled input must not be announced")
    }

    @Test("Without the option the rendered HTML is unchanged")
    func leavesCheckBoxesAloneByDefault() {
        let html = MarkdownRenderer.html(from: "- [ ] Bread")

        #expect(html.contains("<input type=\"checkbox\""))
        #expect(!html.contains("task-toggle"))
    }

    @Test("A toggle link is parsed back into its checkbox")
    func parsesToggleLinks() {
        #expect(PreviewCheckBoxes.target(of: URL(string: "notes-checkbox:7:checked")!)
                == .init(line: 7, checked: true, label: ""))
        #expect(PreviewCheckBoxes.target(of: URL(string: "notes-checkbox:0:open")!)
                == .init(line: 0, checked: false, label: ""))
        #expect(PreviewCheckBoxes.target(of: URL(string: "https://nextcloud.com")!) == nil)
    }

    @Test("Toggling changes exactly the line the link points at")
    func togglesTheRightLine() {
        let content = "- [ ] Bread\n- [ ] Bread\n- [x] Milk"

        #expect(PreviewCheckBoxes.toggling(content, at: .init(line: 1, checked: false, label: ""))
                == "- [ ] Bread\n- [x] Bread\n- [x] Milk")
        #expect(PreviewCheckBoxes.toggling(content, at: .init(line: 2, checked: true, label: ""))
                == "- [ ] Bread\n- [ ] Bread\n- [ ] Milk")
    }

    @Test("A link whose state no longer matches the note changes nothing")
    func refusesStaleToggles() {
        #expect(PreviewCheckBoxes.toggling("- [x] Bread", at: .init(line: 0, checked: false, label: "")) == nil)
        #expect(PreviewCheckBoxes.toggling("- [x] Bread", at: .init(line: 9, checked: true, label: "")) == nil)
    }

    @Test("Windows line endings survive toggling")
    func preservesWindowsLineEndings() {
        #expect(PreviewCheckBoxes.toggling("- [ ] Bread\r\n- [ ] Milk", at: .init(line: 0, checked: false, label: ""))
                == "- [x] Bread\r\n- [ ] Milk")
    }
}
