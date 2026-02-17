// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

///
/// The future connection between user interface and data persistence layer.
///
/// This is introduced for a gradual and long term change in architecture.
/// Through increasing isolation of features and layers with facilities like this future development can be accelerated.
///
protocol Storing: Observable {

    // MARK: Synchronization

    ///
    /// Whether the current account is synchronizing notes or not.
    ///
    /// This is needed to update the user interface state accordingly.
    ///
    var isSynchronizing: Bool { get }

    ///
    /// Synchronize set up accounts and their associated information as well as notes.
    ///
    func synchronize()

    // MARK: Account Management

    ///
    /// Returns all locally set up accounts for this app.
    ///
    var accounts: [AccountTransferObject] { get }

    ///
    /// Create a new account object in the local client database.
    ///
    /// - Parameters:
    ///     - host: The server base address.
    ///     - name: The user name.
    ///     - password: The app password.
    ///
    func addAccount(host: URL, name: String, password: String)

    ///
    /// Log out the currently active account.
    ///
    func removeAccount()

    // MARK: Shared Accounts

    ///
    /// All available accounts shared between the apps of the same group.
    /// Not to confuse with actually set up accounts within this app.
    ///
    var sharedAccounts: [NKShareAccounts.DataAccounts] { get }

    ///
    /// Update ``sharedAccounts`` by reading persisted information from persistent storage.
    ///
    func readSharedAccounts()

    // MARK: Settings

    ///
    /// Which file extension should be used for note files.
    ///
    var fileExtension: FileSuffix { get set }

    ///
    /// Whether only the built-in editor is supposed to be used.
    ///
    var internalEditor: Bool { get set }

    ///
    /// The root file path for note files.
    ///
    var notesPath: String { get set }

    ///
    /// Whether synchronization is forcefully disabled or not.
    ///
    var offlineMode: Bool { get set }

    ///
    /// Whether to synchronize on app launch or not.
    ///
    var launchSynchronization: Bool { get set }
}
