// SPDX-FileCopyrightText: 2025 Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Root screen of the notes navigation listing all folders.
///
/// Shows smart entries for all notes, favorites and uncategorized notes followed by the folder tree
/// derived from note categories. Selecting an entry pushes a ``NotesView`` scoped to it.
///
struct FoldersView: View {
    var model: FoldersModel

    @State private var expandedFolders = Set<String>()
    @State private var isAddingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        List {
            Section {
                NavigationLink(value: NoteRoute.allNotes) {
                    row(
                        title: String(localized: "All Notes", comment: "Title of the list showing notes of all categories"),
                        systemImage: "tray.full",
                        count: model.allCount
                    )
                }

                NavigationLink(value: NoteRoute.favorites) {
                    row(
                        title: String(localized: "Favorites", comment: "Title of the list showing favorite notes"),
                        systemImage: "star",
                        count: model.favoritesCount
                    )
                }

                if model.hasUncategorized {
                    NavigationLink(value: NoteRoute.folder("")) {
                        row(title: Constants.noCategory, systemImage: "folder", count: model.uncategorizedCount)
                    }
                }
            }

            if !model.tree.isEmpty {
                Section {
                    ForEach(visibleFolders, id: \.node.id) { entry in
                        folderRow(entry.node, depth: entry.depth)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await NoteSessionManager.shared.sync()
        }
        .toolbar {
            Button {
                newFolderName = ""
                isAddingFolder = true
            } label: {
                Image(systemName: "folder.badge.plus")
            }
        }
        .toolbarTitleDisplayMode(.large)
        .navigationTitle(String(localized: "Folders", comment: "Title of the folder list screen"))
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .tabBar)
        .alert(
            String(localized: "New Folder", comment: "Title of alert for creating a folder"),
            isPresented: $isAddingFolder
        ) {
            TextField(String(localized: "Name", comment: "Placeholder for the name of a new folder"), text: $newFolderName)
            Button(String(localized: "Cancel", comment: "Caption of Cancel button"), role: .cancel) {
                // Dismisses the alert without creating a folder.
            }
            Button(String(localized: "Save", comment: "Caption of Save button")) {
                model.addLocalFolder(newFolderName)
            }
        } message: {
            Text(String(localized: "Enter a name for the new folder", comment: "Message of alert for creating a folder"))
        }
    }

    ///
    /// The folder tree flattened into the currently visible rows.
    ///
    private var visibleFolders: [(node: FolderNode, depth: Int)] {
        var result = [(node: FolderNode, depth: Int)]()

        func walk(_ nodes: [FolderNode], depth: Int) {
            for node in nodes {
                result.append((node, depth))
                if expandedFolders.contains(node.fullPath) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }

        walk(model.tree, depth: 0)
        return result
    }

    private func folderRow(_ node: FolderNode, depth: Int) -> some View {
        NavigationLink(value: NoteRoute.folder(node.fullPath)) {
            HStack {
                if node.children.isEmpty {
                    // Placeholder keeping leaf folders aligned with expandable ones.
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .hidden()
                } else {
                    Button {
                        withAnimation {
                            if expandedFolders.contains(node.fullPath) {
                                expandedFolders.remove(node.fullPath)
                            } else {
                                expandedFolders.insert(node.fullPath)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expandedFolders.contains(node.fullPath) ? 90 : 0))
                    }
                    .buttonStyle(.borderless)
                }

                row(title: node.name, systemImage: "folder", count: node.directCount)
            }
            .padding(.leading, CGFloat(depth) * 24)
        }
    }

    private func row(title: String, systemImage: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            Text(count, format: .number)
                .foregroundStyle(.secondary)
        }
    }
}
