// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    @MainActor
    @Suite("Notes settings", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct SettingsTests {
        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        @Test("Server settings set the notes folder and file extension", arguments: [
            (".md", FileSuffix.md),
            (".txt", FileSuffix.txt),
            (".org", FileSuffix.txt)
        ])
        func fetch(suffix: String, expected: FileSuffix) async {
            fixture.server.settings = ["notesPath": "My Notes", "fileSuffix": suffix]

            await fixture.manager.settings()

            #expect(Store.shared.notesPath == "My Notes")
            #expect(Store.shared.fileExtension == expected)
            #expect(fixture.presentedErrors.isEmpty)
        }

        @Test("Updating sends the local settings")
        func update() async throws {
            Store.shared.notesPath = "Work Notes"
            Store.shared.fileExtension = .txt

            await fixture.manager.updateSettings()

            let request = try #require(fixture.server.requests("PUT", "/settings").first)

            #expect(request.bodyString == "fileSuffix=.txt&notesPath=Work%20Notes")
            #expect(fixture.server.settings["notesPath"] == "Work Notes")
        }

        @Test("Rejected credentials are reported as such")
        func unauthorized() async {
            KeychainHelper.password = "wrong"

            await fixture.manager.settings()

            #expect(fixture.presentedErrors.map(\.title) == [localized("Unauthorized")])
        }

        @Test("Servers without the settings endpoint are not an error")
        func unsupportedEndpoint() async {
            KeychainHelper.notesApiVersion = "0.2"

            await fixture.manager.settings()

            #expect(fixture.server.statuses("GET", "/settings") == [400])
            #expect(fixture.presentedErrors.isEmpty)
        }
    }
}
