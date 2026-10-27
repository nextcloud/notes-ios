// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    ///
    /// Pins verified sync bugs so they cannot return.
    ///
    @MainActor
    @Suite("Sync bug fixes", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct SyncBugFixTests {
        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        /// Lets the list request see both notes as unchanged `{id}` stubs.
        private func pruneEverything() {
            KeychainHelper.eTag = "\"previous\""
            KeychainHelper.lastModified = fixture.server.now + 1
        }

        // MARK: Pending deletes

        @Test("A failed delete is not reversed by a stub for that note")
        func pendingDeleteSurvivesStub() async throws {
            let doomed = fixture.server.addNote(title: "Doomed")
            let other = fixture.server.addNote(title: "Other")
            try fixture.seedSynced(doomed, deleteNeeded: true)
            try fixture.seedSynced(other)
            fixture.server.script("DELETE", "/notes/\(doomed.id)", .status(500))
            pruneEverything()

            await fixture.manager.sync()

            #expect(fixture.server.requests("GET", "/notes").count == 1)
            #expect(fixture.localNote(id: doomed.id)?.deleteNeeded == true)
        }

        @Test("A failed delete is not reversed by a full copy of that note")
        func pendingDeleteSurvivesFullNote() async throws {
            let doomed = fixture.server.addNote(title: "Doomed")
            try fixture.seedSynced(doomed, deleteNeeded: true)
            fixture.server.script("DELETE", "/notes/\(doomed.id)", .status(500))

            await fixture.manager.sync()

            #expect(fixture.localNote(id: doomed.id)?.deleteNeeded == true)
        }

        // MARK: Empty accounts

        @Test("An account without notes needs one request per sync")
        func emptyAccount() async {
            await fixture.manager.sync()
            await fixture.manager.sync()

            #expect(fixture.server.statuses("GET", "/notes") == [200, 304])
        }

        // MARK: Duplicate uploads

        @Test("Overlapping syncs upload each new note once")
        func overlappingSyncs() async throws {
            try fixture.seedLocal(id: -1, content: "First", addNeeded: true)
            try fixture.seedLocal(id: -1, content: "Second", addNeeded: true)
            fixture.server.script("POST", "/notes", .delay(.seconds(1)))

            let manager = fixture.manager
            let first = Task { await manager.sync() }
            try await fixture.waitForRequest("POST", "/notes")
            let second = Task { await manager.sync() }

            await first.value
            await second.value

            #expect(fixture.server.requests("POST", "/notes").count == 2)
            #expect(fixture.server.notes.map(\.content).sorted() == ["First", "Second"])
        }

        @Test("An edit made while the note is uploading is pushed after the upload, not uploaded twice")
        func editDuringUpload() async throws {
            let draft = try fixture.seedLocal(id: -1, content: "Draft", addNeeded: true)
            fixture.server.script("POST", "/notes", .delay(.seconds(1)))

            let manager = fixture.manager
            let sync = Task { await manager.sync() }
            try await fixture.waitForRequest("POST", "/notes")
            draft.content = "Draft, edited"
            await manager.update(note: draft)
            await sync.value

            #expect(fixture.server.requests("POST", "/notes").count == 1)
            #expect(fixture.server.requests("PUT", "/notes/-1").isEmpty)
            #expect(fixture.server.notes.map(\.content) == ["Draft, edited"])
            #expect(draft.content == "Draft, edited")
            #expect(!draft.updateNeeded)
        }

        @Test("A note deleted while a sync is uploading another one is skipped")
        func deleteDuringUpload() async throws {
            let first = try fixture.seedLocal(id: -1, content: "First", addNeeded: true)
            let second = try fixture.seedLocal(id: -1, content: "Second", addNeeded: true)
            fixture.server.script("POST", "/notes", .delay(.seconds(1)))

            let manager = fixture.manager
            let sync = Task { await manager.sync() }
            try await fixture.waitForRequest("POST", "/notes")
            let inFlight = try #require(fixture.server.requests("POST", "/notes").first?.form["content"])
            await manager.delete(note: inFlight == "First" ? second : first)
            await sync.value

            #expect(fixture.server.requests("POST", "/notes").count == 1)
            #expect(fixture.localNotes.map(\.content) == [inFlight])
        }

        @Test("A note deleted while its own upload is in flight is removed on the server too")
        func deleteOwnUploadInFlight() async throws {
            let draft = try fixture.seedLocal(id: -1, content: "Draft", addNeeded: true)
            fixture.server.script("POST", "/notes", .delay(.seconds(1)))

            let manager = fixture.manager
            let sync = Task { await manager.sync() }
            try await fixture.waitForRequest("POST", "/notes")
            await manager.delete(note: draft)
            await sync.value

            #expect(fixture.server.notes.isEmpty)
            #expect(fixture.localNotes.isEmpty)
        }

        // MARK: Read-only notes

        @Test("The server's read-only flag is decoded by the list and by single-note requests")
        func readOnlyDecoded() async throws {
            let shared = fixture.server.addNote(title: "Shared", readOnly: true)

            await fixture.manager.sync()

            #expect(fixture.localNote(id: shared.id)?.readOnly == true)

            let stale = try #require(fixture.localNote(id: shared.id))
            stale.readOnly = false
            stale.etag = ""
            await fixture.manager.get(note: stale)

            #expect(stale.readOnly)
        }

        @Test("A rejected edit of a read-only note is dropped with one message")
        func readOnlyEditRejected() async throws {
            let shared = fixture.server.addNote(title: "Shared", content: "theirs", readOnly: true)
            var stale = shared
            stale.readOnly = false
            let note = try fixture.seedSynced(stale)
            note.content = "mine"

            await fixture.manager.update(note: note)

            #expect(fixture.presentedErrors.map(\.body) == [localized("This note is read-only. Your changes were not saved.")])
            #expect(!note.updateNeeded)
            #expect(note.content == "theirs")
            #expect(note.readOnly)
        }

        @Test("A rejected edit is undone even when the local copy matched the server's")
        func writeProtectedEditRestored() async throws {
            let shared = fixture.server.addNote(title: "Shared", content: "theirs", writeProtected: true)
            let note = try fixture.seedSynced(shared)
            note.content = "mine"

            await fixture.manager.update(note: note)

            let restore = try #require(fixture.server.requests("GET", "/notes/\(shared.id)").first)

            #expect(restore.header("If-None-Match") == nil)
            #expect(restore.status == 200)
            #expect(note.content == "theirs")
            #expect(!note.updateNeeded)
            #expect(fixture.presentedErrors.map(\.body) == [localized("This note is read-only. Your changes were not saved.")])
        }

        @Test("A rejected delete of a read-only note shows it again")
        func readOnlyDeleteRejected() async throws {
            let shared = fixture.server.addNote(title: "Shared", readOnly: true)
            var stale = shared
            stale.readOnly = false
            let note = try fixture.seedSynced(stale)

            await fixture.manager.delete(note: note)

            #expect(fixture.presentedErrors.map(\.body) == [localized("This note is read-only and cannot be deleted.")])
            #expect(fixture.localNote(id: shared.id)?.deleteNeeded == false)
            #expect(fixture.server.note(id: shared.id) != nil)
        }

        @Test("Only the favorite flag is sent for a read-only note")
        func readOnlyFavoriteOnly() async throws {
            let shared = fixture.server.addNote(title: "Shared", readOnly: true)
            let note = try fixture.seedSynced(shared)
            note.favorite = true

            await fixture.manager.update(note: note, updateModified: false)

            let request = try #require(fixture.server.requests("PUT", "/notes/\(shared.id)").first)

            #expect(Array(request.form.keys) == ["favorite"])
            #expect(fixture.server.note(id: shared.id)?.favorite == true)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Placeholder content of an unreadable note never replaces the local text")
        func unreadableNoteKeepsContent() async throws {
            let broken = fixture.server.addNote(title: "Broken", content: "real text")
            try fixture.seedSynced(broken)
            fixture.server.editNote(id: broken.id) { note in
                note.content = "Error: Exception"
                note.error = true
                note.readOnly = true
            }

            await fixture.manager.sync()

            let note = try #require(fixture.localNote(id: broken.id))

            #expect(note.content == "real text")
            #expect(note.error)
            #expect(note.readOnly)
        }

        // MARK: Conditional single-note requests

        @Test("Opening an unchanged note is answered with 304")
        func singleNoteNotModified() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "same")
            let note = try fixture.seedSynced(remote)

            await fixture.manager.get(note: note)

            let request = try #require(fixture.server.requests("GET", "/notes/\(remote.id)").first)

            #expect(request.header("If-None-Match") == "\"\(remote.etag)\"")
            #expect(request.status == 304)
            #expect(note.content == "same")
        }

        @Test("A note's etag is kept by list syncs and uploads")
        func etagKept() async throws {
            let remote = fixture.server.addNote(title: "Listed")

            await fixture.manager.sync()

            #expect(fixture.localNote(id: remote.id)?.etag == remote.etag)

            let added = try #require(await fixture.manager.add(content: "Added", category: ""))

            #expect(added.etag == fixture.server.note(id: added.id)?.etag)
        }

        // MARK: Notes deleted on the server

        @Test("An edit to a note deleted on the server re-creates it")
        func editWinsOverRemoteDelete() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "theirs")
            let note = try fixture.seedSynced(remote, content: "my edit", updateNeeded: true)
            fixture.server.removeNote(id: remote.id)

            await fixture.manager.sync()

            let recreated = try #require(fixture.server.notes.first)

            #expect(recreated.content == "my edit")
            #expect(note.id == recreated.id)
            #expect(!note.addNeeded)
            #expect(fixture.localNotes.count == 1)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("A late 404 for an older upload does not re-create the note a second time")
        func lateNotFoundAfterRecreate() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "theirs")
            let note = try fixture.seedSynced(remote, content: "my edit")
            fixture.server.removeNote(id: remote.id)
            fixture.server.script("PUT", "/notes/\(remote.id)", .delay(.seconds(1)))

            let manager = fixture.manager
            let first = Task { await manager.update(note: note) }
            try await fixture.waitForRequest("PUT", "/notes/\(remote.id)")
            note.content = "my newer edit"
            await manager.update(note: note)
            await first.value

            #expect(fixture.server.requests("POST", "/notes").count == 1)
            #expect(fixture.server.notes.map(\.content) == ["my newer edit"])
            #expect(fixture.localNotes.map(\.id) == fixture.server.notes.map(\.id))
        }

        @Test("Opening a clean note deleted on the server neither re-creates nor deletes it")
        func openRemotelyDeletedNote() async throws {
            let remote = fixture.server.addNote(title: "Gone")
            let note = try fixture.seedSynced(remote)
            fixture.server.removeNote(id: remote.id)

            await fixture.manager.get(note: note)

            #expect(fixture.server.requests("POST", "/notes").isEmpty)
            #expect(fixture.localNote(id: remote.id) != nil)
        }

        @Test("A 404 page from the server core does not re-create notes")
        func corePageNotFound() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "theirs")
            let note = try fixture.seedSynced(remote)
            note.content = "mine"
            fixture.server.script("PUT", "/notes/\(remote.id)", .html(404))

            await fixture.manager.update(note: note)

            #expect(fixture.server.requests("POST", "/notes").isEmpty)
            #expect(fixture.presentedErrors.map(\.title) == [localized("Error Updating Note")])
        }

        // MARK: Slow list requests

        @Test("A note uploaded while the list is loading is not deleted by that older list")
        func slowListKeepsNewNote() async throws {
            fixture.server.addNote(title: "Existing")
            fixture.server.script("GET", "/notes", .delay(.seconds(1)))

            let manager = fixture.manager
            let sync = Task { await manager.sync() }
            try await fixture.waitForRequest("GET", "/notes")
            let added = try #require(await manager.add(content: "New", category: ""))
            let addedId = added.id
            await sync.value

            #expect(fixture.localNote(id: addedId) != nil)
            #expect(fixture.localNotes.count == 2)
        }

        @Test("A note deleted while the list is loading is not restored by that older list")
        func slowListKeepsDeletion() async throws {
            let remote = fixture.server.addNote(title: "Doomed")
            let note = try fixture.seedSynced(remote)
            fixture.server.script("GET", "/notes", .delay(.seconds(1)))

            let manager = fixture.manager
            let sync = Task { await manager.sync() }
            try await fixture.waitForRequest("GET", "/notes")
            await manager.delete(note: note)
            await sync.value

            #expect(fixture.server.notes.isEmpty)
            #expect(fixture.localNotes.isEmpty)
        }

        // MARK: Offline mode

        @Test("Offline mode stops a sync from sending anything")
        func offlineModeHonored() async throws {
            try fixture.seedLocal(id: -1, content: "Draft", addNeeded: true)
            KeychainHelper.offlineMode = true

            await fixture.manager.sync()

            #expect(fixture.server.requests.isEmpty)
        }

        // MARK: Unpushed local changes

        @Test("Opening a note with unpushed changes keeps them")
        func openKeepsPendingEdit() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "theirs")
            let note = try fixture.seedSynced(remote, content: "my edit", updateNeeded: true)

            await fixture.manager.get(note: note)

            #expect(fixture.server.requests.isEmpty)
            #expect(note.content == "my edit")
            #expect(note.updateNeeded)
        }

        @Test("A failed upload is not overwritten by the following pull")
        func failedPushSurvivesPull() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "theirs")
            let note = try fixture.seedSynced(remote, content: "my edit", updateNeeded: true)
            fixture.server.editNote(id: remote.id) { $0.content = "their newer edit" }
            fixture.server.script("PUT", "/notes/\(remote.id)", .status(500))

            await fixture.manager.sync()

            #expect(note.content == "my edit")
            #expect(note.updateNeeded)
            #expect(fixture.presentedErrors.map(\.title) == [localized("Error Updating Note")])
        }

        @Test("A pending edit survives the note's deletion on the server until it is re-created")
        func pendingEditSurvivesRemoteDeletion() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "theirs")
            let note = try fixture.seedSynced(remote, content: "my edit", updateNeeded: true)
            fixture.server.removeNote(id: remote.id)
            fixture.server.script("PUT", "/notes/\(remote.id)", .status(500))

            await fixture.manager.sync()

            #expect(note.managedObjectContext != nil)
            #expect(note.updateNeeded)

            await fixture.manager.sync()

            #expect(fixture.server.notes.map(\.content) == ["my edit"])
            #expect(!note.updateNeeded)
        }
    }
}
