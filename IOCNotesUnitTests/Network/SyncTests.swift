// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    @MainActor
    @Suite("Synchronization", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct SyncTests {
        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        @Test("Local changes are pushed as deletions, additions, updates, then the list is pulled")
        func pushOrder() async throws {
            let doomed = fixture.server.addNote(title: "Doomed")
            let edited = fixture.server.addNote(title: "Edited", content: "old")
            try fixture.seedSynced(doomed, deleteNeeded: true)
            try fixture.seedSynced(edited, content: "new", updateNeeded: true)
            try fixture.seedLocal(id: -1, content: "Fresh", addNeeded: true)

            await fixture.manager.sync()

            let calls = fixture.server.requests.map { "\($0.method) \($0.path)" }

            #expect(calls == ["DELETE /notes/\(doomed.id)", "POST /notes", "PUT /notes/\(edited.id)", "GET /notes"])
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Notes deleted on the server are removed locally")
        func remoteDeletion() async throws {
            let kept = fixture.server.addNote(title: "Kept")
            let removed = fixture.server.addNote(title: "Removed")
            try fixture.seedSynced(kept)
            try fixture.seedSynced(removed)
            fixture.server.removeNote(id: removed.id)

            await fixture.manager.sync()

            #expect(fixture.localNotes.map(\.id) == [kept.id])
        }

        @Test("The list's ETag and Last-Modified become the next request's validators")
        func storesValidators() async throws {
            fixture.server.addNote(title: "A")

            await fixture.manager.sync()

            let response = fixture.server.requests("GET", "/notes")
            #expect(response.count == 1)
            #expect(KeychainHelper.eTag.hasPrefix("\""))
            #expect(KeychainHelper.lastModified == fixture.server.now)
        }

        @Test("A missing or unparseable Last-Modified disables pruning", arguments: [[:], ["Last-Modified": "not a date"]])
        func unusableLastModified(headers: [String: String]) async throws {
            KeychainHelper.lastModified = 1_234
            fixture.server.script("GET", "/notes", .json(200, "[]", headers: headers))

            await fixture.manager.sync()

            #expect(KeychainHelper.lastModified == 0)
        }

        @Test("Once the list stops changing it is answered with 304, which changes nothing")
        func notModified() async throws {
            let remote = fixture.server.addNote(title: "A", content: "server")
            fixture.server.advanceClock(by: 5)

            // Full list, then the same notes as stubs (a different body), then nothing new.
            await fixture.manager.sync()
            let firstETag = KeychainHelper.eTag
            fixture.server.advanceClock(by: 10)
            await fixture.manager.sync()
            let secondETag = KeychainHelper.eTag
            await fixture.manager.sync()

            let lists = fixture.server.requests("GET", "/notes")

            #expect(fixture.server.statuses("GET", "/notes") == [200, 200, 304])
            #expect(lists[1].header("If-None-Match") == firstETag)
            #expect(lists[2].header("If-None-Match") == secondETag)
            #expect(KeychainHelper.eTag == secondETag)
            #expect(fixture.localNote(id: remote.id)?.content == "server")
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Unchanged notes arrive as stubs and keep their local copy")
        func deltaSync() async throws {
            let unchanged = fixture.server.addNote(title: "Unchanged", content: "same")
            let changed = fixture.server.addNote(title: "Changed", content: "v1")
            fixture.server.advanceClock(by: 5)

            await fixture.manager.sync()

            fixture.server.advanceClock(by: 10)
            fixture.server.editNote(id: changed.id) { $0.content = "v2" }

            await fixture.manager.sync()

            let request = try #require(fixture.server.requests("GET", "/notes").last)

            #expect(request.query["pruneBefore"] == String(fixture.server.now - 10))
            #expect(fixture.localNote(id: unchanged.id)?.content == "same")
            #expect(fixture.localNote(id: changed.id)?.content == "v2")
            #expect(fixture.localNotes.count == 2)
        }

        @Test("Pruning is strict: a change at exactly pruneBefore is still sent in full")
        func pruneBoundary() async throws {
            let atBoundary = fixture.server.addNote(title: "Boundary", content: "v1")
            let before = fixture.server.addNote(title: "Before", content: "v1")

            await fixture.manager.sync()

            let pruneBefore = KeychainHelper.lastModified
            fixture.server.editNote(id: atBoundary.id) { $0.content = "v2" }
            fixture.server.editNote(id: before.id) { $0.content = "v2" }
            fixture.server.setLastUpdate(pruneBefore, id: atBoundary.id)
            fixture.server.setLastUpdate(pruneBefore - 1, id: before.id)

            await fixture.manager.sync()

            #expect(fixture.localNote(id: atBoundary.id)?.content == "v2")
            #expect(fixture.localNote(id: before.id)?.content == "v1")
        }

        @Test("Notes not uploaded yet survive the pull")
        func pendingAddSurvivesPull() async throws {
            fixture.server.script("POST", "/notes", .status(500))
            let pending = try fixture.seedLocal(id: -1, content: "Draft", addNeeded: true)
            let guid = try #require(pending.guid)

            await fixture.manager.sync()

            #expect(fixture.localNote(guid: guid)?.addNeeded == true)
        }

        @Test("A stub for a note missing locally triggers exactly one full refetch")
        func staleValidatorsRecover() async throws {
            fixture.server.addNote(title: "A")
            fixture.server.addNote(title: "B")
            KeychainHelper.eTag = "\"stale\""
            KeychainHelper.lastModified = fixture.server.now + 100

            await fixture.manager.sync()

            let lists = fixture.server.requests("GET", "/notes")

            #expect(lists.count == 2)
            #expect(lists[1].query["pruneBefore"] == nil)
            #expect(lists[1].header("If-None-Match") == nil)
            #expect(fixture.localNotes.map(\.title) == ["A", "B"])
        }

        @Test("Only a genuine timeout is reported as one", arguments: [
            (FakeNotesServer.Scripted.status(500), "Response status code was unacceptable: 500."),
            (FakeNotesServer.Scripted.failure(.timedOut), "The server request timed out")
        ])
        func failureMessages(reply: FakeNotesServer.Scripted, expectedBody: String) async throws {
            fixture.server.script("GET", "/notes", reply)

            await fixture.manager.sync()

            #expect(fixture.presentedErrors.map(\.title) == [localized("Error Syncing Notes")])
            #expect(fixture.presentedErrors.first?.body == expectedBody)
        }
    }
}
