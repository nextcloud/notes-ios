// SPDX-FileCopyrightText: 2025 Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// A single row in ``NotesListView`` showing the note title, a short content preview and the modification date.
///
/// The row renders an immutable snapshot so its content and identity do not depend on live `NSManagedObject`
/// change notifications.
///
struct NoteRowView: View {
    private let title: String
    private let snippet: String
    private let modified: Double
    private let favorite: Bool

    init(row: NoteListRow) {
        title = row.title
        snippet = row.snippet
        modified = row.modified
        favorite = row.favorite
    }

    private static let intervalFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.year, .month, .weekOfMonth, .day, .hour, .minute]
        return formatter
    }()

    ///
    /// Compact relative age of the note, e.g. "7m" or "2h".
    ///
    private var modifiedText: String {
        let interval = max(Date.now.timeIntervalSince1970 - modified, 60)
        return Self.intervalFormatter.string(from: interval) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if favorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                Spacer()

                Text(modifiedText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(snippet.isEmpty ? String(localized: "No content", comment: "Shown in the notes list for notes without content") : snippet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}
