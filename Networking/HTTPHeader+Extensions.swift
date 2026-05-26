// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire

extension HTTPHeader {
    ///
    /// Convenience method to initialize a new If-None-Match header with the given value.
    ///
    public static func ifNoneMatch(_ value: String) -> HTTPHeader {
        HTTPHeader(name: "If-None-Match", value: value)
    }
}
