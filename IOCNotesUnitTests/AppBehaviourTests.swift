// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 s17sh70x2jfl031ag
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

@Suite("App behaviour", .serialized)
struct AppBehaviourTests {
    @Test("Only the temporary copy in Documents/Inbox counts as removable")
    func inboxCopy() {
        let documents = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/ABC/Documents", isDirectory: true)

        #expect(AppDelegate.isInboxCopy(documents.appendingPathComponent("Inbox/todo.txt"), documentsDirectory: documents))
        #expect(!AppDelegate.isInboxCopy(URL(fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/todo.txt"), documentsDirectory: documents))
        #expect(!AppDelegate.isInboxCopy(documents.appendingPathComponent("InboxOld/todo.txt"), documentsDirectory: documents))
        #expect(!AppDelegate.isInboxCopy(documents.appendingPathComponent("todo.txt"), documentsDirectory: documents))
    }

    @Test("Synchronize on Start defaults to on and follows the saved choice")
    func syncOnStartSetting() {
        let previous = UserDefaults.standard.object(forKey: "SyncOnStart")
        defer { UserDefaults.standard.set(previous, forKey: "SyncOnStart") }

        UserDefaults.standard.removeObject(forKey: "SyncOnStart")
        #expect(KeychainHelper.syncOnStart)

        KeychainHelper.syncOnStart = false
        #expect(!KeychainHelper.syncOnStart)

        KeychainHelper.syncOnStart = true
        #expect(KeychainHelper.syncOnStart)
    }
}
