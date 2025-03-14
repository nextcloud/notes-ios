// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// The future connection between user interface and data persistence layer.
///
/// This is introduced for a gradual and long term change in architecture.
/// Through increasing isolation of features and layers with facilities like this future development can be accelerated.
///
protocol Storing {
    ///
    /// Returns all locally set up accounts.
    ///
    var accounts: [AccountTransferObject] { get }
}
