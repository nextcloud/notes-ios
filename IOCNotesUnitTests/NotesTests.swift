// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Peter Hedlund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

@Suite(
    "Notes Management Tests",
    .enabled(
        if: ProcessInfo.processInfo.environment["NOTES_INTEGRATION_TESTS"] == "1",
        "Requires the local Nextcloud test server"
    )
)
class NotesTests {
    var originalServer: String = ""
    var originalUser: String = ""
    var originalPassword: String = ""

    init() {
        // Store original values
        originalServer = KeychainHelper.server
        originalUser = KeychainHelper.username
        originalPassword = KeychainHelper.password

        // Set test values
        KeychainHelper.server = "http://localhost:8080"
        KeychainHelper.username = "nonotes"
        KeychainHelper.password = "password"

        // Clear database
        Note.reset()
    }

    deinit {
        // Restore original values
        KeychainHelper.server = originalServer
        KeychainHelper.username = originalUser
        KeychainHelper.password = originalPassword
    }

    @Test("Add note")
    func addNote() async throws {
        let content = "Note added during test"

        let note = await NoteSessionManager.shared.add(content: content, category: "")

        #expect(note != nil, "Expected note to not be nil")
        #expect(note?.addNeeded == false, "Expected addNeeded to be false")
    }

    @Test("Add note with category")
    func addNoteWithCategory() async throws {
        let content = "Note with category added during test"
        let category = "Test Category"

        let note = await NoteSessionManager.shared.add(content: content, category: category)

        #expect(note != nil, "Expected note to not be nil")
        #expect(note?.addNeeded == false, "Expected addNeeded to be false")
        #expect(note?.category == "Test Category", "Expected the category to be Test Category")
    }

    @Test("Add and delete note")
    func addAndDeleteNote() async throws {
        let content = "Note added and deleted during test"

        let note = await NoteSessionManager.shared.add(content: content, category: "")

        #expect(note != nil, "Expected note to not be nil")
        #expect(note?.addNeeded == false, "Expected addNeeded to be false")

        if let note {
            await NoteSessionManager.shared.delete(note: note)
        }
    }

    @Test("Add and delete note with category")
    func addAndDeleteNoteWithCategory() async throws {
        let content = "Note added and deleted during test"
        let category = "Test Category"

        let note = await NoteSessionManager.shared.add(content: content, category: category)

        #expect(note != nil, "Expected note to not be nil")
        #expect(note?.addNeeded == false, "Expected addNeeded to be false")
        #expect(note?.category == "Test Category", "Expected the category to be Test Category")

        if let note {
            await NoteSessionManager.shared.delete(note: note)
        }
    }

    @Test("Add offline")
    func addOffline() async throws {
        let content = "Note added during offline test"

        KeychainHelper.offlineMode = true

        let note = await NoteSessionManager.shared.add(content: content, category: "")

        #expect(note != nil, "Expected note to not be nil")
        #expect(note?.addNeeded == true, "Expected addNeeded to be true")

        KeychainHelper.offlineMode = false

        await NoteSessionManager.shared.sync()

        if Note.all()?.filter({ $0.addNeeded == true }).count ?? 0 > 0 {
            Issue.record("Expected addNeeded count to be 0")
        }
    }

    @Test("Add and reset")
    func addAndReset() async throws {
        let contents = [
            "Note 1 added during reset test",
            "Note 2 added during reset test",
            "Note 3 added during reset test",
            "Note 4 added during reset test"
        ]

        for content in contents {
            let note = await NoteSessionManager.shared.add(content: content, category: "")

            #expect(note != nil, "Expected note to not be nil")
        }

        Note.reset()

        if Note.all()?.count ?? 0 > 0 {
            Issue.record("Expected note count to be 0")
        }
    }

    @Test("Add and reset with categories")
    func addAndResetWithCategories() async throws {
        let testData = [
            ("Note 1 added during reset test", ""),
            ("Note 2 added during reset test", ""),
            ("Note 3 added during reset test", "A Category"),
            ("Note 4 added during reset test", "A Category")
        ]

        for (content, category) in testData {
            let note = await NoteSessionManager.shared.add(content: content, category: category)

            #expect(note != nil, "Expected note to not be nil")
        }

        Note.reset()

        if Note.all()?.count ?? 0 > 0 {
            Issue.record("Expected note count to be 0")
        }
    }

    @Test("Add and move")
    func addAndMove() async throws {
        let contents = [
            "Note 1 added during add and move test",
            "Note 2 added during add and move test",
            "Note 3 added during add and move test",
            "Note 4 added during add and move test"
        ]

        var notes = [Note]()

        for content in contents {
            let note = await NoteSessionManager.shared.add(content: content, category: "")

            #expect(note != nil, "Expected note to not be nil")

            if let note {
                notes.append(note)
            }
        }

        if notes.count >= 4 {
            for note in [notes[1], notes[3]] {
                note.category = "Add and Move Category"
                await NoteSessionManager.shared.update(note: note)
            }
        }

        if Note.all()?.filter({ $0.category == "Add and Move Category" }).count ?? 0 != 2 {
            Issue.record("Expected category count to be 2")
        }
    }

    @Test("Add and move out")
    func addAndMoveOut() async throws {
        let category = "Test Category Out"

        let contents = [
            "Note 1 added during add and move test",
            "Note 2 added during add and move test",
            "Note 3 added during add and move test",
            "Note 4 added during add and move test"
        ]

        var notes = [Note]()

        for content in contents {
            let note = await NoteSessionManager.shared.add(content: content, category: category)

            #expect(note != nil, "Expected note to not be nil")

            if let note {
                notes.append(note)
            }
        }

        if notes.count >= 4 {
            for note in [notes[1], notes[3]] {
                note.category = ""
                await NoteSessionManager.shared.update(note: note)
            }
        }

        if Note.all()?.filter({ $0.category == "" }).count ?? 0 != 2 {
            Issue.record("Expected category count to be 2")
        }
    }
}
