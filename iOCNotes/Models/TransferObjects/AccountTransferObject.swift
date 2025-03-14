// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// Represents a local user account.
///
struct AccountTransferObject: Identifiable, TransferObject {
    ///
    /// Base URL for requests against the server.
    ///
    let baseURL: String

    ///
    /// Uniquely identifies the string in scope of the local app.
    ///
    var id: String

    ///
    /// App password as stored in the keychain.
    ///
    let password: String

    ///
    /// As retrieved with the capabilities.
    ///
    let serverVersion: ServerVersionTransferObject

    ///
    /// The unique user name on the server.
    ///
    let userId: String

    init(baseURL: String, password: String, serverVersion: ServerVersionTransferObject, userId: String) {
        self.id = "\(userId) \(baseURL)"
        self.password = password
        self.baseURL = baseURL
        self.serverVersion = serverVersion
        self.userId = userId
    }
}
