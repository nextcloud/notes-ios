// SPDX-FileCopyrightText: 2025 Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreData
import SwiftUI

///
/// SwiftUI list of notes, either grouped by category into collapsible sections or sorted by modification date.
///
struct NotesListView: View {
    @Bindable var model: NotesListModel

    @State private var noteToRename: NSManagedObjectID?
    @State private var renameText = ""
    @State private var exporter: NoteExporter?

    private var canRename: Bool {
        isNextcloud() && KeychainHelper.notesApiVersion != Router.defaultApiVersion
    }

    var body: some View {
        Group {
            if model.sections.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Notes", comment: "Shown when there are no notes to display"),
                    systemImage: "note.text"
                )
            } else {
                notesList
            }
        }
        .alert(
            String(localized: "Note Title", comment: "Title of alert to change title"),
            isPresented: Binding(get: { noteToRename != nil }, set: { if !$0 { noteToRename = nil } })
        ) {
            TextField(String(localized: "Note Title", comment: "Title of alert to change title"), text: $renameText)
            Button(String(localized: "Cancel", comment: "Caption of Cancel button"), role: .cancel) {
                // Dismisses the rename alert without applying changes.
            }
            Button(String(localized: "Rename", comment: "Caption of Rename button")) { commitRename() }
        } message: {
            Text(String(localized: "Rename the note", comment: "Message of alert to change title"))
        }
    }

    private var notesList: some View {
        List {
            ForEach(model.sections) { section in
                if section.hasHeader {
                    Section(isExpanded: expansionBinding(for: section.title)) {
                        rows(for: section)
                    } header: {
                        Label(section.title, systemImage: "folder")
                    }
                } else {
                    rows(for: section)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await NoteSessionManager.shared.sync()
        }
        .dropDestination(for: String.self) { items, _ in
            let contents = items.filter { !$0.isEmpty }
            for content in contents {
                NoteSessionManager.shared.add(content: content, category: "")
            }
            return !contents.isEmpty
        }
    }

    private func rows(for section: NoteListSection) -> some View {
        ForEach(section.rows) { row in
            Button {
                openEditor(for: row)
            } label: {
                NoteRowView(row: row)
            }
            .buttonStyle(.plain)
            .contextMenu {
                contextMenu(for: row)
            }
            .swipeActions(edge: .leading) {
                Button {
                    toggleFavorite(row)
                } label: {
                    favoriteLabel(isFavorite: row.favorite)
                }
                .tint(.yellow)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    delete(row)
                } label: {
                    Label(String(localized: "Delete", comment: "Action to delete a note"), systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for row: NoteListRow) -> some View {
        if canRename {
            Button {
                renameText = row.title
                noteToRename = row.noteID
            } label: {
                Label(String(localized: "Rename…", comment: "Action to change title of a note"), systemImage: "square.and.pencil")
            }
        }

        if isNextcloud() {
            Button {
                openCategories(for: row)
            } label: {
                Label(String(localized: "Category…", comment: "Action to change category of a note"), systemImage: "folder")
            }
        }

        Button {
            toggleFavorite(row)
        } label: {
            favoriteLabel(isFavorite: row.favorite)
        }

        Button {
            share(row)
        } label: {
            Label(String(localized: "Share", comment: "Action to share a note"), systemImage: "square.and.arrow.up")
        }

        Button(role: .destructive) {
            delete(row)
        } label: {
            Label(String(localized: "Delete", comment: "Action to delete a note"), systemImage: "trash")
        }
    }

    private func expansionBinding(for title: String) -> Binding<Bool> {
        Binding(
            get: { model.isExpanded(title) },
            set: { model.setExpanded($0, for: title) }
        )
    }

    private func openEditor(for row: NoteListRow) {
        guard let note = model.note(for: row.noteID) else { return }
        NotesPresenter.openEditor(for: note, isNewNote: false)
    }

    private func openCategories(for row: NoteListRow) {
        guard let note = model.note(for: row.noteID) else { return }
        NotesPresenter.openCategories(for: note, categories: Note.categories() ?? [])
    }

    private func share(_ row: NoteListRow) {
        guard let note = model.note(for: row.noteID) else { return }
        NotesPresenter.share(note: note, exporter: &exporter)
    }

    private func delete(_ row: NoteListRow) {
        guard let note = model.note(for: row.noteID) else { return }
        NoteSessionManager.shared.delete(note: note)
    }

    @ViewBuilder
    private func favoriteLabel(isFavorite: Bool) -> some View {
        if isFavorite {
            Label(String(localized: "Remove from Favorites", comment: "Action to unmark a note as favorite"), systemImage: "star.slash")
        } else {
            Label(String(localized: "Favorite", comment: "Action to mark a note as favorite"), systemImage: "star")
        }
    }

    private func toggleFavorite(_ row: NoteListRow) {
        guard let note = model.toggleFavorite(for: row.noteID) else { return }
        NoteSessionManager.shared.update(note: note, updateModified: false, completion: nil)
    }

    private func commitRename() {
        guard let noteID = noteToRename,
              let note = model.note(for: noteID) else { return }
        defer { noteToRename = nil }

        let newName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != note.title else { return }

        note.title = newName
        NoteSessionManager.shared.update(note: note, completion: nil)
    }
}
