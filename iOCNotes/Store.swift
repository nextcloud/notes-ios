// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import SwiftNextcloudUI
import UIKit

@Observable
final class Store: Logging, Storing {
    let logger = makeLogger()

    ///
    /// Required for `ServerAddressViewDelegate` conformance.
    ///
    /// Tasks are keyed by their login flow polling token.
    ///
    var pollingTasks = [String: Task<Void, any Error>]()

    ///
    /// This singleton is necessary to conveniently expose the same environment object used in SwiftUI to the already existing UIKit code.
    ///
    static let shared = Store()

    init() {
        reloadAccounts()
    }

    ///
    /// Loads all accounts from persistence and updates the related state of the store.
    ///
    private func reloadAccounts() {
        logger.debug("Reloading accounts...")

        // For historic reasons only a a single account is supported.
        // The persistence must be refactored to support multiple accounts.
        // This API already decouples calling code from the underlying persistence.
        // Support for multiple accounts then will only be a matter of refactoring the data layer and having a migration for it.

        guard KeychainHelper.username.isEmpty == false else {
            accounts = []
            return
        }

        guard KeychainHelper.password.isEmpty == false else {
            accounts = []
            return
        }

        guard KeychainHelper.server.isEmpty == false else {
            accounts = []
            return
        }

        guard let parsedComponents = URLComponents(string: KeychainHelper.server) else {
            accounts = []
            return
        }

        var assembledComponents = URLComponents()
        assembledComponents.scheme = parsedComponents.scheme
        assembledComponents.host = parsedComponents.host
        assembledComponents.port = parsedComponents.port

        guard let baseURL = assembledComponents.url?.absoluteString else {
            accounts = []
            return
        }

        let major = KeychainHelper.serverMajorVersion
        let minor = KeychainHelper.serverMinorVersion
        let micro = KeychainHelper.serverMicroVersion
        let serverVersion = ServerVersionTransferObject(major: major, minor: minor, micro: micro)

        accounts = [
            AccountTransferObject(
                baseURL: baseURL,
                password: KeychainHelper.password,
                serverVersion: serverVersion,
                userId: KeychainHelper.username
            )
        ]

        logger.debug("Completed reloading accounts.")
    }

    // MARK: - Storing Implementation

    var accounts = [AccountTransferObject]()

    var isSynchronizing = false

    func addAccount(host: URL, name: String, password: String) {
        logger.debug("Creating account for user \"\(name)\" on \"\(host)\"...")

        KeychainHelper.server = host.absoluteString
        KeychainHelper.username = name
        KeychainHelper.password = password

        reloadAccounts()
        synchronize()
    }

    func readSharedAccounts() {
        logger.debug("Reading shared accounts...")

        guard let appGroupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NCBrandOptions.shared.capabilitiesGroupApps) else {
            logger.error("Failed to get app group container!")
            return
        }

        guard let sharedAccounts = NKShareAccounts().getShareAccount(at: appGroupContainer, application: UIApplication.shared) else {
            logger.error("Failed to get shared accounts!")
            return
        }

        logger.debug("Found \(sharedAccounts.count) shared accounts.")
        self.sharedAccounts = sharedAccounts
    }

    func removeAccount() {
        logger.debug("Removing account...")

        KeychainHelper.server = ""
        KeychainHelper.username = ""
        KeychainHelper.password = ""
        CDNote.reset()
        reloadAccounts()
    }

    var sharedAccounts = [NKShareAccounts.DataAccounts]()

    func synchronize() {
        guard NoteSessionManager.isOnline else {
            logger.debug("Cancelling synchronization because device is not online.")
            return
        }

        logger.debug("Synchronizing...")
        isSynchronizing = true

        NoteSessionManager.shared.status {
            NCService.shared.startRequestServicesServer {
                NoteSessionManager.shared.settings {
                    NoteSessionManager.shared.sync { [self] in
                        isSynchronizing = false
                        logger.debug("Synchronization completed.")
                    }
                }
            }
        }
    }
}

// MARK: - ServerAddressViewDelegate

extension Store: ServerAddressViewDelegate {
    private func getResponse(endpoint: URL, token: String, options: NKRequestOptions) async -> (url: String, user: String, appPassword: String)? {
        logger.debug("Getting login flow status...")

        return await withCheckedContinuation { continuation in
            NextcloudKit.shared.getLoginFlowV2Poll(token: token, endpoint: endpoint.absoluteString, options: options) { [self] server, loginName, appPassword, _, error in
                if error == .success, let urlBase = server, let user = loginName, let appPassword {
                    logger.debug("Successfully got login flow status (server: \(urlBase), user: \(user), password: \(appPassword)).")
                    continuation.resume(returning: (urlBase, user, appPassword))
                } else {
                    logger.debug("Failed to get login flow status.")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func beginPolling(at url: URL) async throws -> URL {
        logger.debug("Beginning polling at \(url.absoluteString)")

        let (_, serverInfoResult) = await NextcloudKit.shared.getServerStatusAsync(serverUrl: url.absoluteString)

        switch serverInfoResult {
            case .success:
                let loginOptions = NKRequestOptions(customUserAgent: userAgent)
                let (endpoint, loginAddress, token) = try await NextcloudKit.shared.getLoginFlowV2(serverUrl: url.absoluteString, options: loginOptions)
                let options = NKRequestOptions(customUserAgent: userAgent)
                var grantValues: (url: String, user: String, appPassword: String)?

                logger.debug("Received login address \"\(loginAddress)\" with polling endpoint \"\(endpoint)\" and token \"\(token)\".")

                self.pollingTasks[token] = Task { @MainActor in
                    repeat {
                        grantValues = await getResponse(endpoint: endpoint, token: token, options: options)
                        try await Task.sleep(for: .seconds(1))
                    } while grantValues == nil

                    guard let grantValues else {
                        return
                    }

                    guard let host = URL(string: grantValues.url) else {
                        return
                    }

                    addAccount(host: host, name: grantValues.user, password: grantValues.appPassword)
                }

                return loginAddress
            case .failure(let nKError):
                logger.error("Received error as response to server status: \(nKError.errorDescription)")
                throw nKError.error
        }
    }

    func cancelPolling(by token: String) {
        logger.debug("Cancelling polling task by token \"\(token)\"...")

        guard let task = pollingTasks[token] else {
            logger.error("Attempt to cancel polling task by token \"\(token)\" which is not registered!")
            return
        }

        task.cancel()
        pollingTasks.removeValue(forKey: token)
        logger.debug("Polling task cancelled by token \"\(token)\".")
    }
}
