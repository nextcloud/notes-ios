// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
import UIKit
@testable import iOCNotes

@MainActor
@Suite("Notes list date sections", .isolatedAppState)
struct NotesListModelTests {
    let fixture: HermeticFixture

    init() throws {
        fixture = try #require(NetworkFixtures.hermetic)
    }

    @Test("Date sections move on to the next day after a significant time change")
    func rollsOverAtMidnight() throws {
        let lateEvening = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 23)))
        var now = lateEvening

        try fixture.seedLocal(id: 1, title: "Late note", modified: lateEvening.addingTimeInterval(-3600).timeIntervalSince1970)

        let model = NotesListModel(now: { now })
        model.setGroupByCategory(false)

        #expect(model.sections.map(\.title) == ["Today"])

        now = lateEvening.addingTimeInterval(10 * 3600)

        #expect(model.sections.map(\.title) == ["Today"])

        NotificationCenter.default.post(name: UIApplication.significantTimeChangeNotification, object: nil)

        #expect(model.sections.map(\.title) == ["Previous 7 Days"])
    }
}
