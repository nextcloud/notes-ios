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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private var modifiedText: String {
        Self.dateFormatter.string(from: Date(timeIntervalSince1970: modified))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if favorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }

            if !snippet.isEmpty {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(modifiedText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .contentShape(.rect)
    }
}
