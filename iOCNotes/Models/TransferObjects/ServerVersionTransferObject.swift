// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// Server version as described in example in OCS responses.
///
struct ServerVersionTransferObject: TransferObject {
    let major: Int
    let minor: Int
    let micro: Int
}
