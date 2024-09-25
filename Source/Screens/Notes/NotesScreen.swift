//
//  Notes.swift
//  iOCNotes
//
//  Created by Milen Pivchev on 21.08.24.
//  Copyright © 2024 Milen Pivchev. All rights reserved.
//

import SwiftUI

struct NotesScreen: View {
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
    NotesScreen()
}
