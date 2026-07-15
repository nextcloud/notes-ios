// SPDX-FileCopyrightText: 2025 Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

///
/// A navigation destination in the notes hierarchy.
///
/// Pushed onto the navigation path by ``FoldersView`` and rendered by ``NotesView``.
///
enum NoteRoute: Hashable {
    ///
    /// All notes regardless of category.
    ///
    case allNotes

    ///
    /// Notes marked as favorite.
    ///
    case favorites

    ///
    /// Notes in a specific category. An empty string means notes without a category.
    ///
    case folder(String)

    ///
    /// The category to scope note fetches and note creation to, if any.
    ///
    var category: String? {
        switch self {
            case .allNotes, .favorites:
                return nil
            case .folder(let category):
                return category
        }
    }

    ///
    /// Localized title for the navigation bar.
    ///
    var title: String {
        switch self {
            case .allNotes:
                return String(localized: "All Notes", comment: "Title of the list showing notes of all categories")
            case .favorites:
                return String(localized: "Favorites", comment: "Title of the list showing favorite notes")
            case .folder(let category):
                guard !category.isEmpty else {
                    return Constants.noCategory
                }
                return category.components(separatedBy: "/").last ?? category
        }
    }
}

// MARK: - Persistence

extension NoteRoute {
    private static let allNotesValue = "all"
    private static let favoritesValue = "favorites"
    private static let folderPrefix = "folder:"

    ///
    /// Restore a route from its ``persistenceValue``.
    ///
    init?(persistenceValue: String) {
        switch persistenceValue {
            case Self.allNotesValue:
                self = .allNotes
            case Self.favoritesValue:
                self = .favorites
            default:
                guard persistenceValue.hasPrefix(Self.folderPrefix) else {
                    return nil
                }
                self = .folder(String(persistenceValue.dropFirst(Self.folderPrefix.count)))
        }
    }

    ///
    /// Stable string representation for persisting the last visited route.
    ///
    var persistenceValue: String {
        switch self {
            case .allNotes:
                return Self.allNotesValue
            case .favorites:
                return Self.favoritesValue
            case .folder(let category):
                return Self.folderPrefix + category
        }
    }
}
