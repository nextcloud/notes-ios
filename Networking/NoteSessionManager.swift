// SPDX-FileCopyrightText: 2020 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import NextcloudKit
import os
import SwiftMessages
import SystemConfiguration
import UIKit

struct ErrorMessage {
    var title: String
    var body: String
}

///
/// Server trust handling for the notes session: accepts the saved self-signed
/// certificate when the user allowed it, default evaluation otherwise.
///
final class NotesURLSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

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

private struct HTTPResult {
    let data: Data
    let response: HTTPURLResponse
}

private enum RequestError: Error, LocalizedError {
    case invalidRequest(Error)
    case transport(Error)
    case unacceptableStatusCode(HTTPResult)
    case unacceptableContentType(HTTPResult)
    case decoding(Error, HTTPResult)

    var response: HTTPURLResponse? {
        switch self {
        case .invalidRequest, .transport:
            return nil
        case let .unacceptableStatusCode(result), let .unacceptableContentType(result):
            return result.response
        case let .decoding(_, result):
            return result.response
        }
    }

    var statusCode: Int? {
        response?.statusCode
    }

    var isTimedOut: Bool {
        if case let .transport(error) = self {
            return (error as? URLError)?.code == .timedOut
        }

        return false
    }

    var errorDescription: String? {
        switch self {
        case let .invalidRequest(error), let .transport(error), let .decoding(error, _):
            return error.localizedDescription
        case let .unacceptableStatusCode(result):
            return "Response status code was unacceptable: \(result.response.statusCode)."
        case let .unacceptableContentType(result):
            return "Response Content-Type \"\(result.response.mimeType ?? "unknown")\" was unacceptable."
        }
    }
}

@MainActor
class NoteSessionManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NoteSessionManager")

    struct NoteError: Error {
        var message: ErrorMessage
    }

    static let shared = NoteSessionManager()

    private var notesBeingAdded = Set<String>()

    private let session: URLSession

    nonisolated class var isConnectedToServer: Bool {
        guard let url = URL(string: KeychainHelper.server),
            let host = url.host else {
            return false
        }

        return hostIsReachable(host)
    }

    nonisolated class var isOnline: Bool {
        return NoteSessionManager.isConnectedToServer && !Store.shared.offlineMode
    }

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 30
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        configuration.httpAdditionalHeaders = ["User-Agent": userAgent]
        session = URLSession(configuration: configuration, delegate: NotesURLSessionDelegate(), delegateQueue: nil)
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

                switch error.statusCode {
                    case nil, 400: // Transport error, or bad request (endpoint not supported)
                        break
                    case 401:
                        let title = NSLocalizedString("Unauthorized", comment: "An error message title")
                        let body = NSLocalizedString("Check username and password.", comment: "An error message")
                        showErrorMessage(message: ErrorMessage(title: title, body: body))
                    default:
                        let message = ErrorMessage(title: NSLocalizedString("Error Getting Settings", comment: "The title of an error message"),
                                                   body: error.localizedDescription)
                        showErrorMessage(message: message)
                }
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

                switch error.statusCode {
                    case nil, 400: // Transport error, or bad request (endpoint not supported)
                        break
                    case 401:
                        let title = NSLocalizedString("Unauthorized", comment: "An error message title")
                        let body = NSLocalizedString("Check username and password.", comment: "An error message")
                        showErrorMessage(message: ErrorMessage(title: title, body: body))
                    default:
                        let message = ErrorMessage(title: NSLocalizedString("Error Updating Settings", comment: "The title of an error message"),
                                                   body: error.localizedDescription)
                        showErrorMessage(message: message)
                }
        }
    }

    ///
    /// Synchronize the notes: push local deletions, additions and updates, then pull remote changes.
    ///
    func sync() async {
        logger.notice("Synchronizing...")

        await pushLocalDeletions()
        await pushLocalAdditions()
        await pushLocalUpdates()
        await pullRemoteChanges()
    }

    private func pushLocalDeletions() async {
        guard let notesToDelete = Note.notes(property: "deleteNeeded"), !notesToDelete.isEmpty else { return }

        for note in notesToDelete {
            await delete(note: note)
        }
    }

    private func pushLocalAdditions() async {
        guard let notesToAdd = Note.notes(property: "addNeeded"), !notesToAdd.isEmpty else { return }

        for note in notesToAdd {
            if let guid = note.guid, notesBeingAdded.contains(guid) {
                continue
            }

            _ = await addToServer(note: note)
        }
    }

    private func pushLocalUpdates() async {
        guard let notesToUpdate = Note.notes(property: "updateNeeded"), !notesToUpdate.isEmpty else { return }

        for note in notesToUpdate {
            await update(note: note)
        }
    }

    private func pullRemoteChanges() async {
        switch await perform(Router.allNotes(exclude: ""), retryLimit: 2) {
            case let .success(result):
                if let lastModifiedString = result.response.value(forHTTPHeaderField: "Last-Modified") {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
                    let lastModifiedDate = dateFormatter.date(from: lastModifiedString) ?? Date.distantPast
                    KeychainHelper.lastModified = Int(lastModifiedDate.timeIntervalSince1970)
                }

                if let etag = result.response.value(forHTTPHeaderField: "Etag") {
                    KeychainHelper.eTag = etag
                }

                guard let json = try? JSONSerialization.jsonObject(with: result.data, options: .allowFragments),
                      let jsonArray = json as? Array<[String: Any]> else {
                    logger.error("Unexpected payload received for the list of all notes.")
                    return
                }

                if let serverIds = jsonArray.map({ $0["id"] }) as? [Int64],
                    let knownIds = Note.all()?.map({ $0.id }).filter({ $0 > 0 }) {
                    let deletedOnServer = Set(knownIds).subtracting(Set(serverIds))

                    if !deletedOnServer.isEmpty {
                        Note.delete(ids: Array(deletedOnServer))
                    }
                }

                let filteredDicts = jsonArray.filter({ $0.keys.count > 1 })

                if !filteredDicts.isEmpty {
                    let notes = filteredDicts.map { NoteStruct(dictionary: $0) }
                    Note.update(notes: notes)
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

    @discardableResult
    func add(content: String, category: String, favorite: Bool = false) async -> Note? {
        logger.notice("Adding note...")

        let note = NoteStruct(content: content, category: category, favorite: favorite)

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
        let parameters: Parameters = ["title": note.title as Any,
                                      "content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        let router = Router.createNote(parameters: parameters)

        if let guid = note.guid {
            notesBeingAdded.insert(guid)
        }

        defer {
            if let guid = note.guid {
                notesBeingAdded.remove(guid)
            }
        }

        switch await performDecodable(router, of: NoteStruct.self, retryLimit: 2) {
            case let .success(remote):
                note.id = remote.id
                note.modified = remote.modified
                note.title = remote.title
                note.content = remote.content
                note.category = remote.category
                note.addNeeded = false
                note.updateNeeded = false
                return .success(Note.update(note: note))
            case let .failure(error):
                let message = ErrorMessage(title: NSLocalizedString("Error Adding Note", comment: "The title of an error message"),
                                           body: error.localizedDescription)
                return .failure(NoteError(message: message))
        }
    }

    func get(note: NoteProtocol) async {
        logger.notice("Getting note...")

        guard NoteSessionManager.isOnline else { return }

        let router = Router.getNote(id: Int(note.id), exclude: "", etag: note.etag)
        let validStatusCodes = KeychainHelper.notesApiVersion == Router.defaultApiVersion ? 200..<300 : 200..<201

        switch await performDecodable(router, of: NoteStruct.self, validStatusCodes: validStatusCodes) {
            case let .success(remote):
                Note.update(notes: [remote])
            case let .failure(error):
                switch error.statusCode {
                    case nil, 304, 400: // Transport error, not modified, or bad request
                        break
                    case 404:
                        if let guid = note.guid, let dbNote = Note.note(guid: guid) {
                            await add(note: dbNote)
                        }
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

        if case let .failure(error) = await updateOnServer(incoming, updateModified: updateModified) {
            showErrorMessage(message: error.message)
        }
    }

    private func updateOnServer(_ note: NoteProtocol, updateModified: Bool = true) async -> Result<Void, NoteError> {
        // Metadata-only changes (e.g. toggling favorite) keep the existing modification date so the note does
        // not jump to the top of a date-sorted list and the row is not re-sorted a second time after the sync.
        let modified = updateModified ? Date().timeIntervalSince1970 : note.modified
        let parameters: Parameters = ["title": note.title as Any,
                                      "content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": modified as Any,
                                      "favorite": note.favorite]
        let router = Router.updateNote(id: Int(note.id), paramters: parameters)

        switch await performDecodable(router, of: NoteStruct.self, retryLimit: 2) {
            case let .success(remote):
                Note.update(notes: [remote])
                return .success(())
            case let .failure(error):
                Note.update(notes: [note])

                switch error.statusCode {
                    case 404, 405:
                        if let guid = note.guid, let dbNote = Note.note(guid: guid) {
                            await add(note: dbNote)
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
                return .failure(.invalidRequest(error))
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
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
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

    func showSyncMessage() {
        #if os(iOS)
        var config = SwiftMessages.defaultConfig
        config.duration = .forever
        config.preferredStatusBarStyle = .default
        config.presentationContext = .viewController(UIApplication.topViewController()!)
        SwiftMessages.show(config: config, viewProvider: {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.success, iconStyle: .default)
            view.configureDropShadow()
            view.configureContent(title: NSLocalizedString("Success", comment: "A message title"),
                                  body: NSLocalizedString("You are now connected to Notes on your server", comment: "A message"),
                                  iconImage: Icon.success.image,
                                  iconText: nil,
                                  buttonImage: nil,
                                  buttonTitle: NSLocalizedString("Close & Sync", comment: "Title of a button allowing the user to close the login screen and sync with the server"),
                                  buttonTapHandler: { _ in
                                    SwiftMessages.hide()
                                    UIApplication.topViewController()?.dismiss(animated: true, completion: nil)
                                    NotificationCenter.default.post(name: .syncNotes, object: nil)
            })
            return view
        })
        #endif
    }

    func showErrorMessage(message: ErrorMessage) {
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
