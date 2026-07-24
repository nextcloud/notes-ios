// SPDX-FileCopyrightText: 2025 Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import Observation
import os
import SwiftUI

///
/// Immutable values needed to identify, render and act on a note list row.
///
struct NoteListRow: Equatable, Identifiable {
    ///
    /// Identity used by the native list, which must replace a swiped row when favorite sorting moves it.
    ///
    struct PresentationID: Hashable {
        let noteID: NSManagedObjectID
        let favorite: Bool
    }

    private static let snippetLength = 512

    let noteID: NSManagedObjectID
    let title: String
    let snippet: String
    let modified: Double
    let favorite: Bool

    var id: PresentationID { PresentationID(noteID: noteID, favorite: favorite) }

    init(note: Note) {
        noteID = note.objectID
        title = note.title
        snippet = Self.snippet(from: note.content)
        modified = note.modified
        favorite = note.favorite
    }

    private static func snippet(from content: String) -> String {
        guard let newline = content.firstIndex(of: "\n") else { return "" }
        let bodyStart = content.index(after: newline)
        return content[bodyStart...]
            .prefix(snippetLength)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

///
/// A single group of notes shown in ``NotesListView``.
///
/// When notes are sorted by modification date instead of grouped by category, a single section with an
/// empty ``title`` is produced and rendered without a header.
///
struct NoteListSection: Equatable, Identifiable {
    let title: String
    let rows: [NoteListRow]

    var id: String { title }
    var hasHeader: Bool { !title.isEmpty }
}

///
/// Observable data source for the SwiftUI notes list.
///
/// Wraps an `NSFetchedResultsController` so the proven Core Data behaviour (category grouping, search
/// predicate, live updates) is reused while exposing plain value types to SwiftUI.
///
@Observable
final class NotesListModel: NSObject, Logging, NSFetchedResultsControllerDelegate {
    let logger = makeLogger()

    private(set) var sections: [NoteListSection] = []

    @ObservationIgnored private var fetchedResultsController: NSFetchedResultsController<Note>?
    @ObservationIgnored private var searchText = ""
    @ObservationIgnored private var pendingFavoriteRowReplacement = false
    private var collapsedTitles: Set<String>

    private(set) var groupByCategory: Bool

    override init() {
        groupByCategory = KeychainHelper.groupByCategory
        collapsedTitles = Set(KeychainHelper.sectionExpandedInfo.filter { $0.collapsed }.map { $0.title })
        super.init()
        configure()
    }

    // MARK: - Sorting

    func setGroupByCategory(_ value: Bool) {
        guard value != groupByCategory else { return }
        groupByCategory = value
        KeychainHelper.groupByCategory = value
        configure()
    }

    // MARK: - Search

    func search(for text: String) {
        guard text != searchText else { return }
        searchText = text
        configure()
    }

    // MARK: - Section expansion

    func isExpanded(_ title: String) -> Bool {
        !collapsedTitles.contains(title)
    }

    func setExpanded(_ expanded: Bool, for title: String) {
        if expanded {
            collapsedTitles.remove(title)
        } else {
            collapsedTitles.insert(title)
        }
        persistCollapsedState()
    }

    private func persistCollapsedState() {
        // Persist the full set of collapsed titles, not just the currently visible sections, so that a section
        // filtered out by an active search does not lose its collapsed state.
        KeychainHelper.sectionExpandedInfo = collapsedTitles
            .sorted()
            .map { DisclosureSection(title: $0, collapsed: true) }
    }

    // MARK: - Fetching

    private func configure() {
        let request = Note.fetchRequest()
        request.fetchBatchSize = 288
        request.predicate = predicate(for: searchText)

        if groupByCategory {
            // "category" must stay first so it matches the section key path; favorites float to the top within each category.
            request.sortDescriptors = [
                NSSortDescriptor(key: "category", ascending: true),
                NSSortDescriptor(key: "favorite", ascending: false),
                NSSortDescriptor(key: "modified", ascending: false),
                NSSortDescriptor(key: "id", ascending: true),
                NSSortDescriptor(key: "guid", ascending: true)
            ]
        } else {
            request.sortDescriptors = [
                NSSortDescriptor(key: "favorite", ascending: false),
                NSSortDescriptor(key: "modified", ascending: false),
                NSSortDescriptor(key: "id", ascending: true),
                NSSortDescriptor(key: "guid", ascending: true)
            ]
        }

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: NotesData.mainThreadContext,
            sectionNameKeyPath: groupByCategory ? "sectionName" : nil,
            cacheName: nil
        )
        controller.delegate = self
        fetchedResultsController = controller

        do {
            try controller.performFetch()
            rebuildSections()
        } catch {
            logger.error("Failed to fetch notes: \(error.localizedDescription, privacy: .public)")
            sections = []
        }
    }

    private func predicate(for text: String) -> NSPredicate {
        guard !text.isEmpty else {
            return .allNotes
        }
        let matching = NSPredicate(format: "(title contains[c] %@) || (content contains[cd] %@)", text, text)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [.allNotes, matching])
    }

    private func rebuildSections() {
        guard let fetchedSections = fetchedResultsController?.sections else {
            sections = []
            return
        }

        let updatedSections = fetchedSections.map { section in
            let title = groupByCategory ? section.name : ""
            let notes = (section.objects as? [Note]) ?? []
            return NoteListSection(title: title, rows: notes.map(NoteListRow.init))
        }

        guard updatedSections != sections else { return }
        sections = updatedSections
    }

    func note(for id: NSManagedObjectID) -> Note? {
        try? NotesData.mainThreadContext.existingObject(with: id) as? Note
    }

    func toggleFavorite(for id: NSManagedObjectID) -> Note? {
        guard let note = note(for: id) else { return nil }
        pendingFavoriteRowReplacement = true
        note.favorite.toggle()
        return note
    }

    // MARK: - NSFetchedResultsControllerDelegate

    @objc
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard pendingFavoriteRowReplacement else {
            rebuildSections()
            return
        }

        pendingFavoriteRowReplacement = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            rebuildSections()
        }
    }
}

// MARK: - allNotes

extension NSPredicate {
    ///
    /// Matches all notes that are not pending deletion.
    ///
    static var allNotes: NSPredicate {
        NSPredicate(format: "deleteNeeded == %@", NSNumber(value: false))
    }
}
