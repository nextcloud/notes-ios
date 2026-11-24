// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// The Markdown edits behind the editor's formatting bar, on plain text so they can be tested without UIKit.
///
/// The syntax follows what Nextcloud Text writes, so notes look the same in both editors.
///
enum MarkdownFormatter {
    struct Edit: Equatable {
        let range: NSRange
        let replacement: String
        /// In the edited text.
        let selection: NSRange
    }

    enum LineStyle {
        case bullet
        case checkbox
        case ordered
    }

    struct LineState: Equatable {
        var heading: Int?
        var list: LineStyle?
        var isQuote = false
    }

    /// Matches the example notes in `Server/Notes`.
    static let indentUnit = "    "

    // MARK: - Inline

    static func toggleBold(in text: String, selection: NSRange) -> Edit {
        toggleEmphasis(width: 2, in: text, selection: selection)
    }

    static func toggleItalic(in text: String, selection: NSRange) -> Edit {
        toggleEmphasis(width: 1, in: text, selection: selection)
    }

    ///
    /// The length of an asterisk run decides what is active: 1 is italic, 2 is bold, 3 is both.
    ///
    private static func toggleEmphasis(width: Int, in text: String, selection: NSRange) -> Edit {
        let string = text as NSString
        let selected = string.substring(with: selection)
        let marker = String(repeating: "*", count: width)
        let isActive = { (run: Int) in run == width || run >= 3 }

        // Markers selected along with the text, e.g. "**bold**".
        let inner = min(leadingAsterisks(of: selected), trailingAsterisks(of: selected))
        if inner > 0, selection.length > 2 * inner {
            guard isActive(inner) else {
                return wrap(selection, of: string, with: marker)
            }

            let content = (selected as NSString).substring(with: NSRange(location: width, length: selection.length - 2 * width))
            return Edit(range: selection, replacement: content, selection: NSRange(location: selection.location, length: (content as NSString).length))
        }

        // Markers right around the selection.
        let before = trailingAsterisks(of: string.substring(to: selection.location))
        let after = leadingAsterisks(of: string.substring(from: NSMaxRange(selection)))
        if isActive(min(before, after)) {
            let range = NSRange(location: selection.location - width, length: selection.length + 2 * width)
            return Edit(range: range, replacement: selected, selection: NSRange(location: range.location, length: selection.length))
        }

        return wrap(selection, of: string, with: marker)
    }

    /// For markers that cannot be confused with each other: `__`, `~~`, `==` and `$`.
    static func toggleWrap(_ marker: String, in text: String, selection: NSRange) -> Edit {
        let string = text as NSString
        let selected = string.substring(with: selection)
        let width = (marker as NSString).length

        if selection.length > 2 * width, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let content = (selected as NSString).substring(with: NSRange(location: width, length: selection.length - 2 * width))
            return Edit(range: selection, replacement: content, selection: NSRange(location: selection.location, length: (content as NSString).length))
        }

        let around = NSRange(location: selection.location - width, length: selection.length + 2 * width)
        if around.location >= 0, NSMaxRange(around) <= string.length,
           string.substring(with: NSRange(location: around.location, length: width)) == marker,
           string.substring(with: NSRange(location: NSMaxRange(selection), length: width)) == marker {
            return Edit(range: around, replacement: selected, selection: NSRange(location: around.location, length: selection.length))
        }

        return wrap(selection, of: string, with: marker)
    }

    private static func wrap(_ selection: NSRange, of string: NSString, with marker: String) -> Edit {
        let selected = string.substring(with: selection)
        let width = (marker as NSString).length

        return Edit(range: selection,
                    replacement: marker + selected + marker,
                    selection: NSRange(location: selection.location + width, length: selection.length))
    }

    private static func leadingAsterisks(of string: String) -> Int {
        string.prefix { $0 == "*" }.count
    }

    private static func trailingAsterisks(of string: String) -> Int {
        string.reversed().prefix { $0 == "*" }.count
    }

    /// The selection becomes the link text, without one the URL does.
    static func insertLink(_ url: String, in text: String, selection: NSRange) -> Edit {
        let selected = (text as NSString).substring(with: selection)
        let replacement = "[\(selected.isEmpty ? url : selected)](\(url))"

        return Edit(range: selection, replacement: replacement, selection: NSRange(location: selection.location + (replacement as NSString).length, length: 0))
    }

    // MARK: - Lines

    ///
    /// Removes the style when all selected lines already have it. Blank lines only change when they are the only line.
    ///
    static func toggleLineStyle(_ style: LineStyle, in text: String, selection: NSRange) -> Edit {
        transformLines(in: text, selection: selection) { strings in
            let lines = strings.map(ListLine.init)
            let changes = { (line: ListLine) in !line.isBlank || lines.count == 1 }
            let isRemoving = lines.filter(changes).allSatisfy { $0.style == style }
            var number = 0

            return lines.map { line in
                guard changes(line) else { return line.string }

                var line = line
                number += 1

                switch (isRemoving, style) {
                    case (true, _):
                        line.marker = ""
                    case (false, .bullet):
                        line.marker = "\(line.bullet) "
                    case (false, .checkbox):
                        line.marker = "\(line.bullet) [ ] "
                    case (false, .ordered):
                        line.marker = "\(number). "
                }

                return line.string
            }
        }
    }

    /// Choosing the current level again turns the heading back into a paragraph.
    static func toggleHeading(_ level: Int, in text: String, selection: NSRange) -> Edit {
        transformLines(in: text, selection: selection) { lines in
            let changes = { (line: String) in !isBlank(line) || lines.count == 1 }
            let isRemoving = lines.filter(changes).allSatisfy { headingLevel(of: $0) == level }

            return lines.map { line in
                guard changes(line) else { return line }

                let content = line.replacing(#/^#{1,6}[ \t]+/#, with: "")
                return isRemoving ? content : String(repeating: "#", count: level) + " " + content
            }
        }
    }

    static func toggleQuote(in text: String, selection: NSRange) -> Edit {
        transformLines(in: text, selection: selection) { lines in
            let changes = { (line: String) in !isBlank(line) || lines.count == 1 }
            let isRemoving = lines.filter(changes).allSatisfy { $0.hasPrefix(">") }

            return lines.map { line in
                guard changes(line) else { return line }

                return isRemoving ? line.replacing(#/^>[ \t]?/#, with: "") : "> " + line
            }
        }
    }

    static func indent(in text: String, selection: NSRange) -> Edit {
        transformLines(in: text, selection: selection) { lines in
            lines.map { isBlank($0) ? $0 : indentUnit + $0 }
        }
    }

    /// Removes a tab or up to one ``indentUnit`` of spaces.
    static func outdent(in text: String, selection: NSRange) -> Edit {
        transformLines(in: text, selection: selection) { lines in
            lines.map { line in
                if line.hasPrefix("\t") {
                    return String(line.dropFirst())
                }

                let spaces = line.prefix { $0 == " " }.count
                return String(line.dropFirst(min(spaces, indentUnit.count)))
            }
        }
    }

    /// The state of the line the selection starts in, for highlighting the bar's buttons.
    static func lineState(in text: String, selection: NSRange) -> LineState {
        let string = text as NSString
        let line = string.substring(with: lineRange(of: string, for: NSRange(location: selection.location, length: 0)))

        return LineState(heading: headingLevel(of: line),
                         list: ListLine(line).style,
                         isQuote: line.trimmingCharacters(in: .whitespaces).hasPrefix(">"))
    }

    private static func headingLevel(of line: String) -> Int? {
        line.firstMatch(of: #/^(#{1,6})[ \t]+/#).map { $0.1.count }
    }

    private static func isBlank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private struct ListLine {
        var indentation: String
        var marker: String
        var content: String

        /// Indentation, then a bullet with an optional checkbox or a number, then the text.
        private static let pattern = try! NSRegularExpression(pattern: "^([ \\t]*)((?:[-*+][ \\t]+(?:\\[[ xX]\\](?:[ \\t]+|$))?|\\d+\\.[ \\t]+)?)(.*)$")

        init(_ string: String) {
            let range = NSRange(location: 0, length: (string as NSString).length)
            let match = Self.pattern.firstMatch(in: string, range: range)!
            let part = { (index: Int) in (string as NSString).substring(with: match.range(at: index)) }

            indentation = part(1)
            marker = part(2)
            content = part(3)
        }

        var string: String { indentation + marker + content }

        var isBlank: Bool { marker.isEmpty && content.trimmingCharacters(in: .whitespaces).isEmpty }

        var style: LineStyle? {
            if marker.contains("[") { return .checkbox }
            if let first = marker.first, first.isNumber { return .ordered }
            if marker.isEmpty { return nil }
            return .bullet
        }

        /// Keeps `*` and `+` bullets when changing the style.
        var bullet: Character {
            if let first = marker.first, "-*+".contains(first) { return first }
            return "-"
        }
    }

    // MARK: - Blocks

    /// Puts the selected lines between an opening and a closing line, e.g. a code fence.
    static func wrapLines(open: String, close: String, in text: String, selection: NSRange) -> Edit {
        let string = text as NSString
        let range = lineRange(of: string, for: selection)
        let content = string.substring(with: range)
        let caret = range.location + (open as NSString).length + 1 + (content as NSString).length

        return Edit(range: range, replacement: open + "\n" + content + "\n" + close, selection: NSRange(location: caret, length: 0))
    }

    /// Three columns with a header row, like a new table in Nextcloud Text.
    static func insertTable(in text: String, selection: NSRange) -> Edit {
        let string = text as NSString
        let range = lineRange(of: string, for: selection)
        let lines = string.substring(with: range)
        let before = isBlank(lines) ? "" : lines + "\n\n"
        let table = "|  |  |  |\n| --- | --- | --- |\n|  |  |  |"

        return Edit(range: range, replacement: before + table, selection: NSRange(location: range.location + (before as NSString).length + 2, length: 0))
    }

    // MARK: - Helpers

    /// The lines touched by the selection, without the final line break which belongs to the next line.
    private static func lineRange(of string: NSString, for selection: NSRange) -> NSRange {
        var range = string.lineRange(for: selection)

        if range.length > 0, string.character(at: NSMaxRange(range) - 1) == 0x0A {
            range.length -= 1
        }

        return range
    }

    /// Indentation, heading or quote, and list marker: everything a line edit may change.
    private static let markupPrefix = try! NSRegularExpression(pattern: "^[ \\t]*(?:#{1,6}[ \\t]+|>[ \\t]?)?[ \\t]*(?:[-*+][ \\t]+(?:\\[[ xX]\\](?:[ \\t]+|$))?|\\d+\\.[ \\t]+)?")

    private static func markupPrefixLength(of line: String) -> Int {
        markupPrefix.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))?.range.length ?? 0
    }

    /// A caret keeps its place in the line's text, a selection grows to cover all changed lines.
    private static func transformLines(in text: String, selection: NSRange, _ transform: ([String]) -> [String]) -> Edit {
        let string = text as NSString
        let range = lineRange(of: string, for: selection)
        let oldLines = string.substring(with: range).components(separatedBy: "\n")
        let newLines = transform(oldLines)
        let replacement = newLines.joined(separator: "\n")

        guard selection.length == 0, let old = oldLines.first, let new = newLines.first else {
            return Edit(range: range, replacement: replacement, selection: NSRange(location: range.location, length: (replacement as NSString).length))
        }

        let oldPrefix = markupPrefixLength(of: old)
        let newPrefix = markupPrefixLength(of: new)
        let column = selection.location - range.location
        let newColumn = column < oldPrefix ? newPrefix : column - oldPrefix + newPrefix

        return Edit(range: range, replacement: replacement, selection: NSRange(location: range.location + newColumn, length: 0))
    }
}
