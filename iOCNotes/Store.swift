// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit
import SwiftyJSON
import UIKit

@Observable
final class Store: Logging, Storing {
    let logger = makeLogger()

    ///
    /// This singleton is necessary to conveniently expose the same environment object used in SwiftUI to the already existing UIKit code.
    ///
    static let shared = Store()

    init() {
        reloadAccounts()
    }

    // MARK: Synchronization

    var isSynchronizing = false

    // swiftlint:disable function_body_length

    ///
    /// Fetch filtered capability information from the server of the given account.
    ///
    private func fetchCapabilities(for account: AccountTransferObject) async {
        logger.notice("Fetching capabilities for account \"\(account.id)\"...")

        let directEditingSupportsFileIdKeyPath = [
            "ocs",
            "data",
            "capabilities",
            "files",
            "directEditing",
            "supportsFileId"
        ]

        let directEditingKeyPath = [
            "ocs",
            "data",
            "capabilities",
            "richdocuments",
            "direct_editing"
        ]

        let notesVersionKeypath = [
            "ocs",
            "data",
            "capabilities",
            "notes",
            "version"
        ]

        let notesApiVersionKeyPath = [
            "ocs",
            "data",
            "capabilities",
            "notes",
            "api_version"
        ]

        let serverVersionKeyPath = [
            "ocs",
            "data",
            "version"
        ]

        let (_, _, data, error) = await NextcloudKit.shared.getCapabilitiesAsync(account: account.id)

        guard error == .success else {
            logger.error("Failed to fetch capabilities: \(error.localizedDescription, privacy: .public)")
            return
        }

        guard let data = data?.data else {
            logger.error("No data to parse as capabilities received!")
            return
        }

        let capabilities = JSON(data)

        logger.debug("Received capabilities for account \"\(account.id)\": \(capabilities.debugDescription)")

        KeychainHelper.directEditing = capabilities[directEditingKeyPath].boolValue
        KeychainHelper.directEditingSupportsFileId = capabilities[directEditingSupportsFileIdKeyPath].boolValue
        KeychainHelper.notesVersion = capabilities[notesVersionKeypath].stringValue
        KeychainHelper.notesApiVersion = capabilities[notesApiVersionKeyPath].array?.last?.string ?? ""
        KeychainHelper.serverMajorVersion = capabilities[serverVersionKeyPath]["major"].int ?? 0
        KeychainHelper.serverMinorVersion = capabilities[serverVersionKeyPath]["minor"].int ?? 0
        KeychainHelper.serverMicroVersion = capabilities[serverVersionKeyPath]["micro"].int ?? 0
    }

    // swiftlint:enable function_body_length

    func synchronize() {
        guard NoteSessionManager.isOnline else {
            logger.debug("Cancelling synchronization because device is not online.")
            return
        }

        logger.debug("Synchronizing...")
        isSynchronizing = true

        Task {
            for account in accounts {
                NextcloudKit.shared.appendSession(
                    account: account.id,
                    urlBase: account.baseURL,
                    user: account.userId,
                    userId: account.userId,
                    password: account.password,
                    userAgent: userAgent,
                    groupIdentifier: NCBrandOptions.shared.capabilitiesGroup
                )

                await fetchCapabilities(for: account)
            }

            await NoteSessionManager.shared.status()
            await NoteSessionManager.shared.settings()
            await NoteSessionManager.shared.sync()

            isSynchronizing = false
            logger.debug("Synchronization completed.")
        }
    }

    // MARK: Account Management

    var accounts = [AccountTransferObject]()

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

        guard let assembledComponents = canonicalServerComponents(from: KeychainHelper.server),
              let baseURL = assembledComponents.url?.absoluteString else {
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

    func addAccount(host: URL, name: String, password: String) {
        logger.debug("Creating account for user \"\(name)\" on \"\(host)\"...")

        KeychainHelper.server = host.absoluteString
        KeychainHelper.username = name
        KeychainHelper.password = password

        reloadAccounts()
        synchronize()
    }

    func removeAccount() {
        logger.debug("Removing account...")

        KeychainHelper.server = ""
        KeychainHelper.username = ""
        KeychainHelper.password = ""
        Note.reset()
        reloadAccounts()
    }

    // MARK: Shared Accounts

    var sharedAccounts = [NKShareAccounts.DataAccounts]()

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

    // MARK: Settings

    var fileExtension: FileSuffix {
        get {
            KeychainHelper.fileSuffix
        }
        set {
            logger.debug("Setting file extension to \"\(newValue)\".")
            KeychainHelper.fileSuffix = newValue
        }
    }

    var internalEditor: Bool {
        get {
            KeychainHelper.internalEditor
        }
        set {
            logger.debug("Setting internal editor enabled to \(newValue).")
            KeychainHelper.internalEditor = newValue
        }
    }

    var notesPath: String {
        get {
            KeychainHelper.notesPath
        }
        set {
            logger.debug("Setting notes path to \"\(newValue)\".")
            KeychainHelper.notesPath = newValue
        }
    }

    var offlineMode: Bool {
        get {
            KeychainHelper.offlineMode
        }
        set {
            logger.debug("Setting offline mode enabled to \(newValue).")
            KeychainHelper.offlineMode = newValue
        }
    }

    var launchSynchronization: Bool {
        get {
            KeychainHelper.syncOnStart
        }
        set {
            logger.debug("Setting startup synchronization enabled to \(newValue).")
            KeychainHelper.syncOnStart = newValue
        }
    }
}
