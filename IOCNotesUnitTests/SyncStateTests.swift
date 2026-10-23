// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 s17sh70x2jfl031ag
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation
import Testing
@testable import iOCNotes

@Suite("Sync state", .serialized)
struct SyncStateTests {
    @Test("Last-Modified parses as an HTTP date in any device language")
    func parsesHTTPDate() {
        #expect(NoteSessionManager.timestamp(fromHTTPDate: "Wed, 21 Oct 2026 07:28:00 GMT") == 1_792_567_680)
        #expect(NoteSessionManager.timestamp(fromHTTPDate: "Mon, 01 Jan 2024 00:00:00 GMT") == 1_704_067_200)
        #expect(NoteSessionManager.timestamp(fromHTTPDate: "not a date") == nil)
    }

    @Test("Logging out forgets the ETag and pruneBefore of the previous list")
    func logoutResetsListState() {
        KeychainHelper.eTag = "\"abc\""
        KeychainHelper.lastModified = 1_792_567_680

        Store().removeAccount()

        #expect(KeychainHelper.eTag.isEmpty)
        #expect(KeychainHelper.lastModified == 0)
    }

    @Test("Server notes do not overwrite local notes with pending changes")
    func pendingNotesAreSkipped() {
        var pending = NoteStruct(content: "server copy", category: "")
        pending.id = 7
        var unchanged = NoteStruct(content: "other note", category: "")
        unchanged.id = 8

        let applied = NoteSessionManager.notes([pending, unchanged], excludingPending: [7])

        #expect(applied.map(\.id) == [8])
    }

    @Test("A timed out request is described without the retry wrappers")
    func timeoutMessage() {
        let failure = AFError.sessionTaskFailed(error: URLError(.timedOut))
        let wrapped = AFError.requestRetryFailed(retryError: AFError.requestRetryFailed(retryError: failure, originalError: failure), originalError: failure)

        let message = NoteSessionManager.message(for: wrapped)

        #expect(message == URLError(.timedOut).localizedDescription)
        #expect(!message.contains("Request retry failed"))
    }

    @Test("A locked note is described in plain words")
    func lockedMessage() {
        let failure = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 423))
        let wrapped = AFError.requestRetryFailed(retryError: failure, originalError: failure)

        #expect(NoteSessionManager.message(for: wrapped) == "The note is locked on the server. Please try again later.")
    }
}
