// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Julian Schneider
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Makes the checkboxes of a note tappable in the preview.
///
/// The preview forbids scripts from note content, so a checkbox cannot report a tap by itself.
/// Every checkbox is therefore wrapped in a link that carries the source line it was rendered from;
/// the preview cancels the navigation and toggles exactly that line. The state the link was
/// rendered with travels along and is verified before anything is written, so a checkbox can never
/// toggle a line other than its own.
enum PreviewCheckBoxes {

    /// The URL scheme of the toggle links.
    static let scheme = "notes-checkbox"

    /// A checkbox of a note: where it stands, how it is shown, and what it says.
    struct CheckBox: Equatable {
        let line: Int
        let checked: Bool
        /// The text of the entry, read out instead of the bare checkbox.
        let label: String
    }

    /// A list entry with a checkbox, indented or not, ordered or not.
    private static let itemExpression = try? NSRegularExpression(
        pattern: #"^[ \t]*(?:[-*+]|\d{1,9}[.)])[ \t]+\[([ xX])\](?=[ \t]|$)[ \t]*(.*)$"#)

    /// A checkbox as swift-markdown renders it.
    private static let inputExpression = try? NSRegularExpression(
        pattern: #"<input type="checkbox" disabled=""( checked="")? />"#)

    /// A line opening or closing a fenced code block.
    private static let codeFenceExpression = try? NSRegularExpression(pattern: #"^ {0,3}(```|~~~)"#)

    /// Every checkbox of `content`, in the order a renderer walks them.
    ///
    /// Checkboxes inside fenced code blocks are not checkboxes and are skipped. Checkboxes inside
    /// quotes are counted like any other, because a renderer renders them too.
    static func checkBoxes(in content: String) -> [CheckBox] {
        var result = [CheckBox]()
        var insideCodeBlock = false
        for (index, line) in MarkdownDocument(content).lines.enumerated() {
            if matches(codeFenceExpression, line) {
                insideCodeBlock.toggle()
                continue
            }
            guard !insideCodeBlock, let item = item(in: line) else {
                continue
            }
            result.append(CheckBox(line: index,
                                   checked: isChecked(line, at: item.state),
                                   label: (line as NSString).substring(with: item.label)))
        }
        return result
    }

    /// Wraps every checkbox in `html` in a link toggling the line of `content` it came from.
    ///
    /// A checkbox is only linked when the state in the HTML matches the state found in the source.
    /// If the two ever disagree the checkbox stays untappable, which is harmless, rather than
    /// pointing at the wrong line.
    static func linkingCheckBoxes(in html: String, of content: String) -> String {
        guard let inputExpression else {
            return html
        }
        let checkBoxes = checkBoxes(in: content)
        let text = html as NSString
        var result = ""
        var position = 0
        var index = 0
        inputExpression.enumerateMatches(in: html, range: NSRange(location: 0, length: text.length)) { match, _, _ in
            guard let match else {
                return
            }
            result += text.substring(with: NSRange(location: position, length: match.range.location - position))
            let input = text.substring(with: match.range)
            if index < checkBoxes.count, checkBoxes[index].checked == input.contains("checked") {
                result += link(for: checkBoxes[index], around: input)
            } else {
                result += input
            }
            position = match.range.location + match.range.length
            index += 1
        }
        result += text.substring(from: position)
        return result
    }

    /// The checkbox a toggle link points at, or `nil` if `url` is not a toggle link.
    static func target(of url: URL) -> CheckBox? {
        guard url.scheme == scheme else {
            return nil
        }
        let parts = url.absoluteString.dropFirst(scheme.count + 1).components(separatedBy: ":")
        guard parts.count == 2, let line = Int(parts[0]) else {
            return nil
        }
        return CheckBox(line: line, checked: parts[1] == "checked", label: "")
    }

    /// Returns `content` with the checkbox at `target` toggled, or `nil` when it no longer matches.
    static func toggling(_ content: String, at target: CheckBox) -> String? {
        var document = MarkdownDocument(content)
        guard document.lines.indices.contains(target.line) else {
            return nil
        }
        let line = document.lines[target.line]
        guard let item = item(in: line), isChecked(line, at: item.state) == target.checked else {
            return nil
        }
        document.lines[target.line] = (line as NSString).replacingCharacters(in: item.state,
                                                                            with: target.checked ? " " : "x")
        return document.content
    }

    /// A checkbox as a link, announced to assistive technology as the checkbox it stands for.
    ///
    /// The input itself is hidden from the accessibility tree: it is disabled and would be read as
    /// an unavailable control, while the link is the element that actually reacts to a tap.
    private static func link(for checkBox: CheckBox, around input: String) -> String {
        let state = checkBox.checked ? "checked" : "open"
        let hiddenInput = input.replacingOccurrences(of: "<input ", with: "<input aria-hidden=\"true\" ")
        return """
            <a class="task-toggle" href="\(scheme):\(checkBox.line):\(state)" \
            role="checkbox" aria-checked="\(checkBox.checked)" aria-label="\(escapingHTML(checkBox.label))">\
            \(hiddenInput)</a>
            """
    }

    private static func escapingHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// The ranges of the state character and of the text of a list entry with a checkbox.
    private static func item(in line: String) -> (state: NSRange, label: NSRange)? {
        guard let itemExpression else {
            return nil
        }
        let text = line as NSString
        guard let match = itemExpression.firstMatch(in: line, range: NSRange(location: 0, length: text.length)) else {
            return nil
        }
        return (match.range(at: 1), match.range(at: 2))
    }

    private static func isChecked(_ line: String, at state: NSRange) -> Bool {
        !(line as NSString).substring(with: state).trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func matches(_ expression: NSRegularExpression?, _ line: String) -> Bool {
        guard let expression else {
            return false
        }
        let text = line as NSString
        return expression.firstMatch(in: line, range: NSRange(location: 0, length: text.length)) != nil
    }
}
