// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Faris Armoush
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import iOCNotes

@Suite("Sync gate")
struct SyncGateTests {
    @Test("Only the first caller gets to run")
    func secondCallerIsQueued() {
        let gate = SyncGate()
        var completed = 0

        #expect(gate.begin())
        #expect(gate.isBusy)
        #expect(gate.begin { completed += 1 } == false)
        #expect(gate.begin { completed += 1 } == false)
        #expect(completed == 0)

        gate.end()

        #expect(completed == 2)
        #expect(gate.isBusy == false)
        #expect(gate.begin())
    }

    @Test("Queued completions run once", arguments: [1, 5, 14])
    func queuedCompletionsRunOnce(waiters: Int) {
        let gate = SyncGate()
        var completed = 0
        _ = gate.begin()
        for _ in 0..<waiters {
            _ = gate.begin { completed += 1 }
        }

        gate.end()
        gate.end()

        #expect(completed == waiters)
    }

    @Test("A key can only be claimed while it is in flight")
    func inFlightTracker() {
        let tracker = InFlightTracker()

        #expect(tracker.claim("a"))
        #expect(tracker.claim("a") == false)
        #expect(tracker.claim("b"))

        tracker.release("a")

        #expect(tracker.claim("a"))
    }
}
