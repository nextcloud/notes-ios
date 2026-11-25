// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    ///
    /// End-to-end checks against a real Nextcloud with the Notes app, as the account tests may change.
    ///
    @MainActor
    @Suite("Live server: mutable account",
           .tags(.liveServer),
           .enabled(if: LiveServer.isEnabled, "Needs the Integration test plan and a provisioned server"),
           // A real server, especially a local SQLite one under load, can take tens of seconds per request.
           .timeLimit(.minutes(3)),
           .liveAccount(.mutable))
    struct LiveMutableAccountTests {
        let fixture: LiveFixture

        init() throws {
            fixture = try #require(NetworkFixtures.live)
        }

        private var manager: NoteSessionManager {
            fixture.manager
        }

        /// What a fresh install would see: an empty database and a full sync.
        private func resyncFromScratch() async {
            Note.reset()
            await manager.sync()
        }

        @Test("Settings round-trip through the server")
        func settingsRoundTrip() async {
            Store.shared.fileExtension = .txt
            await manager.updateSettings()

            Store.shared.fileExtension = .md
            await manager.settings()

            #expect(Store.shared.fileExtension == .txt)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Content survives the round trip byte for byte", arguments: [
            "a+b c & d=e #f ?g /h :i @j !k $l 'm (n) *o ,p ;q [r]",
            "line 1\r\nline 2\n\nemoji 🎉 👩‍👩‍👧 and 100% done",
            "decomposed e\u{301} and composed é"
        ])
        func contentRoundTrip(content: String) async throws {
            let note = try #require(await manager.add(content: content, category: "Round Trip"))
            let id = note.id

            #expect(!note.addNeeded)
            #expect(try await fixture.client.note(id: id)["content"] as? String == content)

            // Resetting deletes the local rows, so `note` no longer carries its id afterwards.
            await resyncFromScratch()

            let synced = try #require(fixture.localNotes.first { $0.id == id })

            #expect(synced.content == content)
            #expect(synced.category == "Round Trip")
        }

        @Test("Adding, editing and deleting reach the server")
        func lifecycle() async throws {
            let note = try #require(await manager.add(content: "Draft", category: ""))

            note.content = "Final"
            await manager.update(note: note)

            #expect(try await fixture.client.note(id: note.id)["content"] as? String == "Final")

            await manager.delete(note: note)

            #expect(try await fixture.client.notes().isEmpty)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Favorites round-trip in both directions")
        func favorite() async throws {
            let note = try #require(await manager.add(content: "Favorite me", category: ""))

            note.favorite = true
            await manager.update(note: note, updateModified: false)

            #expect(try await fixture.client.note(id: note.id)["favorite"] as? Bool == true)

            note.favorite = false
            await manager.update(note: note, updateModified: false)

            #expect(try await fixture.client.note(id: note.id)["favorite"] as? Bool == false)
        }

        @Test("Repeated syncs settle on 304 without changing anything")
        func notModified() async throws {
            try await fixture.client.createNote(title: "Steady", content: "unchanged")

            await manager.sync()
            await manager.sync()

            let eTag = KeychainHelper.eTag
            let lastModified = KeychainHelper.lastModified

            // Last-Modified has a resolution of one second, so a 200 instead of a 304 would now change it.
            try await Task.sleep(for: .seconds(1.5))
            await manager.sync()

            #expect(KeychainHelper.eTag == eTag)
            #expect(KeychainHelper.lastModified == lastModified)
            #expect(fixture.localNotes.map(\.content) == ["unchanged"])
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("A change made elsewhere arrives through delta sync")
        func deltaSync() async throws {
            let unchanged = try await fixture.client.createNote(title: "Unchanged", content: "same")
            let changed = try await fixture.client.createNote(title: "Changed", content: "v1")

            await manager.sync()

            #expect(KeychainHelper.lastModified > 0)

            // pruneBefore has a resolution of one second.
            try await Task.sleep(for: .seconds(1.5))
            try await fixture.client.updateNote(id: changed, ["content": "v2"])

            await manager.sync()

            #expect(fixture.localNotes.first { $0.id == unchanged }?.content == "same")
            #expect(fixture.localNotes.first { $0.id == changed }?.content == "v2")
        }

        @Test("After a relogin every note is loaded again")
        func relogin() async throws {
            try await fixture.client.createNote(title: "Kept", content: "kept")
            await manager.sync()

            await resyncFromScratch()

            #expect(fixture.localNotes.map(\.content) == ["kept"])
        }

        @Test("An edit to a note deleted elsewhere re-creates it")
        func editWinsOverRemoteDelete() async throws {
            let note = try #require(await manager.add(content: "Draft", category: ""))
            let originalId = note.id

            KeychainHelper.offlineMode = true
            note.content = "Edited offline"
            await manager.update(note: note)
            KeychainHelper.offlineMode = false

            try await fixture.client.deleteAllNotes()
            await manager.sync()

            let remote = try await fixture.client.notes()

            #expect(remote.map { $0["content"] as? String } == ["Edited offline"])
            #expect(note.id != originalId)
            #expect(!note.updateNeeded)
        }

        @Test("An edit the server rejects for a read-only share is dropped and the server copy restored")
        func readOnlyShare() async throws {
            let owner = LiveNotesClient(address: LiveServer.address, account: .fixtures)
            let shareId = try await owner.shareReadOnly(path: "/Notes/Top-Level Note.md", with: LiveServer.Account.mutable.user)

            do {
                await manager.sync()

                let shared = try #require(fixture.localNotes.first { $0.title == "Top-Level Note" })
                let original = shared.content

                // The list reports file shares as writable (`readonly: false`), so only the server's 403 protects them.
                shared.content = "Overwritten"
                await manager.update(note: shared)

                #expect(fixture.presentedErrors.map(\.body) == [localized("This note is read-only. Your changes were not saved.")])
                #expect(shared.content == original)
                #expect(!shared.updateNeeded)
                #expect(try await owner.note(id: shared.id)["content"] as? String == original)
            } catch {
                try? await owner.deleteShare(id: shareId)
                throw error
            }

            try await owner.deleteShare(id: shareId)
        }

        // MARK: Categories and offline additions

        @Test("A note with a category is uploaded")
        func addWithCategory() async throws {
            let note = try #require(await manager.add(content: "Note with category", category: "Test Category"))

            #expect(!note.addNeeded)
            #expect(try await fixture.client.note(id: note.id)["category"] as? String == "Test Category")
        }

        @Test("Notes added offline are uploaded by the next sync")
        func addOfflineThenSync() async throws {
            KeychainHelper.offlineMode = true
            let note = try #require(await manager.add(content: "Added offline", category: ""))

            #expect(note.addNeeded)

            KeychainHelper.offlineMode = false
            await manager.sync()

            #expect(!note.addNeeded)
            #expect(try await fixture.client.notes().map { $0["content"] as? String } == ["Added offline"])
        }

        @Test("Moving notes into and out of a category reaches the server")
        func moveBetweenCategories() async throws {
            let note = try #require(await manager.add(content: "Movable", category: ""))

            note.category = "Moved"
            await manager.update(note: note)

            #expect(try await fixture.client.note(id: note.id)["category"] as? String == "Moved")

            note.category = ""
            await manager.update(note: note)

            #expect(try await fixture.client.note(id: note.id)["category"] as? String == "")
        }
    }

    ///
    /// Reads the `Server/Notes` fixtures provisioned for the `manynotes` account.
    ///
    @MainActor
    @Suite("Live server: fixture account",
           .tags(.liveServer),
           .enabled(if: LiveServer.isEnabled, "Needs the Integration test plan and a provisioned server"),
           // A real server, especially a local SQLite one under load, can take tens of seconds per request.
           .timeLimit(.minutes(3)),
           .liveAccount(.fixtures))
    struct LiveFixtureAccountTests {
        let fixture: LiveFixture

        init() throws {
            fixture = try #require(NetworkFixtures.live)
        }

        @Test("A full sync loads every fixture note with its category")
        func fullSync() async throws {
            await fixture.manager.sync()

            let notes = fixture.localNotes
            let categories = Dictionary(notes.map { ($0.title, $0.category) }, uniquingKeysWith: { first, _ in first })

            #expect(notes.count >= 16)
            #expect(categories["Top-Level Note"] == "")
            #expect(categories["Different File Extension"] == "")
            #expect(categories["Headings"] == "Formatting")
            #expect(categories["Screenshot"] == "Notes with Attachments")
            #expect(categories["Deeply Nested Folders"] == "Deeply/Nested/Folders")
            #expect(fixture.presentedErrors.isEmpty)
        }
    }
}
