// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import iOCNotes

@Suite("String HTML Stripper Tests")
struct StringHTMLStripperTests {
    @Test("Strips HTML tags and active blocks")
    func stripsHTMLTagsAndActiveBlocks() {
        let input = """
        <h1>Meeting</h1><script>alert(1)</script><style>h1{color:red}</style><p>Notes</p>
        """

        let stripped = input.strippingHTML()

        #expect(stripped == "Meeting Notes")
    }

    @Test("Strips title-breakout payload to plain text")
    func stripsTitleBreakoutPayloadToPlainText() {
        let input = "Weekly</title><script>new Image().src='https://attacker/x'</script><title>Report"

        let stripped = input.strippingHTML()

        #expect(stripped == "Weekly Report")
    }

    @Test("Leaves plain text untouched")
    func leavesPlainTextUntouched() {
        let input = "Simple title 123"
        #expect(input.strippingHTML() == input)
    }
}
