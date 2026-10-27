// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

extension NetworkIntegrationTests {
    ///
    /// The exact requests the client builds, in the form the Notes server parses.
    ///
    @MainActor
    @Suite("Router wire format", .tags(.hermetic), .timeLimit(.minutes(1)), .isolatedAppState)
    struct RouterWireFormatTests {
        enum Route: CaseIterable, Sendable {
            case allNotes, getNote, createNote, updateNote, deleteNote, settings, updateSettings

            var router: Router {
                switch self {
                    case .allNotes: .allNotes
                    case .getNote: .getNote(id: 7, etag: "")
                    case .createNote: .createNote(parameters: ["content": "x"])
                    case .updateNote: .updateNote(id: 7, parameters: ["content": "x"])
                    case .deleteNote: .deleteNote(id: 7)
                    case .settings: .settings
                    case .updateSettings: .updateSettings(notesPath: "Notes", fileSuffix: ".md")
                }
            }

            var expected: (method: String, path: String) {
                switch self {
                    case .allNotes: ("GET", "/notes")
                    case .getNote: ("GET", "/notes/7")
                    case .createNote: ("POST", "/notes")
                    case .updateNote: ("PUT", "/notes/7")
                    case .deleteNote: ("DELETE", "/notes/7")
                    case .settings: ("GET", "/settings")
                    case .updateSettings: ("PUT", "/settings")
                }
            }
        }

        let fixture: HermeticFixture

        init() throws {
            fixture = try #require(NetworkFixtures.hermetic)
        }

        @Test("Method and path per route and API version", arguments: Route.allCases, [(capability: "1.4", path: "v1"), (capability: "0.2", path: "v0.2")])
        func methodAndPath(route: Route, version: (capability: String, path: String)) throws {
            KeychainHelper.notesApiVersion = version.capability

            let request = try route.router.asURLRequest()

            #expect(request.httpMethod == route.expected.method)
            #expect(request.url?.path == "/\(fixture.token)/index.php/apps/notes/api/\(version.path)\(route.expected.path)")
        }

        @Test("Server addresses with sub-paths, index.php and ports", arguments: [
            ("https://cloud.example.com", "https://cloud.example.com/index.php/apps/notes/api/v1/notes"),
            ("https://example.com/nextcloud/", "https://example.com/nextcloud/index.php/apps/notes/api/v1/notes"),
            ("https://example.com/nextcloud/index.php", "https://example.com/nextcloud/index.php/apps/notes/api/v1/notes"),
            ("http://example.com:8443", "http://example.com:8443/index.php/apps/notes/api/v1/notes")
        ])
        func serverAddresses(server: String, expectedURL: String) throws {
            KeychainHelper.server = server

            #expect(try Router.allNotes.asURLRequest().url?.absoluteString == expectedURL)
        }

        @Test("An empty server address cannot build a request")
        func missingServer() {
            KeychainHelper.server = ""

            #expect(throws: RouterError.self) {
                try Router.allNotes.asURLRequest()
            }
        }

        @Test("Basic authorization, Accept and User-Agent headers")
        func headers() throws {
            KeychainHelper.username = "jürgen"
            KeychainHelper.password = "pa:ss wörd"

            let request = try Router.allNotes.asURLRequest()
            let credential = Data("jürgen:pa:ss wörd".utf8).base64EncodedString()

            #expect(request.value(forHTTPHeaderField: "Authorization") == "Basic \(credential)")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
            #expect(request.value(forHTTPHeaderField: "User-Agent") == userAgent)
        }

        @Test("The list request carries sync validators only once they exist")
        func listValidators() throws {
            KeychainHelper.eTag = ""
            KeychainHelper.lastModified = 0

            let fresh = try Router.allNotes.asURLRequest()

            #expect(fresh.value(forHTTPHeaderField: "If-None-Match") == nil)
            #expect(fresh.url?.query == nil)

            KeychainHelper.eTag = "\"list-etag\""
            KeychainHelper.lastModified = 1_761_234_567

            let delta = try Router.allNotes.asURLRequest()

            #expect(delta.value(forHTTPHeaderField: "If-None-Match") == "\"list-etag\"")
            #expect(delta.url?.query == "pruneBefore=1761234567")
        }

        @Test("A single-note request quotes the note's etag", arguments: [
            ("abc123", "\"abc123\""),
            ("\"abc123\"", "\"abc123\""),
            ("", nil)
        ])
        func singleNoteEtag(etag: String, expectedHeader: String?) throws {
            let request = try Router.getNote(id: 7, etag: etag).asURLRequest()

            #expect(request.value(forHTTPHeaderField: "If-None-Match") == expectedHeader)
            #expect(request.url?.query == nil)
        }

        @Test("Form bodies use sorted keys, 1/0 booleans and NSNumber-formatted numbers")
        func formBody() throws {
            let parameters: Parameters = ["title": "New note",
                                          "content": "Hello",
                                          "category": "Work",
                                          "modified": 1_761_234_567.0,
                                          "favorite": true]
            let request = try Router.createNote(parameters: parameters).asURLRequest()

            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded; charset=utf-8")
            #expect(String(decoding: try #require(request.httpBody), as: UTF8.self) == "category=Work&content=Hello&favorite=1&modified=1761234567&title=New%20note")

            let unfavorite = try Router.updateNote(id: 7, parameters: ["favorite": false, "modified": 1_761_234_567.25]).asURLRequest()

            #expect(String(decoding: try #require(unfavorite.httpBody), as: UTF8.self) == "favorite=0&modified=1761234567.25")
        }

        @Test("Content survives the server's form decoding byte for byte", arguments: [
            "a+b c",
            "x&y=z",
            "#?/:@!$'()*,;[]",
            "100% done",
            "line 1\r\nline 2\nline 3",
            "emoji 🎉 👩‍👩‍👧",
            "decomposed e\u{301} and composed é",
            "  surrounding whitespace  ",
            ""
        ])
        func contentRoundTrip(content: String) throws {
            let request = try Router.createNote(parameters: ["content": content, "category": "a/b c"]).asURLRequest()
            let decoded = FakeNotesServer.phpDecodeForm(try #require(request.httpBody))

            #expect(decoded["content"] == content)
            #expect(decoded["category"] == "a/b c")
        }

        @Test("Deleting sends neither a body nor parameters")
        func deleteRequest() throws {
            let request = try Router.deleteNote(id: 7).asURLRequest()

            #expect(request.httpBody == nil)
            #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
            #expect(request.url?.query == nil)
        }
    }
}
