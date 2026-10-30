// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import Foundation
import Testing
@testable import iOCNotes

///
/// The real Nextcloud the live tier runs against: the `Integration` test plan, CI's `Integration Tests` job,
/// or `Server/Run.sh` locally. Its users are provisioned by `Server/Provisioning.sh`.
///
enum LiveServer {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["NOTES_INTEGRATION_TESTS"] == "1"
    }

    static var address: String {
        ProcessInfo.processInfo.environment["NOTES_TEST_SERVER_URL"] ?? "http://localhost:8080"
    }

    struct Account: Sendable {
        let user: String
        let password: String

        /// Starts empty and may be changed by tests; it is wiped before and after each one.
        static let mutable = Account(user: "nonotes", password: "password")

        /// Holds the `Server/Notes` fixtures; tests only read it.
        static let fixtures = Account(user: "manynotes", password: "password")
    }
}

///
/// State of a test that runs against a real Nextcloud.
///
@MainActor
final class LiveFixture {
    let account: LiveServer.Account
    let manager: NoteSessionManager
    let client: LiveNotesClient
    private(set) var presentedErrors = [ErrorMessage]()

    private let snapshot = AppStateSnapshot()
    private var originalSettings: [String: Any]?

    private init(account: LiveServer.Account) throws {
        self.account = account
        client = LiveNotesClient(address: LiveServer.address, account: account)

        // Production timeouts, but without cookies shared between the accounts.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        manager = NoteSessionManager(configuration: configuration, retryDelay: .milliseconds(500))

        do {
            try AppStateSnapshot.install(server: LiveServer.address, username: account.user, password: account.password)
        } catch {
            snapshot.restore()
            throw error
        }

        manager.presentError = { [weak self] message in
            self?.presentedErrors.append(message)
        }
    }

    static func install(account: LiveServer.Account) async throws -> LiveFixture {
        try await LiveNotesClient.probe(LiveServer.address)

        let fixture = try LiveFixture(account: account)

        guard account.user == LiveServer.Account.mutable.user else {
            return fixture
        }

        do {
            // A run that was aborted can leave the read-only share test's share behind.
            try await LiveNotesClient(address: LiveServer.address, account: .fixtures).deleteAllShares()
            try await fixture.client.deleteAllNotes()
            fixture.originalSettings = try await fixture.client.settings()
        } catch {
            await fixture.tearDown()
            throw error
        }

        return fixture
    }

    func tearDown() async {
        manager.invalidateSession()

        if account.user == LiveServer.Account.mutable.user {
            try? await client.deleteAllNotes()

            if let originalSettings {
                try? await client.putSettings(originalSettings)
            }
        }

        snapshot.restore()
    }

    var localNotes: [Note] {
        let request = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        return (try? NotesData.mainThreadContext.fetch(request)) ?? []
    }
}

struct LiveNetworkTrait: SuiteTrait, TestTrait, TestScoping {
    let account: LiveServer.Account

    var isRecursive: Bool { true }

    func provideScope(for test: Test, testCase: Test.Case?, performing function: @concurrent @Sendable () async throws -> Void) async throws {
        let fixture = try await LiveFixture.install(account: account)

        do {
            try await NetworkFixtures.$live.withValue(fixture) {
                try await function()
            }
        } catch {
            await fixture.tearDown()
            throw error
        }

        await fixture.tearDown()
    }
}

extension Trait where Self == LiveNetworkTrait {
    /// Runs each test against the live server as `account`, with isolated app state.
    static func liveAccount(_ account: LiveServer.Account) -> Self { Self(account: account) }
}

///
/// Talks to the server out of band, independently of the app's networking code, to arrange and inspect state.
/// It sends JSON, which the server accepts on every method, so it never relies on the app's form encoding.
///
struct LiveNotesClient: Sendable {
    let address: String
    let account: LiveServer.Account

    /// Without cookies: a session cookie from another account would make the server ignore the credentials.
    private let session = URLSession(configuration: .ephemeral)

    init(address: String, account: LiveServer.Account) {
        self.address = address
        self.account = account
    }

    enum ClientError: Error, CustomStringConvertible {
        case unreachable(String)
        case unexpectedStatus(Int, String)

        var description: String {
            switch self {
                case let .unreachable(address):
                    return "The live server at \(address) is not reachable. Start it with Server/Run.sh."
                case let .unexpectedStatus(status, request):
                    return "\(request) returned HTTP \(status)."
            }
        }
    }

    static func probe(_ address: String) async throws {
        guard let url = URL(string: address + "/status.php") else {
            throw ClientError.unreachable(address)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        do {
            let (_, response) = try await URLSession(configuration: .ephemeral).data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ClientError.unreachable(address)
            }
        } catch {
            throw ClientError.unreachable(address)
        }
    }

    func notes() async throws -> [[String: Any]] {
        let data = try await send("GET", "/index.php/apps/notes/api/v1/notes")
        return (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    func note(id: Int64) async throws -> [String: Any] {
        let data = try await send("GET", "/index.php/apps/notes/api/v1/notes/\(id)")
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    @discardableResult
    func createNote(title: String, content: String, category: String = "") async throws -> Int64 {
        let data = try await send("POST", "/index.php/apps/notes/api/v1/notes", json: ["title": title, "content": content, "category": category])
        let note = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        return (note["id"] as? NSNumber)?.int64Value ?? -1
    }

    func updateNote(id: Int64, _ fields: [String: Any]) async throws {
        try await send("PUT", "/index.php/apps/notes/api/v1/notes/\(id)", json: fields)
    }

    /// Best effort per note, so one undeletable note (e.g. a read-only share) does not stop the cleanup.
    func deleteAllNotes() async throws {
        for note in try await notes() {
            if let id = (note["id"] as? NSNumber)?.int64Value {
                _ = try? await send("DELETE", "/index.php/apps/notes/api/v1/notes/\(id)")
            }
        }
    }

    func settings() async throws -> [String: Any] {
        let data = try await send("GET", "/index.php/apps/notes/api/v1/settings")
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func putSettings(_ settings: [String: Any]) async throws {
        try await send("PUT", "/index.php/apps/notes/api/v1/settings", json: settings)
    }

    /// Shares `path` (relative to the account's files) read-only with `user`; returns the share id.
    func shareReadOnly(path: String, with user: String) async throws -> String {
        let data = try await send("POST", "/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json",
                                  json: ["path": path, "shareType": 0, "shareWith": user, "permissions": 1])
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let share = (object?["ocs"] as? [String: Any])?["data"] as? [String: Any]
        return (share?["id"] as? String) ?? ((share?["id"] as? NSNumber)?.stringValue ?? "")
    }

    func deleteShare(id: String) async throws {
        try await send("DELETE", "/ocs/v2.php/apps/files_sharing/api/v1/shares/\(id)")
    }

    func deleteAllShares() async throws {
        let data = try await send("GET", "/ocs/v2.php/apps/files_sharing/api/v1/shares?format=json")
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let shares = ((object?["ocs"] as? [String: Any])?["data"] as? [[String: Any]]) ?? []

        for share in shares {
            if let id = (share["id"] as? String) ?? (share["id"] as? NSNumber)?.stringValue {
                try await deleteShare(id: id)
            }
        }
    }

    @discardableResult
    private func send(_ method: String, _ path: String, json: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: address + path) else {
            throw ClientError.unreachable(address)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Basic " + Data("\(account.user):\(account.password)".utf8).base64EncodedString(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("true", forHTTPHeaderField: "OCS-APIRequest")

        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200..<300).contains(status) else {
            throw ClientError.unexpectedStatus(status, "\(method) \(path)")
        }

        return data
    }
}
