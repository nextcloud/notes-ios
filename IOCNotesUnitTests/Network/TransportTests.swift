// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    ///
    /// Response validation, retries and cancellation shared by every request.
    ///
    @MainActor
    @Suite("Transport semantics", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct TransportTests {
        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        @Test("A non-JSON page with status 200 is rejected")
        func htmlRejected() async {
            fixture.server.script("GET", "/notes", .html(200))

            await fixture.manager.sync()

            #expect(fixture.presentedErrors.map(\.title) == [localized("Error Syncing Notes")])
            #expect(fixture.presentedErrors.first?.body.contains("text/html") == true)
        }

        @Test("An empty 200 response to a deletion is accepted")
        func emptyDeleteResponse() async throws {
            let remote = fixture.server.addNote(title: "Old")
            let note = try fixture.seedSynced(remote)
            fixture.server.script("DELETE", "/notes/\(remote.id)", .json(200, ""))

            await fixture.manager.delete(note: note)

            #expect(fixture.localNote(id: remote.id) == nil)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("An undecodable response is reported")
        func undecodable() async throws {
            fixture.server.script("POST", "/notes", .json(200, #"{"unexpected": true}"#))

            let note = try #require(await fixture.manager.add(content: "Draft", category: ""))

            #expect(note.addNeeded)
            #expect(fixture.presentedErrors.map(\.title) == [localized("Error Adding Note")])
        }

        @Test("A locked note succeeds on the third attempt")
        func lockedThenSucceeds() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "old")
            let note = try fixture.seedSynced(remote)
            note.content = "new"
            fixture.server.script("PUT", "/notes/\(remote.id)", times: 2, .status(423))

            await fixture.manager.update(note: note)

            #expect(fixture.server.statuses("PUT", "/notes/\(remote.id)") == [423, 423, 200])
            #expect(fixture.server.note(id: remote.id)?.content == "new")
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Fetching a note and the settings are not retried")
        func singleAttempt() async throws {
            let remote = fixture.server.addNote(title: "Plan")
            let note = try fixture.seedSynced(remote)
            fixture.server.script("GET", "/notes/\(remote.id)", .status(423))
            fixture.server.script("GET", "/settings", .status(423))
            fixture.server.script("PUT", "/settings", .status(423))

            await fixture.manager.get(note: note)
            await fixture.manager.settings()
            await fixture.manager.updateSettings()

            #expect(fixture.server.requests("GET", "/notes/\(remote.id)").count == 1)
            #expect(fixture.server.requests("GET", "/settings").count == 1)
            #expect(fixture.server.requests("PUT", "/settings").count == 1)
        }

        @Test("Transport errors are not retried")
        func transportErrorNotRetried() async throws {
            let remote = fixture.server.addNote(title: "Plan", content: "old")
            let note = try fixture.seedSynced(remote)
            note.content = "new"
            fixture.server.script("PUT", "/notes/\(remote.id)", .failure(.networkConnectionLost))

            await fixture.manager.update(note: note)

            #expect(fixture.server.requests("PUT", "/notes/\(remote.id)").count == 1)
            #expect(note.updateNeeded)
        }

        @Test("A cancelled sync reports nothing and stops")
        func cancellation() async throws {
            fixture.server.addNote(title: "A")
            fixture.server.script("GET", "/notes", .delay(.seconds(5)))

            let manager = fixture.manager
            let sync = Task { await manager.sync() }

            try await fixture.waitForRequest("GET", "/notes")
            sync.cancel()
            await sync.value

            #expect(fixture.server.requests("GET", "/notes").count == 1)
            #expect(fixture.localNotes.isEmpty)
            #expect(fixture.presentedErrors.isEmpty)
        }
    }
}
