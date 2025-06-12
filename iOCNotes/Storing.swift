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
    ///
    /// Returns all locally set up accounts for this app.
    ///
    var accounts: [AccountTransferObject] { get }

    ///
    /// Whether the current account is synchronizing notes or not.
    ///
    /// This is needed to update the user interface state accordingly.
    ///
    var isSynchronizing: Bool { get }

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
    /// Update ``sharedAccounts`` by reading persisted information from persistent storage.
    ///
    func readSharedAccounts()

    ///
    /// Log out the currently active account.
    ///
    func removeAccount()

    ///
    /// All available accounts shared between the apps of the same group.
    /// Not to confuse with actually set up accounts within this app.
    ///
    var sharedAccounts: [NKShareAccounts.DataAccounts] { get }

    ///
    /// Synchronize set up accounts and their associated information as well as notes.
    ///
    func synchronize()
}
