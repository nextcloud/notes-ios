// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    /// Overlapping writes for one note were answered with `423 Locked` until the server timed the client out.
    @MainActor
    @Suite("Note update queue", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct NoteUpdateQueueTests {
        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        @Test("An edit during an upload is sent once the upload finished, carrying the newest content")
        func coalescesOverlappingUpdates() async throws {
            let remote = fixture.server.addNote(title: "Busy", content: "v1")
            let local = try fixture.seedSynced(remote, content: "v1")
            fixture.server.script("PUT", "/notes/\(remote.id)", times: 1, .delay(.seconds(1)))

            let manager = fixture.manager

            local.content = "v2"
            let upload = Task { await manager.update(note: local) }
            try await fixture.waitForRequest("PUT", "/notes/\(remote.id)")

            local.content = "v3"
            await manager.update(note: local)
            await upload.value

            #expect(fixture.server.requests("PUT", "/notes/\(remote.id)").count == 2)
            #expect(fixture.server.note(id: remote.id)?.content == "v3")
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Writes for different notes do not wait for each other")
        func separateNotes() async throws {
            let first = fixture.server.addNote(title: "First", content: "v1")
            let second = fixture.server.addNote(title: "Second", content: "v1")
            let firstLocal = try fixture.seedSynced(first, content: "v1")
            let secondLocal = try fixture.seedSynced(second, content: "v1")
            fixture.server.script("PUT", "/notes/\(first.id)", times: 1, .delay(.seconds(1)))

            let manager = fixture.manager

            firstLocal.content = "changed"
            secondLocal.content = "changed"

            let slow = Task { await manager.update(note: firstLocal) }
            try await fixture.waitForRequest("PUT", "/notes/\(first.id)")
            await manager.update(note: secondLocal)
            await slow.value

            #expect(fixture.server.note(id: second.id)?.content == "changed")
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("A failed upload keeps the note pending for the next synchronization")
        func failureKeepsPending() async throws {
            let remote = fixture.server.addNote(title: "Fragile", content: "v1")
            let local = try fixture.seedSynced(remote, content: "v1")
            fixture.server.script("PUT", "/notes/\(remote.id)", .status(500))

            local.content = "v2"
            await fixture.manager.update(note: local)

            #expect(fixture.localNote(id: remote.id)?.updateNeeded == true)
            #expect(fixture.server.note(id: remote.id)?.content == "v1")
            #expect(fixture.presentedErrors.count == 1)
        }
    }
}
