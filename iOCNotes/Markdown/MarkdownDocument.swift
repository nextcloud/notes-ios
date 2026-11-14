// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Julian Schneider
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A note split into lines, remembering how the lines were separated.
///
/// Notes are edited on other platforms too, so the line endings of a note have to survive a round
/// trip: content containing `\r\n` is split at and rejoined with `\r\n`, everything else with `\n`.
struct MarkdownDocument {

    /// The separator the content was split at and is joined with again.
    let lineSeparator: String

    /// The lines of the note, without their separator.
    var lines: [String]

    init(_ content: String) {
        lineSeparator = content.contains("\r\n") ? "\r\n" : "\n"
        lines = content.components(separatedBy: lineSeparator)
    }

    /// The lines joined back into note content.
    var content: String {
        lines.joined(separator: lineSeparator)
    }
}
