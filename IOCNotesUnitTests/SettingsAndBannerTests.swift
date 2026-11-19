// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

@Suite("File extension")
struct FileSuffixTests {

    @Test("Known and custom extensions are accepted and normalized", arguments: [
        (".md", ".md"),
        ("md", ".md"),
        (".MD", ".md"),
        ("org", ".org"),
        ("  .markdown  ", ".markdown"),
        (".txt", ".txt")
    ])
    func accepts(input: String, expected: String) {
        #expect(FileSuffix(validating: input)?.suffix == expected)
    }

    @Test("Anything that is not a plain extension is rejected", arguments: [
        "",
        " ",
        ".",
        "..md",
        "md/../evil",
        "a b",
        "m-d",
        ".abcdefghijklmnopqrstuvwxyz"
    ])
    func rejects(input: String) {
        #expect(FileSuffix(validating: input) == nil)
    }

    @Test("The two named extensions are known, everything else is not")
    func known() throws {
        #expect(FileSuffix.md.isKnown)
        #expect(FileSuffix.txt.isKnown)
        #expect(try #require(FileSuffix(validating: ".org")).isKnown == false)
    }
}

@Suite("Error banner policy")
struct ErrorBannerPolicyTests {
    private let failure = ErrorMessage(title: "Error Updating Note", body: "The request timed out.")
    private let other = ErrorMessage(title: "Error Syncing Notes", body: "The server is unreachable.")
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("The first failure is shown")
    func firstFailure() {
        var policy = ErrorBannerPolicy()

        let appears = policy.shouldShow(failure, at: now)

        #expect(appears)
    }

    @Test("The same failure right afterwards is dropped so it cannot cover the editor")
    func repeatedFailure() {
        var policy = ErrorBannerPolicy()

        let first = policy.shouldShow(failure, at: now)
        let immediately = policy.shouldShow(failure, at: now.addingTimeInterval(1))
        let nearTheEnd = policy.shouldShow(failure, at: now.addingTimeInterval(policy.repeatInterval - 1))

        #expect(first)
        #expect(!immediately)
        #expect(!nearTheEnd)
    }

    @Test("The same failure is shown again once the quiet time is over")
    func failureAfterQuietTime() {
        var policy = ErrorBannerPolicy()

        let first = policy.shouldShow(failure, at: now)
        let later = policy.shouldShow(failure, at: now.addingTimeInterval(policy.repeatInterval + 1))

        #expect(first)
        #expect(later)
    }

    @Test("A different failure is always worth showing")
    func differentFailure() {
        var policy = ErrorBannerPolicy()

        let first = policy.shouldShow(failure, at: now)
        let different = policy.shouldShow(other, at: now)

        #expect(first)
        #expect(different)
    }
}

@Suite("Server version display", .serialized)
struct ServerVersionDisplayTests {

    @Test("The version reported by the capabilities is shown")
    func fromCapabilities() {
        let previous = (KeychainHelper.serverMajorVersion, KeychainHelper.serverMinorVersion, KeychainHelper.serverMicroVersion)
        defer {
            KeychainHelper.serverMajorVersion = previous.0
            KeychainHelper.serverMinorVersion = previous.1
            KeychainHelper.serverMicroVersion = previous.2
        }

        KeychainHelper.serverMajorVersion = 32
        KeychainHelper.serverMinorVersion = 0
        KeychainHelper.serverMicroVersion = 3

        #expect(KeychainHelper.serverVersion == "32.0.3")
    }

    @Test("Without capabilities the product version of the status endpoint is shown")
    func fromStatus() {
        let previous = (KeychainHelper.serverMajorVersion, KeychainHelper.productVersion)
        defer {
            KeychainHelper.serverMajorVersion = previous.0
            KeychainHelper.productVersion = previous.1
        }

        KeychainHelper.serverMajorVersion = 0
        KeychainHelper.productVersion = "31.0.5"

        #expect(KeychainHelper.serverVersion == "31.0.5")
    }
}

@Suite("Note titles", .serialized)
struct NoteTitleTests {

    private func note(content: String, title: String = Constants.newNote) -> NoteStruct {
        var note = NoteStruct(content: content, category: "")
        note.title = title
        return note
    }

    @Test("A new note is named after its first line")
    func firstLine() {
        #expect(noteTitle(note(content: "Groceries\nMilk")) == "Groceries")
    }

    @Test("Blank lines before the first line are skipped")
    func skipsBlankLines() {
        #expect(noteTitle(note(content: "\n\nGroceries")) == "Groceries")
    }

    @Test("Characters a file name cannot contain are removed")
    func removesForbiddenCharacters() {
        #expect(noteTitle(note(content: "a/b\\c:d?e")) == "abcde")
    }

    @Test("A long first line is shortened")
    func truncates() {
        let title = noteTitle(note(content: "https://example.com/some/really/long/path/without/any/spaces.html"))
        #expect(title.hasSuffix("…"))
    }

    @Test("Whitespace only content keeps the name the note has")
    func keepsTitleForBlankContent() {
        #expect(noteTitle(note(content: "   \n\t")) == Constants.newNote)
    }

    @Test("An existing title of an unchanged note is not derived from its content")
    func keepsExistingTitle() {
        #expect(noteTitle(note(content: "First line", title: "A name that is long enough to stay as it is, unchanged")) == "A name that is long enough to stay as it is, unchanged")
    }

    @Test("Taking the title from the first line is on by default and follows the setting")
    func titleSetting() {
        let key = "UseFirstLineAsTitle"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        #expect(KeychainHelper.useFirstLineAsTitle)

        KeychainHelper.useFirstLineAsTitle = false
        #expect(!KeychainHelper.useFirstLineAsTitle)
    }
}
