// SPDX-FileCopyrightText: 2020 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import NextcloudKit
import os
import SwiftMessages
import SystemConfiguration
import UIKit

struct ErrorMessage {
    let title: String
    let body: String
}

///
/// Server trust handling for the notes session: accepts the saved self-signed
/// certificate when the user allowed it, default evaluation otherwise.
///
private final class NotesURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            return completionHandler(.performDefaultHandling, nil)
        }

        let host = challenge.protectionSpace.host

        guard KeychainHelper.allowUntrustedCertificate,
              !host.isEmpty,
              let serverHost = URLComponents(string: KeychainHelper.server)?.host,
              host == serverHost,
              let savedCertificate = ServerStatus.shared.savedCert(host: host) else {
            return completionHandler(.performDefaultHandling, nil)
        }

        let savedData = SecCertificateCopyData(savedCertificate) as Data
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []

        if chain.contains(where: { SecCertificateCopyData($0) as Data == savedData }) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

}

/// The fields a user edits, to tell whether a note changed while a request for it was in flight.
private struct EditableFields: Equatable {
    let title: String
    let content: String
    let category: String
    let favorite: Bool

    init(_ note: NoteProtocol) {
        title = note.title
        content = note.content
        category = note.category
        favorite = note.favorite
    }
}

private struct HTTPResult {
    let data: Data
    let response: HTTPURLResponse
}

private enum RequestError: Error, LocalizedError {
    case transport(Error)
    case unacceptableStatusCode(HTTPResult)
    case unacceptableContentType(HTTPResult)
    case decoding(Error, HTTPResult)

    var statusCode: Int? {
        switch self {
        case .transport:
            return nil
        case let .unacceptableStatusCode(result), let .unacceptableContentType(result):
            return result.response.statusCode
        case let .decoding(_, result):
            return result.response.statusCode
        }
    }

    var isTimedOut: Bool {
        if case let .transport(error) = self {
            return (error as? URLError)?.code == .timedOut
        }

        return false
    }

    /// Whether the Notes app itself answered, as opposed to e.g. an HTML error page of the server core.
    var isNotesAppResponse: Bool {
        switch self {
        case .transport:
            return false
        case let .unacceptableStatusCode(result), let .unacceptableContentType(result), let .decoding(_, result):
            return result.response.mimeType?.lowercased() == Router.applicationJson
        }
    }

    var errorDescription: String? {
        switch self {
        case let .transport(error), let .decoding(error, _):
            return error.localizedDescription
        case let .unacceptableStatusCode(result):
            return "Response status code was unacceptable: \(result.response.statusCode)."
        case let .unacceptableContentType(result):
            return "Response Content-Type \"\(result.response.mimeType ?? "unknown")\" was unacceptable."
        }
    }
}

@MainActor
final class NoteSessionManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NoteSessionManager")

    private struct NoteError: Error {
        let message: ErrorMessage
    }

    static let shared = NoteSessionManager(configuration: makeProductionConfiguration(), retryDelay: .seconds(2))

    /// Presents user-facing errors; tests replace it to capture them.
    var presentError: @MainActor (ErrorMessage) -> Void = { message in
        NoteSessionManager.showBanner(for: message)
    }

    private var notesBeingAdded = Set<String>()
    private var runningSync: Task<Void, Never>?

    private let session: URLSession
    private let retryDelay: Duration

    nonisolated static var isConnectedToServer: Bool {
        guard let url = URL(string: KeychainHelper.server),
            let host = url.host else {
            return false
        }

        return hostIsReachable(host)
    }

    nonisolated static var isOnline: Bool {
        return NoteSessionManager.isConnectedToServer && !Store.shared.offlineMode
    }

    init(configuration: URLSessionConfiguration, retryDelay: Duration) {
        session = URLSession(configuration: configuration, delegate: NotesURLSessionDelegate(), delegateQueue: nil)
        self.retryDelay = retryDelay
    }

    nonisolated static func makeProductionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        return configuration
    }

    /// Releases the session, which otherwise retains its delegate for the lifetime of the process.
    func invalidateSession() {
        session.finishTasksAndInvalidate()
    }

    /// Fetch the server status from `/status.php`.
    func status() async {
        logger.notice("Fetching status...")

        guard let serverUrl = canonicalServerComponents(from: KeychainHelper.server)?.url?.absoluteString else {
            logger.error("Cannot fetch status: server URL is empty or invalid.")
            return
        }

        let (_, result) = await NextcloudKit.shared.getServerStatusAsync(serverUrl: serverUrl)

        switch result {
            case let .success(info):
                KeychainHelper.productVersion = info.version
                KeychainHelper.productName = info.productName
            case let .failure(error):
                logger.error("Error fetching status: \(error.errorDescription, privacy: .public)")
        }
    }

    ///
    /// Fetch the user settings for Nextcloud Notes from the server.
    ///
    func settings() async {
        logger.debug("Fetching notes user settings from server...")

        switch await performDecodable(Router.settings, of: SettingsStruct.self) {
            case let .success(result):
                logger.debug("Successfully received settings from the server (notes path: \"\(result.notesPath)\", file suffix: \"\(result.fileSuffix)\").")

                switch result.fileSuffix {
                    case FileSuffix.md.suffix:
                        Store.shared.fileExtension = FileSuffix.md
                    case FileSuffix.txt.suffix:
                        Store.shared.fileExtension = FileSuffix.txt
                    default:
                        logger.error("Unexpected file suffix \"\(result.fileSuffix, privacy: .public)\" received in settings, falling back to plain text extension.")
                        Store.shared.fileExtension = FileSuffix.txt
                }

                Store.shared.notesPath = result.notesPath
            case let .failure(error):
                logger.error("Error during settings retrieval: \(error.localizedDescription, privacy: .public)")

                showSettingsError(error, title: NSLocalizedString("Error Getting Settings", comment: "The title of an error message"))
        }
    }

    ///
    /// Update the user settings for Nextcloud Notes on the server.
    ///
    func updateSettings() async {
        logger.debug("Updating notes user settings on server...")

        let router = Router.updateSettings(notesPath: Store.shared.notesPath, fileSuffix: Store.shared.fileExtension.suffix)

        switch await perform(router) {
            case .success:
                logger.debug("Successfully updated notes user settings on server.")
            case let .failure(error):
                logger.debug("Error while updating notes user settings on server: \(error.localizedDescription, privacy: .public)")

                showSettingsError(error, title: NSLocalizedString("Error Updating Settings", comment: "The title of an error message"))
        }
    }

    private func showSettingsError(_ error: RequestError, title: String) {
        switch error.statusCode {
            case nil, 400: // Transport error, or bad request (endpoint not supported)
                break
            case 401:
                showErrorMessage(message: ErrorMessage(title: NSLocalizedString("Unauthorized", comment: "An error message title"),
                                                       body: NSLocalizedString("Check username and password.", comment: "An error message")))
            default:
                showErrorMessage(message: ErrorMessage(title: title, body: error.localizedDescription))
        }
    }

    ///
    /// Synchronize the notes: push local deletions, additions and updates, then pull remote changes.
    /// Overlapping calls join the synchronization already in progress.
    ///
    func sync() async {
        if let runningSync {
            await runningSync.value
            return
        }

        guard NoteSessionManager.isOnline else {
            logger.notice("Skipping synchronization because offline mode is on or the server is not reachable.")
            return
        }

        logger.notice("Synchronizing...")

        let task = Task {
            await pushLocalDeletions()
            await pushLocalAdditions()
            await pushLocalUpdates()
            await pullRemoteChanges()
        }

        runningSync = task

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        runningSync = nil
    }

    // Each push re-checks its row: earlier awaits may have uploaded, deleted or detached it.

    private func pushLocalDeletions() async {
        for note in Note.notes(property: "deleteNeeded") ?? [] {
            guard note.managedObjectContext != nil, note.deleteNeeded else { continue }

            await delete(note: note)
        }
    }

    private func pushLocalAdditions() async {
        for note in Note.notes(property: "addNeeded") ?? [] {
            guard note.managedObjectContext != nil, note.addNeeded else { continue }

            _ = await addToServer(note: note)
        }
    }

    private func pushLocalUpdates() async {
        for note in Note.notes(property: "updateNeeded") ?? [] {
            guard note.managedObjectContext != nil, note.updateNeeded, !note.addNeeded else { continue }

            await update(note: note)
        }
    }

    private func pullRemoteChanges(recoveringFromStaleCache: Bool = false) async {
        // Local operations can finish while the list is in flight, so the response may only remove or
        // re-insert notes the database already knew, unchanged, when the request was sent.
        let knownBeforeRequest = Note.syncedIds()
        let unchangedBeforeRequest = Note.syncedIds(excludingPendingChanges: true)

        switch await perform(Router.allNotes, retryLimit: 2) {
            case let .success(result):
                guard let json = try? JSONSerialization.jsonObject(with: result.data, options: .allowFragments),
                      let jsonArray = json as? Array<[String: Any]> else {
                    logger.error("Unexpected payload received for the list of all notes.")
                    return
                }

                storeValidators(from: result.response)

                // A pruned stub for a note missing locally means the validators got ahead of
                // the local database: drop them and fetch the full list once.
                if !recoveringFromStaleCache {
                    let localIds = Note.syncedIds()
                    let prunedIds = jsonArray.filter({ $0.keys.count == 1 }).compactMap({ $0["id"] as? Int64 })

                    if prunedIds.contains(where: { !localIds.contains($0) }) {
                        logger.notice("Server pruned notes that do not exist locally, refetching the full list...")

                        KeychainHelper.eTag = ""
                        KeychainHelper.lastModified = 0

                        await pullRemoteChanges(recoveringFromStaleCache: true)
                        return
                    }
                }

                // Rows with unpushed changes survive a remote deletion: their next push re-creates them.
                if let serverIds = jsonArray.map({ $0["id"] }) as? [Int64] {
                    let deletedOnServer = unchangedBeforeRequest
                        .intersection(Note.syncedIds(excludingPendingChanges: true))
                        .subtracting(serverIds)

                    if !deletedOnServer.isEmpty {
                        Note.delete(ids: Array(deletedOnServer))
                    }
                }

                let localIds = Note.syncedIds()
                let remoteNotes = jsonArray
                    .filter({ $0.keys.count > 1 })
                    .map { NoteStruct(dictionary: $0) }
                    .filter { localIds.contains($0.id) || !knownBeforeRequest.contains($0.id) }

                if !remoteNotes.isEmpty {
                    Note.merge(remote: remoteNotes)
                }
            case let .failure(error):
                if error.statusCode == 304 {
                    logger.notice("Remote notes did not change.")
                } else {
                    let body = error.isTimedOut ? "The server request timed out" : error.localizedDescription
                    let message = ErrorMessage(title: NSLocalizedString("Error Syncing Notes", comment: "The title of an error message"),
                                               body: body)
                    showErrorMessage(message: message)
                }
        }
    }

    private func storeValidators(from response: HTTPURLResponse) {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        // Like the Android client: 0 (no pruning) when the header is missing or unparseable.
        let lastModifiedDate = response.value(forHTTPHeaderField: "Last-Modified").flatMap { dateFormatter.date(from: $0) }
        KeychainHelper.lastModified = Int(lastModifiedDate?.timeIntervalSince1970 ?? 0)

        if let etag = response.value(forHTTPHeaderField: "Etag") {
            KeychainHelper.eTag = etag
        }
    }

    @discardableResult
    func add(content: String, category: String) async -> Note? {
        logger.notice("Adding note...")

        let note = NoteStruct(content: content, category: category)

        guard let incoming = Note.update(note: note) else { return nil } //addNeeded defaults to true

        return await add(note: incoming)
    }

    @discardableResult
    func add(note: Note) async -> Note? {
        guard NoteSessionManager.isOnline else { return note }

        switch await addToServer(note: note) {
            case let .success(newNote):
                return newNote
            case let .failure(error):
                showErrorMessage(message: error.message)
                return note
        }
    }

    private func addToServer(note: Note) async -> Result<Note?, NoteError> {
        let guid = note.guid ?? UUID().uuidString
        note.guid = guid

        // Several paths can upload the same pending note; only one request may be in flight for it.
        guard notesBeingAdded.insert(guid).inserted else {
            return .success(note)
        }

        defer {
            notesBeingAdded.remove(guid)
        }

        let sent = EditableFields(note)
        let parameters: Parameters = ["title": note.title as Any,
                                      "content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        let router = Router.createNote(parameters: parameters)

        switch await performDecodable(router, of: NoteStruct.self, retryLimit: 2) {
            case let .success(remote):
                // Deleted locally while the upload was in flight: remove the server copy as well.
                guard note.managedObjectContext != nil else {
                    _ = await perform(Router.deleteNote(id: Int(remote.id)), requireJSONContentType: false, retryLimit: 2)
                    return .success(nil)
                }

                note.id = remote.id
                note.readOnly = remote.readOnly
                note.etag = remote.etag
                note.addNeeded = false

                // Edits made while the upload was in flight win over the server's echo of the older version.
                let editedMeanwhile = EditableFields(note) != sent

                if editedMeanwhile {
                    note.updateNeeded = true
                } else {
                    note.modified = remote.modified
                    note.title = remote.title
                    note.content = remote.content
                    note.category = remote.category
                    note.updateNeeded = false
                }

                let saved = Note.update(note: note)

                if editedMeanwhile, case let .failure(error) = await updateOnServer(note) {
                    showErrorMessage(message: error.message)
                }

                return .success(saved)
            case let .failure(error):
                let message = ErrorMessage(title: NSLocalizedString("Error Adding Note", comment: "The title of an error message"),
                                           body: error.localizedDescription)
                return .failure(NoteError(message: message))
        }
    }

    func get(note: NoteProtocol) async {
        logger.notice("Getting note...")

        // Unpushed local changes win until they are pushed, so there is nothing to fetch.
        guard !note.addNeeded, !note.updateNeeded, !note.deleteNeeded, NoteSessionManager.isOnline else { return }

        let router = Router.getNote(id: Int(note.id), etag: note.etag)
        let validStatusCodes = KeychainHelper.notesApiVersion == Router.defaultApiVersion ? 200..<300 : 200..<201

        switch await performDecodable(router, of: NoteStruct.self, validStatusCodes: validStatusCodes) {
            case let .success(remote):
                Note.merge(remote: [remote])
            case let .failure(error):
                switch error.statusCode {
                    case nil, 304, 400, 404: // Transport error, not modified, bad request, or deleted remotely (the next pull removes it)
                        break
                    default:
                        let message = ErrorMessage(title: NSLocalizedString("Error Getting Note", comment: "The title of an error message"),
                                                   body: error.localizedDescription)
                        showErrorMessage(message: message)
                }
        }
    }

    func update(note: NoteProtocol, updateModified: Bool = true) async {
        logger.notice("Updating note...")

        var incoming = note
        incoming.updateNeeded = true

        guard NoteSessionManager.isOnline else {
            Note.update(notes: [incoming])
            return
        }

        // A note the server has not seen yet is uploaded as a whole instead.
        if incoming.addNeeded {
            Note.update(notes: [incoming])

            if let pending = managedNote(for: incoming) {
                await add(note: pending)
            }

            return
        }

        if case let .failure(error) = await updateOnServer(incoming, updateModified: updateModified) {
            showErrorMessage(message: error.message)
        }
    }

    private func updateOnServer(_ note: NoteProtocol, updateModified: Bool = true) async -> Result<Void, NoteError> {
        let parameters: Parameters

        if note.readOnly || note.error {
            // The server rejects other changes to these notes, and their content must never be sent back.
            parameters = ["favorite": note.favorite]
        } else {
            // Metadata-only changes (e.g. toggling favorite) keep the existing modification date so the note does
            // not jump to the top of a date-sorted list and the row is not re-sorted a second time after the sync.
            let modified = updateModified ? Date().timeIntervalSince1970 : note.modified
            parameters = ["title": note.title as Any,
                          "content": note.content as Any,
                          "category": note.category as Any,
                          "modified": modified as Any,
                          "favorite": note.favorite]
        }

        let sent = EditableFields(note)
        let sentId = note.id
        let router = Router.updateNote(id: Int(note.id), parameters: parameters)

        switch await performDecodable(router, of: NoteStruct.self, retryLimit: 2) {
            case let .success(remote):
                // A newer local edit made while this request was in flight stays pending instead of being reverted.
                guard EditableFields(note) == sent else {
                    return .success(())
                }

                Note.update(notes: [remote])
                return .success(())
            case let .failure(error):
                Note.update(notes: [note])

                switch error.statusCode {
                    case 403:
                        // Read-only on the server: drop the rejected change and restore the server copy.
                        if let rejected = managedNote(for: note) {
                            rejected.updateNeeded = false
                            // Unconditional fetch: the server copy is unchanged, so a conditional one would get 304.
                            rejected.etag = ""
                            Note.update(notes: [rejected])
                            await get(note: rejected)
                        }

                        let message = ErrorMessage(title: NSLocalizedString("Error Updating Note", comment: "The title of an error message"),
                                                   body: NSLocalizedString("This note is read-only. Your changes were not saved.", comment: "An error message"))
                        return .failure(NoteError(message: message))
                    case 404 where error.isNotesAppResponse, 405:
                        // A late answer to an older request must not re-create an already re-created note.
                        if note.id == sentId {
                            await recreateOnServer(note)
                        }

                        return .success(())
                    default:
                        let message = ErrorMessage(title: NSLocalizedString("Error Updating Note", comment: "The title of an error message"),
                                                   body: error.localizedDescription)
                        return .failure(NoteError(message: message))
                }
        }
    }

    func delete(note: NoteProtocol) async {
        logger.notice("Deleting note...")

        var incoming = note
        incoming.deleteNeeded = true

        if incoming.addNeeded {
            Note.delete(note: incoming)
            return
        }

        guard NoteSessionManager.isOnline else {
            Note.update(notes: [incoming])
            return
        }

        if case let .failure(error) = await deleteOnServer(incoming) {
            showErrorMessage(message: error.message)
        }
    }

    private func deleteOnServer(_ note: NoteProtocol) async -> Result<Void, NoteError> {
        let router = Router.deleteNote(id: Int(note.id))

        switch await perform(router, requireJSONContentType: false, retryLimit: 2) {
            case .success:
                Note.delete(note: note)
                return .success(())
            case let .failure(error):
                switch error.statusCode {
                    case 404:
                        // The note is already gone from the server, delete it locally.
                        Note.delete(note: note)
                        return .success(())
                    case 403:
                        // Read-only on the server: the note stays, so show it again.
                        if let kept = managedNote(for: note) {
                            kept.deleteNeeded = false
                            Note.update(notes: [kept])
                        }

                        let message = ErrorMessage(title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                                                   body: NSLocalizedString("This note is read-only and cannot be deleted.", comment: "An error message"))
                        return .failure(NoteError(message: message))
                    case 423:
                        let message = ErrorMessage(title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                                                   body: NSLocalizedString("Unable to delete locked file on server", comment: ""))
                        Note.delete(note: note)
                        return .failure(NoteError(message: message))
                    default:
                        let message = ErrorMessage(title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                                                   body: error.localizedDescription)
                        Note.update(notes: [note])
                        return .failure(NoteError(message: message))
                }
        }
    }

    ///
    /// Re-creates a note the server no longer has, keeping the local content: an edit wins over a remote delete.
    ///
    private func recreateOnServer(_ note: NoteProtocol) async {
        guard let orphan = managedNote(for: note) else { return }

        orphan.id = -1
        orphan.addNeeded = true
        orphan.updateNeeded = false

        if orphan.guid == nil {
            orphan.guid = UUID().uuidString
        }

        Note.update(notes: [orphan])
        await add(note: orphan)
    }

    private func managedNote(for note: NoteProtocol) -> Note? {
        if let managed = note as? Note, managed.managedObjectContext != nil {
            return managed
        }

        if note.id > 0 {
            return Note.note(id: note.id)
        }

        return note.guid.flatMap(Note.note(guid:))
    }

    // MARK: - Requests

    ///
    /// Perform the request described by the router: validates the status code first
    /// (so a 304 surfaces as a failure carrying its status), then the content type
    /// (skipped for empty bodies), retrying up to `retryLimit` times on HTTP 423.
    ///
    private func perform(_ router: Router,
                         validStatusCodes: Range<Int> = 200..<300,
                         requireJSONContentType: Bool = true,
                         retryLimit: Int = 0) async -> Result<HTTPResult, RequestError> {
        var attempt = 0

        while true {
            let request: URLRequest

            do {
                request = try router.asURLRequest()
            } catch {
                return .failure(.transport(error))
            }

            let data: Data
            let response: URLResponse

            do {
                (data, response) = try await session.data(for: request)
            } catch {
                return .failure(.transport(error))
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.transport(URLError(.badServerResponse)))
            }

            let result = HTTPResult(data: data, response: httpResponse)

            guard validStatusCodes.contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 423, attempt < retryLimit { // File lock on server
                    attempt += 1

                    do {
                        try await Task.sleep(for: retryDelay)
                    } catch {
                        return .failure(.transport(error))
                    }

                    continue
                }

                return .failure(.unacceptableStatusCode(result))
            }

            if requireJSONContentType,
               !data.isEmpty,
               httpResponse.mimeType?.lowercased() != Router.applicationJson {
                return .failure(.unacceptableContentType(result))
            }

            return .success(result)
        }
    }

    private func performDecodable<T: Decodable>(_ router: Router,
                                                of type: T.Type,
                                                validStatusCodes: Range<Int> = 200..<300,
                                                retryLimit: Int = 0) async -> Result<T, RequestError> {
        switch await perform(router, validStatusCodes: validStatusCodes, retryLimit: retryLimit) {
            case let .success(result):
                do {
                    return .success(try JSONDecoder().decode(T.self, from: result.data))
                } catch {
                    return .failure(.decoding(error, result))
                }
            case let .failure(error):
                return .failure(error)
        }
    }

    /// Synchronous per-host reachability check.
    private nonisolated static func hostIsReachable(_ host: String) -> Bool {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else { return false }

        var flags = SCNetworkReachabilityFlags()

        guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return false }

        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutIntervention = canConnectAutomatically && !flags.contains(.interventionRequired)

        return flags.contains(.reachable) && (!flags.contains(.connectionRequired) || canConnectWithoutIntervention)
    }

    // MARK: - Messages

    private func showErrorMessage(message: ErrorMessage) {
        // A cancelled flow (dismissed pull-to-refresh, expired background task) must not surface banners.
        guard !Task.isCancelled else { return }

        presentError(message)
    }

    private static func showBanner(for message: ErrorMessage) {
        #if !os(OSX)
        var config = SwiftMessages.defaultConfig
        config.interactiveHide = true
        config.duration = .forever
        config.preferredStatusBarStyle = .default
        SwiftMessages.show(config: config, viewProvider: {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.error, iconStyle: .default)
            view.configureDropShadow()
            view.button?.isHidden = true
            view.configureContent(title: message.title,
                                  body: message.body,
                                  iconImage: Icon.error.image
            )
            return view
        })
        #endif
    }

}
