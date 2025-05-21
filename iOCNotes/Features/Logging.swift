// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

///
/// Conforming types are provided with the factory method to set up a specific `Logger` for them.
///
/// This reduces the `Logger` setup to this property declaration in conforming types:
///
/// ```swift
/// let logger = makeLogger()
/// ```
///
protocol Logging {
    ///
    /// A dedicated `Logger` for every instance of this type.
    ///
    var logger: Logger { get }
}

extension Logging {
    ///
    /// Automatically defines the subsystem and category fields for the logger to reduce repetitive code.
    ///
    static func makeLogger() -> Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: String(describing: Self.self))
    }
}
