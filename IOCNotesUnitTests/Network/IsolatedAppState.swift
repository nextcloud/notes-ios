// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import Foundation
import Testing
@testable import iOCNotes

enum NetworkFixtures {
    @TaskLocal static var hermetic: HermeticFixture?
    @TaskLocal static var live: LiveFixture?
}

///
/// Captures the process-wide state the networking layer reads and writes, so a test can change it freely
/// and the developer's own app data on the simulator stays untouched.
///
@MainActor
struct AppStateSnapshot {
    /// Every user defaults key `KeychainHelper` persists.
    private static let defaultsKeys = [
        "ServerMajorVersion", "ServerMinorVersion", "ServerMicroVersion", "Server", "NotesPath", "FileSuffix",
        "version", "SyncOnStart", "OfflineMode", "AllowUntrustedCertificate", "dbReset", "GroupByCategory",
        "Sections", "notesApiVersion", "notesVersion", "productVersion", "productName", "didResetSyncValidators",
        "eTag", "lastModified", "InternalEditor", "directEditingSupportsFileId"
    ]

    private let defaults: [String: Any]
    private let username: String
    private let password: String

    init() {
        var defaults = [String: Any]()

        for key in Self.defaultsKeys {
            defaults[key] = UserDefaults.standard.object(forKey: key)
        }

        self.defaults = defaults
        username = KeychainHelper.username
        password = KeychainHelper.password
    }

    /// Points the app at `server` with an empty, isolated note store and fresh sync state.
    static func install(server: String, username: String, password: String) throws {
        for key in defaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        UserDefaults.standard.set(server, forKey: "Server")
        UserDefaults.standard.set("1.4", forKey: "notesApiVersion")
        UserDefaults.standard.set(false, forKey: "OfflineMode")
        UserDefaults.standard.set(false, forKey: "AllowUntrustedCertificate")

        KeychainHelper.username = username
        KeychainHelper.password = password

        guard KeychainHelper.username == username, KeychainHelper.password == password else {
            throw IsolationError.keychainUnavailable
        }

        NotesData.overrideContext = try makeIsolatedContext()
    }

    func restore() {
        NotesData.overrideContext = nil

        for key in Self.defaultsKeys {
            if let value = defaults[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        KeychainHelper.username = username
        KeychainHelper.password = password
    }

    /// A real SQLite store kept in memory: batch deletes (used by `Note.reset()`) do nothing on in-memory stores.
    private static func makeIsolatedContext() throws -> NSManagedObjectContext {
        let container = NSPersistentContainer(name: "Notes", managedObjectModel: NotesData.model)
        container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: URL(fileURLWithPath: "/dev/null"))]

        var loadError: Error?

        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError {
            throw loadError
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        return container.viewContext
    }

    enum IsolationError: Error, CustomStringConvertible {
        case keychainUnavailable

        var description: String {
            "The keychain did not store the test credentials; requests would be sent unauthenticated."
        }
    }
}

///
/// State of a test that runs against the in-process ``FakeNotesServer``.
///
@MainActor
final class HermeticFixture {
    static let username = "notes-tester"
    static let password = "s3cret"

    let token = UUID().uuidString
    let server = FakeNotesServer(username: HermeticFixture.username, password: HermeticFixture.password)
    let manager: NoteSessionManager
    private(set) var presentedErrors = [ErrorMessage]()

    private let snapshot = AppStateSnapshot()

    var serverAddress: String {
        "http://127.0.0.1:9/\(token)"
    }

    private init() throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false

        manager = NoteSessionManager(configuration: configuration, retryDelay: .milliseconds(20))
        StubURLProtocol.register(server, token: token)

        do {
            try AppStateSnapshot.install(server: serverAddress, username: Self.username, password: Self.password)
        } catch {
            StubURLProtocol.unregister(token: token)
            snapshot.restore()
            throw error
        }

        manager.presentError = { [weak self] message in
            self?.presentedErrors.append(message)
        }
    }

    static func install() throws -> HermeticFixture {
        try HermeticFixture()
    }

    func tearDown() {
        Attachment.record(Data(server.requestLog.utf8), named: "requests.txt")

        manager.invalidateSession()
        StubURLProtocol.unregister(token: token)
        snapshot.restore()
    }

    /// Waits until the fake server has received `count` matching requests, e.g. one whose response it holds back.
    func waitForRequest(_ method: String, _ path: String, count: Int = 1) async throws {
        for _ in 0..<500 {
            if server.requests(method, path).count >= count {
                return
            }

            try await Task.sleep(for: .milliseconds(10))
        }

        Issue.record("\(method) \(path) was not requested \(count) time(s) within 5 seconds")
    }

    // MARK: Local database

    var localNotes: [Note] {
        let request = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        return (try? NotesData.mainThreadContext.fetch(request)) ?? []
    }

    func localNote(id: Int64) -> Note? {
        localNotes.first { $0.id == id }
    }

    func localNote(guid: String) -> Note? {
        localNotes.first { $0.guid == guid }
    }

    /// Inserts a local row, as if an earlier sync or edit had produced it.
    @discardableResult
    func seedLocal(id: Int64, title: String = "Title", content: String = "Content", category: String = "", favorite: Bool = false, modified: Double = 1_700_000_000, etag: String = "", readOnly: Bool = false, addNeeded: Bool = false, updateNeeded: Bool = false, deleteNeeded: Bool = false) throws -> Note {
        let context = NotesData.mainThreadContext
        let note = NSEntityDescription.insertNewObject(forEntityName: "Note", into: context) as! Note
        note.id = id
        note.title = title
        note.content = content
        note.category = category
        note.favorite = favorite
        note.modified = modified
        note.etag = etag
        note.readOnly = readOnly
        note.addNeeded = addNeeded
        note.updateNeeded = updateNeeded
        note.deleteNeeded = deleteNeeded
        try context.save()
        return note
    }

    /// Mirrors a server note locally, as a completed sync would.
    @discardableResult
    func seedSynced(_ remote: FakeNotesServer.Note, content: String? = nil, updateNeeded: Bool = false, deleteNeeded: Bool = false) throws -> Note {
        try seedLocal(id: remote.id,
                      title: remote.title,
                      content: content ?? remote.content,
                      category: remote.category,
                      favorite: remote.favorite,
                      modified: Double(remote.modified),
                      etag: remote.etag,
                      readOnly: remote.readOnly,
                      updateNeeded: updateNeeded,
                      deleteNeeded: deleteNeeded)
    }
}

struct HermeticNetworkTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(for test: Test, testCase: Test.Case?, performing function: @concurrent @Sendable () async throws -> Void) async throws {
        let fixture = try await HermeticFixture.install()

        do {
            try await NetworkFixtures.$hermetic.withValue(fixture) {
                try await function()
            }
        } catch {
            await fixture.tearDown()
            throw error
        }

        await fixture.tearDown()
    }
}

extension Trait where Self == HermeticNetworkTrait {
    /// Runs each test against its own ``FakeNotesServer`` with isolated app state.
    static var isolatedAppState: Self { Self() }
}
