// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Top-level view for the notes navigation.
///
struct NotesView: View {
    @State private var model = NotesListModel()
    @State private var searchText = ""

    var body: some View {
        NotesListView(model: model)
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                model.search(for: newValue)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    sortMenu
                    Button {
                        addNote()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .navigationTitle(String(localized: "Notes", comment: ""))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    private var sortMenu: some View {
        Menu {
            Picker(
                String(localized: "Sorting", comment: "Menu heading for note list sorting options"),
                selection: Binding(get: { model.groupByCategory }, set: { model.setGroupByCategory($0) })
            ) {
                Label(String(localized: "Group by category", comment: "Sorting option grouping notes into their categories"), systemImage: "folder")
                    .tag(true)
                Label(String(localized: "Sort by most recent", comment: "Sorting option ordering notes by modification date"), systemImage: "clock")
                    .tag(false)
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
    }

    private func addNote() {
        NoteSessionManager.shared.add(content: "", category: "") { note in
            guard let note else { return }
            DispatchQueue.main.async {
                NotesPresenter.openEditor(for: note, isNewNote: true)
            }
        }
    }
}

#Preview {
    let store = Store()

    store.accounts = [
        AccountTransferObject(baseURL: "http://localhost:8080", password: "password", serverVersion: ServerVersionTransferObject(major: 31, minor: 0, micro: 0), userId: "admin")
    ]

    return ContentView(selection: 0)
        .environment(store)
}
