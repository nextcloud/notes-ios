// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

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
            .navigationTitle(NSLocalizedString("Notes", comment: ""))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    NotesView()
}
