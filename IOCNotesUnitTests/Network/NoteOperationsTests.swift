// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    @MainActor
    @Suite("Note operations", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct NoteOperationsTests {
        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        // MARK: Add

        @Test("Adding uploads the note and adopts the server's id, title and etag")
        func add() async throws {
            fixture.server.addNote(title: Constants.newNote, category: "Home")

            let note = try #require(await fixture.manager.add(content: "Groceries\nmilk", category: "Home"))
            let remote = try #require(fixture.server.notes.last)

            #expect(fixture.server.requests("POST", "/notes").count == 1)
            #expect(remote.content == "Groceries\nmilk")
            #expect(note.id == remote.id)
            #expect(note.title == "\(Constants.newNote) (2)")
            #expect(note.etag == remote.etag)
            #expect(!note.addNeeded)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Adding in offline mode keeps the note local without any request")
        func addOffline() async throws {
            KeychainHelper.offlineMode = true

            let note = try #require(await fixture.manager.add(content: "Draft", category: ""))

            #expect(note.addNeeded)
            #expect(fixture.server.requests.isEmpty)
        }

        @Test("Adding locally keeps the note on the device without any request")
        func addLocally() throws {
            let note = try #require(fixture.manager.addLocally(content: "", category: ""))

            #expect(note.addNeeded)
            #expect(note.id == -1)
            #expect(note.title == Constants.newNote)
            #expect(fixture.server.requests.isEmpty)
        }

        @Test("A failed upload keeps the note pending and reports it")
        func addFailure() async throws {
            fixture.server.script("POST", "/notes", .status(500))

            let note = try #require(await fixture.manager.add(content: "Draft", category: ""))

            #expect(note.addNeeded)
            #expect(note.id == -1)
            #expect(fixture.presentedErrors.map(\.title) == [localized("Error Adding Note")])
        }

        // MARK: Update

        @Test("Updating sends the local content and clears the pending flag")
        func update() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "old")
            let note = try fixture.seedSynced(remote)
            note.content = "new"

            await fixture.manager.update(note: note)

            let request = try #require(fixture.server.requests("PUT", "/notes/\(remote.id)").first)

            #expect(request.form["content"] == "new")
            #expect(fixture.server.note(id: remote.id)?.content == "new")
            #expect(!note.updateNeeded)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("A metadata-only update keeps the modification date")
        func favoriteKeepsModified() async throws {
            let remote = fixture.server.addNote(title: "Plan", modified: 1_700_000_000)
            let note = try fixture.seedSynced(remote)
            note.favorite = true

            await fixture.manager.update(note: note, updateModified: false)

            let request = try #require(fixture.server.requests("PUT", "/notes/\(remote.id)").first)

            #expect(request.form["modified"] == "1700000000")
            #expect(request.form["favorite"] == "1")
            #expect(fixture.server.note(id: remote.id)?.favorite == true)
        }

        @Test("Updating a note the server has not seen yet uploads it instead")
        func updatePendingNoteUploads() async throws {
            let note = try fixture.seedLocal(id: -1, content: "Draft", addNeeded: true)

            await fixture.manager.update(note: note)

            #expect(fixture.server.requests.map(\.method) == ["POST"])
            #expect(!note.addNeeded)
            #expect(note.id > 0)
        }

        @Test("A 405 from the server re-creates the note")
        func update405Recreates() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "server")
            let note = try fixture.seedSynced(remote, content: "local")
            fixture.server.script("PUT", "/notes/\(remote.id)", .html(405))

            await fixture.manager.update(note: note)

            #expect(fixture.server.requests("POST", "/notes").first?.form["content"] == "local")
            #expect(!note.addNeeded)
            #expect(note.id != remote.id)
        }

        // MARK: Delete

        @Test("Deleting removes the note on the server and locally")
        func delete() async throws {
            let remote = fixture.server.addNote(title: "Old")
            let note = try fixture.seedSynced(remote)

            await fixture.manager.delete(note: note)

            #expect(fixture.server.note(id: remote.id) == nil)
            #expect(fixture.localNote(id: remote.id) == nil)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Deleting a note the server no longer has is silent")
        func delete404() async throws {
            let note = try fixture.seedLocal(id: 42)

            await fixture.manager.delete(note: note)

            #expect(fixture.server.requests("DELETE", "/notes/42").count == 1)
            #expect(fixture.localNote(id: 42) == nil)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("A locked note is retried twice, then removed locally with one message")
        func deleteLocked() async throws {
            let remote = fixture.server.addNote(title: "Locked")
            let note = try fixture.seedSynced(remote)
            fixture.server.script("DELETE", "/notes/\(remote.id)", times: 3, .status(423))

            await fixture.manager.delete(note: note)

            #expect(fixture.server.requests("DELETE", "/notes/\(remote.id)").count == 3)
            #expect(fixture.localNote(id: remote.id) == nil)
            #expect(fixture.presentedErrors.map(\.body) == [localized("Unable to delete locked file on server")])
        }

        @Test("Deleting a note that was never uploaded needs no request")
        func deletePendingAdd() async throws {
            let note = try fixture.seedLocal(id: -1, addNeeded: true)
            let guid = try #require(note.guid)

            await fixture.manager.delete(note: note)

            #expect(fixture.server.requests.isEmpty)
            #expect(fixture.localNote(guid: guid) == nil)
        }

        // MARK: Get

        @Test("Fetching a changed note updates it locally")
        func getChanged() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "old")
            let note = try fixture.seedSynced(remote)
            fixture.server.editNote(id: remote.id) { $0.content = "new" }

            await fixture.manager.get(note: note)

            #expect(note.content == "new")
        }

        @Test("A rejected single-note request is silent")
        func getBadRequest() async throws {
            let remote = fixture.server.addNote(title: "Plan")
            let note = try fixture.seedSynced(remote)
            fixture.server.script("GET", "/notes/\(remote.id)", .status(400))

            await fixture.manager.get(note: note)

            #expect(fixture.presentedErrors.isEmpty)
        }
    }
}
