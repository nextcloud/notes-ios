// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Faris Armoush
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// Allows only one synchronization to run at a time.
///
/// Callers which arrive while a run is in progress are not started again. Their completion blocks are queued and
/// called once the running synchronization has ended. Not thread safe, use it from the main queue only.
///
final class SyncGate {
    private var isRunning = false
    private var waiting = [() -> Void]()

    /// Whether a synchronization is currently running.
    var isBusy: Bool { isRunning }

    ///
    /// Try to start a synchronization.
    ///
    /// - Parameter completion: Called when the synchronization ends if this call did not get to start it.
    /// - Returns: `true` if the caller must run the synchronization and call ``end()`` afterwards.
    ///
    func begin(completion: (() -> Void)? = nil) -> Bool {
        if isRunning {
            if let completion {
                waiting.append(completion)
            }
            return false
        }
        isRunning = true
        return true
    }

    /// Marks the running synchronization as ended and calls the queued completion blocks.
    func end() {
        isRunning = false
        let blocks = waiting
        waiting.removeAll()
        for block in blocks {
            block()
        }
    }
}

///
/// Remembers keys of requests which are currently in flight so the same note is not sent twice.
/// Not thread safe, use it from the main queue only.
///
final class InFlightTracker {
    private var keys = Set<String>()

    /// Returns `true` and remembers the key unless it is already in flight.
    func claim(_ key: String) -> Bool {
        keys.insert(key).inserted
    }

    /// Forgets the key once its request finished.
    func release(_ key: String) {
        keys.remove(key)
    }
}
