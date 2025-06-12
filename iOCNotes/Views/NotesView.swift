// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

///
/// Top-level view for the notes navigation.
///
struct NotesView: View {
    @State private var addNote = false

    var body: some View {
        NotesTableViewControllerRepresentable(addNote: $addNote)
            .ignoresSafeArea(.all)
            .toolbar {
                Button {
                    addNote = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .navigationTitle(String(localized: "Notes", comment: ""))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
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
