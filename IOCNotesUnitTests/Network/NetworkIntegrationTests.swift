// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing

/// The text the app shows for a `NSLocalizedString` key; the host app's bundle provides the translation.
func localized(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: nil, table: nil)
}

///
/// Parent of every suite that exercises the networking layer.
///
/// They share process-wide state (user defaults, keychain, the Core Data context), so all of them run serially.
/// Each nested suite sets its own time limit: the shortest applicable limit wins, so one here would cap them all.
///
@Suite(.serialized)
enum NetworkIntegrationTests {}

extension Tag {
    /// Runs against the in-process fake Notes server.
    @Tag static var hermetic: Self

    /// Runs against a real Nextcloud server.
    @Tag static var liveServer: Self
}
