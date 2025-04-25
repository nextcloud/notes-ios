// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

final class Store: Storing {
    static let shared = Store()

    // MARK: - Storing Implementation

    var accounts: [AccountTransferObject] {
        // For historic reasons only a a single account is supported.
        // The persistence must be refactored to support multiple accounts.
        // This API already decouples calling code from the underlying persistence.
        // Support for multiple accounts then will only be a matter of refactoring the data layer and having a migration for it.

        guard KeychainHelper.username.isEmpty == false else {
            return []
        }

        guard KeychainHelper.password.isEmpty == false else {
            return []
        }

        guard KeychainHelper.server.isEmpty == false else {
            return []
        }

        guard let parsedComponents = URLComponents(string: KeychainHelper.server) else {
            return []
        }

        var assembledComponents = URLComponents()
        assembledComponents.scheme = parsedComponents.scheme
        assembledComponents.host = parsedComponents.host
        assembledComponents.port = parsedComponents.port

        guard let baseURL = assembledComponents.url?.absoluteString else {
            return []
        }

        let major = KeychainHelper.serverMajorVersion
        let minor = KeychainHelper.serverMinorVersion
        let micro = KeychainHelper.serverMicroVersion
        let serverVersion = ServerVersionTransferObject(major: major, minor: minor, micro: micro)

        return [
            AccountTransferObject(
                baseURL: baseURL,
                password: KeychainHelper.password,
                serverVersion: serverVersion,
                userId: KeychainHelper.username
            )
        ]
    }
}
