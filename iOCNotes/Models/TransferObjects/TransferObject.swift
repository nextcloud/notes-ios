// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// Transfer objects are immutable and concurrency safe value types to pass information between different architecture layers and domains.
///
/// They are meant to abstract their underlying origin like a CoreData object, user defaults, keychain items or JSON response objects from HTTP requests.
///
protocol TransferObject: Sendable {}
