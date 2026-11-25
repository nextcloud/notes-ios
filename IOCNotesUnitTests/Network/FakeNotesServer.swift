// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation
import Synchronization

///
/// In-memory Notes API, modeled on `nextcloud/notes` (`NotesApiController`, `Helper`, `NoteUtil`)
/// and Nextcloud core's `NotModifiedMiddleware`, so the client is tested against the real contract.
///
final class FakeNotesServer: Sendable {
    struct Note: Equatable, Sendable {
        var id: Int64
        var title: String
        var content: String
        var category: String
        var modified: Int
        var favorite: Bool
        var readOnly: Bool
        var error: Bool
        /// Server time of the last metadata change; drives `pruneBefore`, separately from `modified`.
        var lastUpdate: Int
        /// Like a file shared without edit permission: listed as writable, yet writes are rejected with 403.
        var writeProtected = false

        var etag: String {
            FakeNotesServer.md5("\(id)|\(title)|\(modified)|\(category)|\(favorite)|\(readOnly)|\(FakeNotesServer.md5(content))")
        }
    }

    struct RecordedRequest: Sendable {
        let method: String
        /// Relative to the API root, e.g. `/notes/7`.
        let path: String
        let apiVersion: String
        let query: [String: String]
        let headers: [String: String]
        let body: Data
        /// Parameters as PHP decodes them; empty unless the body is form-urlencoded.
        let form: [String: String]
        /// The status the server answered with; nil for a transport failure.
        var status: Int?

        var bodyString: String {
            String(decoding: body, as: UTF8.self)
        }

        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }
    }

    enum Scripted: Sendable {
        /// The status with the Notes app's JSON error body.
        case status(Int)
        case json(Int, String, headers: [String: String] = [:])
        /// The status with an HTML body, as the server core answers when the Notes app is not reached.
        case html(Int)
        case failure(URLError.Code)
        /// Handles the request at once but delivers the response later, like a slow network.
        case delay(Duration)
    }

    struct Reply: Sendable {
        enum Outcome: Sendable {
            case response(HTTPURLResponse, Data)
            case failure(URLError)
        }

        let outcome: Outcome
        let delay: Duration?
    }

    let username: String
    let password: String

    private struct Script {
        let method: String
        let path: String
        var remaining: Int
        let reply: Scripted
    }

    private struct State {
        var notes = [Int64: Note]()
        // Beyond Int32 so 32-bit id handling (e.g. a `%d` predicate) cannot pass unnoticed.
        var nextId: Int64 = 5_000_000_001
        var now = 1_800_000_000
        var settings = ["notesPath": "Notes", "fileSuffix": ".md"]
        var scripts = [Script]()
        var requests = [RecordedRequest]()
    }

    private let state = Mutex(State())

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    // MARK: - Test API

    var now: Int {
        state.withLock { $0.now }
    }

    func advanceClock(by seconds: Int) {
        state.withLock { $0.now += seconds }
    }

    var notes: [Note] {
        state.withLock { $0.notes.values.sorted { $0.id < $1.id } }
    }

    func note(id: Int64) -> Note? {
        state.withLock { $0.notes[id] }
    }

    @discardableResult
    func addNote(title: String, content: String = "", category: String = "", favorite: Bool = false, readOnly: Bool = false, error: Bool = false, writeProtected: Bool = false, modified: Int? = nil) -> Note {
        state.withLock { state in
            let note = Note(id: state.nextId,
                            title: title,
                            content: content,
                            category: category,
                            modified: modified ?? state.now,
                            favorite: favorite,
                            // Like `Note::getData`, an unreadable note is always reported read-only.
                            readOnly: readOnly || error,
                            error: error,
                            lastUpdate: state.now,
                            writeProtected: writeProtected)
            state.notes[note.id] = note
            state.nextId += 1
            return note
        }
    }

    /// Changes a note as another client would; its `lastUpdate` follows when the metadata changes.
    func editNote(id: Int64, _ change: (inout Note) -> Void) {
        state.withLock { state in
            guard var note = state.notes[id] else { return }

            let etag = note.etag
            change(&note)

            if note.etag != etag {
                note.lastUpdate = state.now
            }

            state.notes[id] = note
        }
    }

    func removeNote(id: Int64) {
        _ = state.withLock { $0.notes.removeValue(forKey: id) }
    }

    /// Moves a note's last metadata change, e.g. onto the `pruneBefore` boundary.
    func setLastUpdate(_ timestamp: Int, id: Int64) {
        state.withLock { $0.notes[id]?.lastUpdate = timestamp }
    }

    var settings: [String: String] {
        get { state.withLock { $0.settings } }
        set { state.withLock { $0.settings = newValue } }
    }

    /// The next `times` requests matching `method` and `path` get `reply` instead of the normal handling.
    func script(_ method: String, _ path: String, times: Int = 1, _ reply: Scripted) {
        state.withLock { $0.scripts.append(Script(method: method, path: path, remaining: times, reply: reply)) }
    }

    var requests: [RecordedRequest] {
        state.withLock { $0.requests }
    }

    func requests(_ method: String, _ path: String) -> [RecordedRequest] {
        requests.filter { $0.method == method && $0.path == path }
    }

    func statuses(_ method: String, _ path: String) -> [Int?] {
        requests(method, path).map(\.status)
    }

    var requestLog: String {
        requests.map { request in
            let query = request.query.isEmpty ? "" : "?" + request.query.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            return "\(request.method) v\(request.apiVersion)\(request.path)\(query) → \(request.status.map(String.init) ?? "failed") \(request.bodyString)"
        }.joined(separator: "\n")
    }

    // MARK: - Request handling

    func handle(_ request: URLRequest, token: String) -> Reply {
        guard let url = request.url else {
            return Reply(outcome: .failure(URLError(.badURL)), delay: nil)
        }

        let prefix = "/\(token)/index.php/apps/notes/api/v"

        guard url.path.hasPrefix(prefix) else {
            return Reply(outcome: .response(Self.response(url, 404, contentType: "text/html"), Data("<html>Not Found</html>".utf8)), delay: nil)
        }

        let versionAndPath = url.path.dropFirst(prefix.count)
        let apiVersion = String(versionAndPath.prefix { $0 != "/" })
        let path = String(versionAndPath.dropFirst(apiVersion.count))
        let method = request.httpMethod ?? "GET"
        let body = request.httpBody ?? Data()
        let headers = request.allHTTPHeaderFields ?? [:]
        let isForm = (headers.first { $0.key.lowercased() == "content-type" }?.value ?? "").contains("application/x-www-form-urlencoded")

        var recorded = RecordedRequest(method: method,
                                       path: path,
                                       apiVersion: apiVersion,
                                       query: Self.query(of: url),
                                       headers: headers,
                                       body: body,
                                       form: isForm ? Self.phpDecodeForm(body) : [:])

        return state.withLock { state in
            let reply = self.reply(to: recorded, url: url, state: &state)

            if case let .response(response, _) = reply.outcome {
                recorded.status = response.statusCode
            }

            state.requests.append(recorded)
            return reply
        }
    }

    private func reply(to recorded: RecordedRequest, url: URL, state: inout State) -> Reply {
        let method = recorded.method
        let path = recorded.path
        var delay: Duration?

        if let index = state.scripts.firstIndex(where: { $0.method == method && $0.path == path && $0.remaining > 0 }) {
            state.scripts[index].remaining -= 1

            switch state.scripts[index].reply {
                case let .delay(duration):
                    delay = duration
                case let .status(code):
                    return Reply(outcome: .response(Self.response(url, code), Data(#"{"errorType":"Exception"}"#.utf8)), delay: nil)
                case let .json(code, json, headers):
                    return Reply(outcome: .response(Self.response(url, code, headers: headers), Data(json.utf8)), delay: nil)
                case let .html(code):
                    return Reply(outcome: .response(Self.response(url, code, contentType: "text/html"), Data("<html>Error</html>".utf8)), delay: nil)
                case let .failure(code):
                    return Reply(outcome: .failure(URLError(code)), delay: nil)
            }
        }

        let (response, data) = route(recorded, url: url, state: &state)
        return Reply(outcome: .response(response, data), delay: delay)
    }

    private func route(_ request: RecordedRequest, url: URL, state: inout State) -> (HTTPURLResponse, Data) {
        guard request.header("Authorization") == "Basic " + Data("\(username):\(password)".utf8).base64EncodedString() else {
            return (Self.response(url, 401), Data(#"{"message":"CORS requires basic auth"}"#.utf8))
        }

        let isV1 = request.apiVersion == "1"
        let components = request.path.split(separator: "/").map(String.init)

        switch (request.method, components.first, components.count) {
            case ("GET", "notes", 1):
                return listNotes(request, url: url, state: state)
            case ("POST", "notes", 1):
                return createNote(request, isV1: isV1, url: url, state: &state)
            case (_, "notes", 2):
                // The routes only accept numeric ids; other ids fall through to the GET-only catch-all.
                guard let id = Int64(components[1]), id >= 0 else {
                    return request.method == "GET"
                        ? (Self.response(url, 400), Data("[]".utf8))
                        : (Self.response(url, 405, contentType: "text/html"), Data())
                }

                return handleNote(id: id, request, isV1: isV1, url: url, state: &state)
            case ("GET", "settings", 1):
                guard isV1 else {
                    return (Self.response(url, 400), Data("[]".utf8))
                }

                return (Self.response(url, 200), Self.json(state.settings))
            case ("PUT", "settings", 1):
                guard isV1 else {
                    return (Self.response(url, 405, contentType: "text/html"), Data())
                }

                for key in ["notesPath", "fileSuffix"] {
                    if let value = request.form[key] {
                        state.settings[key] = value
                    }
                }

                return (Self.response(url, 200), Self.json(state.settings))
            default:
                return (Self.response(url, 400), Data("[]".utf8))
        }
    }

    private func listNotes(_ request: RecordedRequest, url: URL, state: State) -> (HTTPURLResponse, Data) {
        let pruneBefore = Self.phpInt(request.query["pruneBefore"])
        let all = state.notes.values.sorted { $0.id < $1.id }
        let full = all
            .filter { !(pruneBefore != 0 && $0.lastUpdate < pruneBefore) }
            .sorted { ($0.lastUpdate, $0.id) < ($1.lastUpdate, $1.id) }
        let fullIds = Set(full.map(\.id))
        let stubs: [[String: Any]] = all.filter { !fullIds.contains($0.id) }.map { ["id": $0.id] }
        let body = Self.json(full.map(Self.json(for:)) + stubs)
        let etag = "\"" + Self.md5(body) + "\""
        let headers = ["ETag": etag, "Last-Modified": Self.httpDate(state.now)]

        if request.header("If-None-Match")?.trimmingCharacters(in: .whitespaces) == etag {
            return (Self.response(url, 304, headers: headers), Data())
        }

        return (Self.response(url, 200, headers: headers), body)
    }

    private func createNote(_ request: RecordedRequest, isV1: Bool, url: URL, state: inout State) -> (HTTPURLResponse, Data) {
        let form = request.form
        let content = form["content"] ?? ""
        let category = Self.normalizeCategory(form["category"] ?? "")
        let requestedTitle = isV1 ? (form["title"] ?? "") : content
        let modified = Self.phpInt(form["modified"])

        let note = Note(id: state.nextId,
                        title: Self.uniqueTitle(Self.safeTitle(requestedTitle), category: category, excluding: nil, in: state.notes),
                        content: content,
                        category: category,
                        modified: modified != 0 ? modified : state.now,
                        favorite: Self.phpBool(form["favorite"]),
                        readOnly: false,
                        error: false,
                        lastUpdate: state.now)

        state.notes[note.id] = note
        state.nextId += 1

        return (Self.response(url, 200), Self.json(Self.json(for: note)))
    }

    private func handleNote(id: Int64, _ request: RecordedRequest, isV1: Bool, url: URL, state: inout State) -> (HTTPURLResponse, Data) {
        let notFound = (Self.response(url, 404), Data(#"{"errorType":"Exception"}"#.utf8))
        let forbidden = (Self.response(url, 403), Data(#"{"errorType":"Exception"}"#.utf8))

        guard var note = state.notes[id] else { return notFound }

        switch request.method {
            case "GET":
                let etag = "\"\(note.etag)\""

                if request.header("If-None-Match")?.trimmingCharacters(in: .whitespaces) == etag {
                    return (Self.response(url, 304, headers: ["ETag": etag]), Data())
                }

                return (Self.response(url, 200, headers: ["ETag": etag]), Self.json(Self.json(for: note)))
            case "PUT":
                let form = request.form
                let previousEtag = note.etag

                if let content = form["content"], content != note.content {
                    guard !note.readOnly, !note.writeProtected else { return forbidden }

                    note.content = content
                }

                if let modifiedValue = form["modified"] {
                    let modified = Self.phpInt(modifiedValue)

                    if modified != note.modified {
                        guard !note.readOnly, !note.writeProtected else { return forbidden }

                        note.modified = modified
                    }
                }

                let title = isV1 ? form["title"] : form["content"].map(Self.safeTitle)

                if let title, title != note.title {
                    guard !note.readOnly, !note.writeProtected else { return forbidden }

                    let category = form["category"].map(Self.normalizeCategory) ?? note.category
                    note.title = Self.uniqueTitle(Self.safeTitle(title), category: category, excluding: id, in: state.notes)
                    note.category = category
                } else if let category = form["category"], category != note.category {
                    guard !note.readOnly, !note.writeProtected else { return forbidden }

                    note.category = Self.normalizeCategory(category)
                }

                if let favorite = form["favorite"] {
                    note.favorite = Self.phpBool(favorite)
                }

                if note.etag != previousEtag {
                    note.lastUpdate = state.now
                }

                state.notes[id] = note
                return (Self.response(url, 200), Self.json(Self.json(for: note)))
            case "DELETE":
                guard !note.readOnly, !note.writeProtected else { return forbidden }

                state.notes[id] = nil
                return (Self.response(url, 200), Data("[]".utf8))
            default:
                return (Self.response(url, 405, contentType: "text/html"), Data())
        }
    }

    // MARK: - Server semantics

    /// `NoteUtil::getSafeTitle`: strips illegal characters, keeps the first line, at most 100 characters.
    static func safeTitle(_ string: String) -> String {
        let sanitized = sanitizePath(string)
        let firstLine = sanitized.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let spaced = String(firstLine.trimmingCharacters(in: .whitespaces).map { $0.isWhitespace ? " " : $0 })
        let title = String(spaced.prefix(100))

        return title.isEmpty ? "New note" : title
    }

    static func normalizeCategory(_ category: String) -> String {
        category.split(separator: "/", omittingEmptySubsequences: false)
            .map { sanitizePath(String($0)) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private static func sanitizePath(_ string: String) -> String {
        let illegal = Set("*|/\\:\"<>?")
        let lines = String(string.filter { !illegal.contains($0) })
            .components(separatedBy: "\n")
            .map { String($0.drop { $0 == "." || $0.isWhitespace }) }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `NoteUtil::generateFileName`: a taken title becomes `title (2)`, `title (3)`, …
    private static func uniqueTitle(_ title: String, category: String, excluding id: Int64?, in notes: [Int64: Note]) -> String {
        let taken = Set(notes.values.filter { $0.category == category && $0.id != id }.map(\.title))
        var candidate = title
        var counter = 2

        while taken.contains(candidate) {
            candidate = "\(title) (\(counter))"
            counter += 1
        }

        return candidate
    }

    /// PHP's `settype(..., 'int')`: numeric strings are truncated, anything else is 0.
    static func phpInt(_ string: String?) -> Int {
        guard let string else { return 0 }

        if let int = Int(string) {
            return int
        }

        return Double(string).map { Int($0) } ?? 0
    }

    /// Nextcloud's dispatcher: `"false"`, `"0"` and `""` are false, anything else is true.
    static func phpBool(_ string: String?) -> Bool {
        guard let string else { return false }

        return !(string.isEmpty || string == "0" || string == "false")
    }

    /// PHP's `parse_str`: `+` is a space, then `%XX` sequences are decoded.
    static func phpDecodeForm(_ body: Data) -> [String: String] {
        var result = [String: String]()

        for pair in String(decoding: body, as: UTF8.self).split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let decode = { (string: String) in string.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? string }

            result[decode(parts[0])] = parts.count > 1 ? decode(parts[1]) : ""
        }

        return result
    }

    // MARK: - Encoding

    private static func json(for note: Note) -> [String: Any] {
        ["id": note.id,
         "title": note.title,
         "modified": note.modified,
         "category": note.category,
         "favorite": note.favorite,
         "readonly": note.readOnly,
         "internalPath": "/Notes/\(note.title).md",
         "shareTypes": [Int](),
         "isShared": false,
         "error": note.error,
         "errorType": "",
         "content": note.content,
         "etag": note.etag]
    }

    private static func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }

    private static func response(_ url: URL, _ status: Int, contentType: String = "application/json; charset=utf-8", headers: [String: String] = [:]) -> HTTPURLResponse {
        var fields = headers
        fields["Content-Type"] = contentType

        return HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields)!
    }

    private static func query(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
    }

    /// RFC 7231 IMF-fixdate, as `Response::setLastModified` emits it.
    static func httpDate(_ timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }

    static func md5(_ string: String) -> String {
        md5(Data(string.utf8))
    }

    static func md5(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
