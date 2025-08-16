//
//  NoteSessionManager.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/6/19.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Alamofire
import Foundation
import UIKit
import SwiftMessages
import os

typealias SyncCompletionBlock = () -> Void
typealias SyncCompletionBlockWithNote = (_ note: CDNote?) -> Void

struct ErrorMessage {
    var title: String
    var body: String
}

final class NotesServerTrustPolicyManager: ServerTrustManager {
    override func serverTrustEvaluator(forHost host: String) -> ServerTrustEvaluating? {
        let server = KeychainHelper.server
        if KeychainHelper.allowUntrustedCertificate,
           !host.isEmpty,
           let serverHost = URLComponents(string: server)?.host,
           host == serverHost,
           let certificate = ServerStatus.shared.savedCert(host: host) {
            return PinnedCertificatesTrustEvaluator(certificates: [certificate],
                                                    acceptSelfSignedCertificates: true,
                                                    performDefaultValidation: false,
                                                    validateHost: false)
        } else {
            return DefaultTrustEvaluator()
        }
    }
}

final class LoginRequestInterceptor: RequestInterceptor {

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let _ = request.request?.url else {
            return completion(.doNotRetryWithError(error))
        }
        
        guard request.retryCount <= 1 else {
            return completion(.doNotRetryWithError(error))
        }

        return completion(.doNotRetryWithError(error))
    }

}

final class NoteRequestInterceptor: RequestInterceptor {

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        guard let _ = request.request?.url,
              let afError = error as? AFError else {
            return completion(.doNotRetryWithError(error))
        }

        guard request.retryCount <= 1 else {
            return completion(.doNotRetryWithError(error))
        }

        switch afError.responseCode {
        case 304:
            completion(.doNotRetry)
        case 404:
            completion(.doNotRetryWithError(error))
        case 405:
            completion(.doNotRetryWithError(error))
        case 423: // File lock on server, retry once
            completion(.retryWithDelay(2))
        default:
            completion(.doNotRetryWithError(error))
        }
    }

}

class NoteSessionManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NoteSessionManager")

    struct NoteError: Error {
        var message: ErrorMessage
    }
    
    enum Result<CDNote, NoteError> {
        case success(CDNote?)
        case failure(NoteError)
    }

    typealias SyncHandler = (Result<CDNote, NoteError>) -> Void

    static let shared = NoteSessionManager()

    private var notesBeingAdded = Set<String>()
    
    private var session: Session

    class var isConnectedToServer: Bool {
        guard let url = URL(string: KeychainHelper.server),
            let host = url.host else {
            return false
        }
        return NetworkReachabilityManager(host: host)?.isReachable ?? false
    }

    class var isOnline: Bool {
        return NoteSessionManager.isConnectedToServer && !Store.shared.offlineMode
    }
    
    init() {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForResource = 30
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        session = Session(configuration: configuration, serverTrustManager: NotesServerTrustPolicyManager(allHostsMustBeEvaluated: true, evaluators: [:]))
    }

    ///
    /// Fetch the server status.
    ///
    /// - Parameters:
    ///     - completion: Optional completion handler to call afterwards.
    ///
    func status(completion: SyncCompletionBlock? = nil) {
        logger.notice("Fetching status...")

        let router = StatusRouter.status
        session
            .request(router)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: CloudStatus.self) { response in
                switch response.result {
                case let .success(result):
                    KeychainHelper.productVersion = result.versionstring
                    KeychainHelper.productName = result.productname
                case let .failure(error):
                    print(error.localizedDescription)
                }
                completion?()
        }
    }

    ///
    /// Asynchronous wrapper for ``status(completion:)``.
    ///
    func status() async {
        await withCheckedContinuation { continuation in
            status {
                continuation.resume()
            }
        }
    }

    ///
    /// Fetch the user settings for Nextcloud Notes from the server.
    ///
    /// - Parameters:
    ///     - completion: Optional completion handler to call afterwards.
    ///
    func settings(completion: SyncCompletionBlock? = nil) {
        logger.debug("Fetching notes user settings from server...")

        let router = Router.settings

        session
        .request(router, interceptor: LoginRequestInterceptor())
        .validate(statusCode: 200..<300)
        .validate(contentType: [Router.applicationJson])
        .responseDecodable(of: SettingsStruct.self) { [self] response in
            switch response.result {
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
                    logger.error("Error during settings retrieval: \(error, privacy: .public)")

                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                            case 400: // Bad request, endpoint not supported
                                print(error)
                            case 401:
                                let title = NSLocalizedString("Unauthorized", comment: "An error message title")
                                let body = NSLocalizedString("Check username and password.", comment: "An error message")
                                NoteSessionManager.shared.showErrorMessage(message: ErrorMessage(title: title, body: body))
                            default:
                                let message = ErrorMessage(title: NSLocalizedString("Error Getting Settings", comment: "The title of an error message"),
                                                           body: error.localizedDescription)
                                self.showErrorMessage(message: message)
                        }
                    }
            }

            completion?()
        }
    }

    ///
    /// Asynchronous wrapper for ``settings(completion:)``.
    ///
    func settings() async {
        await withCheckedContinuation { continuation in
            settings {
                continuation.resume()
            }
        }
    }

    func updateSettings(completion: SyncCompletionBlock? = nil) {
        logger.debug("Updating notes user settings on server...")

        let router = Router.updateSettings(notesPath: Store.shared.notesPath, fileSuffix: Store.shared.fileExtension.suffix)

        session
        .request(router)
        .validate(statusCode: 200..<300)
        .validate(contentType: [Router.applicationJson])
        .responseData { [self] response in
            switch response.result {
                case .success( _):
                    logger.debug("Successfully updated notes user settings on server.")
                    completion?()
                case let .failure(error):
                    logger.debug("Error while updating notes user settings on server: \(error.localizedDescription, privacy: .public)")

                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                            case 400: // Bad request, endpoint not supported
                                print(error)
                            case 401:
                                let title = NSLocalizedString("Unauthorized", comment: "An error message title")
                                let body = NSLocalizedString("Check username and password.", comment: "An error message")
                                NoteSessionManager.shared.showErrorMessage(message: ErrorMessage(title: title, body: body))
                            default:
                                let message = ErrorMessage(title: NSLocalizedString("Error Updating Settings", comment: "The title of an error message"),
                                                           body: error.localizedDescription)
                                self.showErrorMessage(message: message)
                        }
                    }

                    completion?()
            }
        }
    }

    ///
    /// Actually synchronize the notes.
    ///
    func sync(completion: SyncCompletionBlock? = nil) {
        logger.notice("Synchronizing...")

        func deleteOnServer(completion: @escaping SyncCompletionBlock) {
            if let notesToDelete = CDNote.notes(property: "cdDeleteNeeded"),
                !notesToDelete.isEmpty {
                let group = DispatchGroup()
                
                for note in notesToDelete {
                    group.enter()
                    NoteSessionManager.shared.delete(note: note, completion: {
                        group.leave()
                    })
                }
                
                group.notify(queue: .main) {
                    print("Finished all requests.")
                    completion()
                }
            } else {
                completion()
            }
        }

        func addOnServer(completion: @escaping SyncCompletionBlock) {
            if let notesToAdd = CDNote.notes(property: "cdAddNeeded"),
                !notesToAdd.isEmpty {
                let group = DispatchGroup()
                
                for note in notesToAdd {
                    if let guid = note.guid,
                        notesBeingAdded.contains(guid) {
                        continue
                    }
                    
                    group.enter()
                    self.addToServer(note: note) { _ in
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    print("Finished all requests.")
                    completion()
                }
            } else {
                completion()
            }
        }

        func updateOnServer(completion: @escaping SyncCompletionBlock) {
            if let notesToUpdate = CDNote.notes(property: "cdUpdateNeeded"),
                !notesToUpdate.isEmpty {
                let group = DispatchGroup()

                for note in notesToUpdate {
                    group.enter()
                    NoteSessionManager.shared.update(note: note, completion: {
                        group.leave()
                    })
                }

                group.notify(queue: .main) {
                    print("Finished all requests.")
                    completion()
                }
            } else {
                completion()
            }
        }

        deleteOnServer {
            addOnServer {
                updateOnServer {
                    let router = Router.allNotes(exclude: "")
                    self.session
                        .request(router, interceptor: NoteRequestInterceptor())
                        .validate(statusCode: 200..<300)
                        .validate(contentType: [Router.applicationJson])
                        .responseJSON(completionHandler: { response in
                            switch response.result {
                            case let .success(json):
                                if let allHeaders = response.response?.allHeaderFields {
                                    if let lmIndex = allHeaders.index(forKey: "Last-Modified"),
                                        let lastModifiedString = allHeaders[lmIndex].value as? String {
                                        let dateFormatter = DateFormatter()
                                        dateFormatter.dateFormat = "EEEE, dd LLL yyyy HH:mm:ss zzz"
                                        let lastModifiedDate = dateFormatter.date(from: lastModifiedString) ?? Date.distantPast
                                        KeychainHelper.lastModified = Int(lastModifiedDate.timeIntervalSince1970)
                                    }
                                    if let etagIndex = allHeaders.index(forKey: "Etag"),
                                        let etag = allHeaders[etagIndex].value as? String {
                                        KeychainHelper.eTag = etag
                                    }
                                }
                                if let jsonArray = json as? Array<[String: Any]> {
                                    print(jsonArray)
                                    if let serverIds = jsonArray.map( { $0["id"] }) as? [Int64],
                                        let knownIds = CDNote.all()?.map({ $0.id }).filter({ $0 > 0 }) {
                                        let deletedOnServer = Set(knownIds).subtracting(Set(serverIds))
                                        if !deletedOnServer.isEmpty {
                                            CDNote.delete(ids: Array(deletedOnServer))
                                        }
                                    }
                                    let filteredDicts = jsonArray.filter({ $0.keys.count > 1 })
                                    if !filteredDicts.isEmpty {
                                        var notes = [NoteStruct]()
                                        for noteDict in filteredDicts {
                                            notes.append(NoteStruct(dictionary: noteDict))
                                        }
                                        CDNote.update(notes: notes)
                                    }
                                }
                            case let .failure(error):
                                if error.isResponseValidationError {
                                    switch error.responseCode {
                                    case 304:
                                        self.logger.notice("Remote notes did not change.")
                                        break
                                    default:
                                        let message = ErrorMessage(title: NSLocalizedString("Error Syncing Notes", comment: "The title of an error message"),
                                                                   body: error.localizedDescription)
                                        self.showErrorMessage(message: message)
                                    }
                                } else if error.isRequestRetryError {
                                    let message = ErrorMessage(title: NSLocalizedString("Error Syncing Notes", comment: "The title of an error message"),
                                                               body: "The server request timed out")
                                    self.showErrorMessage(message: message)
                                } else {
                                    let message = ErrorMessage(title: NSLocalizedString("Error Syncing Notes", comment: "The title of an error message"),
                                                               body: error.localizedDescription)
                                    self.showErrorMessage(message: message)
                                }
                            }
                            completion?()
                        })
                }
            }
        }
    }

    ///
    /// Asynchronous wrapper for ``sync(completion:)``
    ///
    func sync() async {
        await withCheckedContinuation { continuation in
            sync {
                continuation.resume()
            }
        }
    }

    func add(content: String, category: String, favorite: Bool? = false, completion: SyncCompletionBlockWithNote? = nil) {
        logger.notice("Adding note...")

        let note = NoteStruct(content: content, category: category, favorite: favorite ?? false)
        if  let incoming = CDNote.update(note: note) { //addNeeded defaults to true
            self.add(note: incoming, completion: completion)
        }
    }

    func add(note: CDNote, completion: SyncCompletionBlockWithNote? = nil) {
        if NoteSessionManager.isOnline {
            addToServer(note: note) { [weak self] result in
                switch result {
                case .success(let newNote):
                    completion?(newNote)
                case .failure(let error):
                    Task { @MainActor in
                        self?.showErrorMessage(message: error.message)
                    }
                    completion?(note)
                }
            }
        } else {
            completion?(note)
        }
    }

    func addToServer(note: CDNote, handler: @escaping SyncHandler) {
        let newNote = note
        var result: CDNote?
        let parameters: Parameters = ["title": note.title as Any,
                                      "content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": note.modified,
                                      "favorite": note.favorite]
        let router = Router.createNote(parameters: parameters)
        if let guid = newNote.guid {
            notesBeingAdded.insert(guid)
        }
        session
            .request(router, interceptor: NoteRequestInterceptor())
            .validate(statusCode: 200..<300)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: NoteStruct.self) { response in
                if let guid = newNote.guid {
                    self.notesBeingAdded.remove(guid)
                }
                switch response.result {
                case let .success(note):
                    newNote.id = note.id
                    newNote.modified = note.modified
                    newNote.title = note.title
                    newNote.content = note.content
                    newNote.category = note.category
                    newNote.addNeeded = false
                    newNote.updateNeeded = false
                    result = CDNote.update(note: newNote)
                    handler(.success(result))
                case let .failure(error):
                    let message = ErrorMessage(title: NSLocalizedString("Error Adding Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    handler(.failure(NoteError(message: message)))
                }
        }
    }

    func get(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        logger.notice("Getting note...")

        guard NoteSessionManager.isOnline else {
            completion?()
            return
        }
        let router = Router.getNote(id: Int(note.id), exclude: "", etag: note.etag)
        let validStatusCode = KeychainHelper.notesApiVersion == Router.defaultApiVersion ? 200..<300 : 200..<201
        let attachmentHelper = AttachmentHelper()
        
        session
            .request(router)
            .validate(statusCode: validStatusCode)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: NoteStruct.self, decoder: JSONDecoder()) { (response: AFDataResponse<NoteStruct>) in
                switch response.result {
                case let .success(note):
                    CDNote.update(notes: [note])
                    self.logger.debug("Checking server API version \(KeychainHelper.notesApiVersion, privacy: .public) for compatibility for attachment download")
                    guard
                        KeychainHelper.notesApiVersionisAtLeast("1.4")
                    else {
                        self.logger.warning("Server with API version \(KeychainHelper.notesApiVersion, privacy: .public) does not support attachment download (API version >= 1.4), not parsing and downloading attachments")
                        return
                    }

                    self.logger.debug("Searching for attachments")
                    let paths: [String] = attachmentHelper.extractRelativeAttachmentPaths(from: note.content, removeUrlEncoding: true)
                    self.logger.debug("Found the paths: \(paths, privacy: .public)")
                    
                    guard !paths.isEmpty else {
                        self.logger.notice("Searching for attachments completed, no paths found in note")
                        completion?()
                        return
                    }
                    
                    let group = DispatchGroup()
                    for path in paths {
                        group.enter()
                        Task { [weak self] in
                            guard let self else { return }
                            do {
                                let data = try await self.getAttachment(noteId: Int(note.id), path: path)
                                self.logger.debug("Attachment for note ID \(note.id, privacy: .public) and path \(path, privacy: .public) downloaded successfully")
                                try AttachmentStore.shared.store(data: data, noteId: Int(note.id), path: path)
                                self.logger.notice("Attachment for note ID \(note.id, privacy: .public) and path \(path, privacy: .public) stored successfully")
                            } catch {
                                self.logger.error("Attachment download for note ID \(note.id, privacy: .public) and path \(path, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                        group.leave()
                    }
                    
                    group.notify(queue: .main) {
                        completion?()
                    }
                    return

                case let .failure(error):
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 304:
                            // Not modified. Do nothing.
                            break
                        case 400:
                            print(error)
                        case 404:
                            if let guid = note.guid,
                                let dbNote = CDNote.note(guid: guid) {
                                self.add(note: dbNote, completion: nil)
                            }
                        default:
                            let message = ErrorMessage(title: NSLocalizedString("Error Getting Note", comment: "The title of an error message"),
                                                       body: error.localizedDescription)
                            self.showErrorMessage(message: message)
                        }
                    }
                }
                completion?()
            }
    }



    func getAttachment(noteId: Int, path: String) async throws -> Data {
        logger.notice("Getting attachment for noteId: \(noteId, privacy: .public), path: \(path, privacy: .public)")
        let router = Router.getAttachment(noteId: noteId, path: path)

        return try await session
            .request(router)
            .onURLRequestCreation { req in
                self.logger.debug("URL: \(req.url?.absoluteString ?? "nil", privacy: .public)")
              }
            .validate(statusCode: 200..<300)
            .serializingData()
            .value
    }

    func update(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        logger.notice("Updating note...")

        var incoming = note
        incoming.updateNeeded = true
        if NoteSessionManager.isOnline {
            updateOnServer(incoming) { [weak self] result in
                switch result {
                case .success( _):
                    completion?()
                case .failure(let error):
                    Task { @MainActor in
                        self?.showErrorMessage(message: error.message)
                    }
                    completion?()
                }
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }
    
    fileprivate func updateOnServer(_ note: NoteProtocol, handler: @escaping SyncHandler) {
        let parameters: Parameters = ["title": note.title as Any,
                                      "content": note.content as Any,
                                      "category": note.category as Any,
                                      "modified": Date().timeIntervalSince1970 as Any,
                                      "favorite": note.favorite]
        let router = Router.updateNote(id: Int(note.id), paramters: parameters)
        session
            .request(router, interceptor: NoteRequestInterceptor())
            .validate(statusCode: 200..<300)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: NoteStruct.self) { response in
                switch response.result {
                case let .success(note):
                    CDNote.update(notes: [note])
                    handler(.success(nil))
                case let .failure(error):
                    CDNote.update(notes: [note])
                    let message = ErrorMessage(title: NSLocalizedString("Error Updating Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404, 405:
                            if let guid = note.guid,
                                let dbNote = CDNote.note(guid: guid) {
                                self.add(note: dbNote, completion: nil)
                            }
                            handler(.success(nil))
                        default:
                            handler(.failure(NoteError(message: message)))
                        }
                    } else {
                        handler(.failure(NoteError(message: message)))
                    }
                }
        }
    }
    
    func createAttachment(noteId: Int,
                          fileData: Data,
                          filename: String,
                          mimeType: String,
                          completion: @escaping (Result<String, NoteError>) -> Void) {
        struct AttachmentResponse: Decodable {
            let filename: String
        }
        
        let router = Router.createAttachment(noteId: noteId)
        
        session
            .upload(multipartFormData: { form in
                form.append(fileData,
                            withName: "file",
                            fileName: filename,
                            mimeType: mimeType)
            }, with: router)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: AttachmentResponse.self) { response in
                switch response.result {
                case .success(let payload):
                    completion(.success(payload.filename))
                case .failure(let error):
                    let message = ErrorMessage(
                        title: NSLocalizedString("Error Creating Attachment", comment: ""),
                        body: error.localizedDescription
                    )
                    completion(.failure(NoteError(message: message)))
                }
            }
    }
    
    func delete(note: NoteProtocol, completion: SyncCompletionBlock? = nil) {
        logger.notice("Deleting note...")

        var incoming = note
        incoming.deleteNeeded = true
        if incoming.addNeeded {
            CDNote.delete(note: incoming)
            completion?()
        } else if NoteSessionManager.isOnline {
            deleteOnServer(incoming) { [weak self] result in
                switch result {
                case .success( _):
                    completion?()
                case .failure(let error):
                    Task { @MainActor in
                        self?.showErrorMessage(message: error.message)
                    }
                    completion?()
                }
            }
        } else {
            CDNote.update(notes: [incoming])
            completion?()
        }
    }

    fileprivate func deleteOnServer(_ note: NoteProtocol, handler: @escaping SyncHandler) {
        let router = Router.deleteNote(id: Int(note.id))
        session
            .request(router, interceptor: NoteRequestInterceptor())
            .validate(statusCode: 200..<300)
            .responseData { (response) in
                switch response.result {
                case .success:
                    CDNote.delete(note: note)
                    handler(.success(nil))
                case .failure(let error):
                    var message = ErrorMessage(title: NSLocalizedString("Error Deleting Note", comment: "The title of an error message"),
                                               body: error.localizedDescription)
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 404:
                            //Note doesn't exist on the server but we are obviously
                            //trying to delete it, so let's do that.
                            CDNote.delete(note: note)
                            handler(.success(nil))
                        case 423:
                            message.body = NSLocalizedString("Unable to delete locked file on server", comment: "")
                            CDNote.delete(note: note)
                            handler(.failure(NoteError(message: message)))
                        default:
                            CDNote.update(notes: [note])
                            handler(.failure(NoteError(message: message)))
                        }
                    }
                    if !message.body.isEmpty {
                        self.showErrorMessage(message: message)
                    }
                }
        }
    }

    @MainActor
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

    @MainActor
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
