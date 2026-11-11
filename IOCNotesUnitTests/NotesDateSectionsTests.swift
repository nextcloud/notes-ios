// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import iOCNotes

@Suite("Notes list date grouping")
struct NotesDateSectionsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var referenceDate: Date {
        calendar.date(from: DateComponents(year: 2027, month: 6, day: 15, hour: 12))!
    }

    private func section(modifiedDaysAgo days: Int) -> NoteDateSection {
        let date = calendar.date(byAdding: .day, value: -days, to: referenceDate)!
        return NoteDateSection(modified: date.timeIntervalSince1970, relativeTo: referenceDate, calendar: calendar)
    }

    @Test("Notes modified today are grouped together")
    func today() {
        #expect(section(modifiedDaysAgo: 0).title == localized("Today"))
    }

    @Test("The last week and the last month have their own groups")
    func recent() {
        #expect(section(modifiedDaysAgo: 3).title == localized("Previous 7 Days"))
        #expect(section(modifiedDaysAgo: 15).title == localized("Previous 30 Days"))
    }

    @Test("Older notes of the current year are grouped by month")
    func months() {
        let march = calendar.date(from: DateComponents(year: 2027, month: 3, day: 10))!
        let section = NoteDateSection(modified: march.timeIntervalSince1970, relativeTo: referenceDate, calendar: calendar)

        #expect(section.title == march.formatted(.dateTime.month(.wide)))
    }

    @Test("Notes of earlier years are grouped by year")
    func years() {
        let old = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        let section = NoteDateSection(modified: old.timeIntervalSince1970, relativeTo: referenceDate, calendar: calendar)

        #expect(section.title == old.formatted(.dateTime.year()))
    }

    @Test("Groups are ordered from the most to the least recent")
    func ordering() {
        let sections = [section(modifiedDaysAgo: 400), section(modifiedDaysAgo: 0), section(modifiedDaysAgo: 15), section(modifiedDaysAgo: 90)]

        #expect(Set(sections).sorted { $0.startDate > $1.startDate }.map(\.startDate) == sections.map(\.startDate).sorted(by: >))
    }
}
