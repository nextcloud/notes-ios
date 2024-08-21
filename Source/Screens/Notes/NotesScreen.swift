//
//  Notes.swift
//  iOCNotes
//
//  Created by Milen on 21.08.24.
//  Copyright © 2024 Peter Hedlund. All rights reserved.
//

import SwiftUI

struct NotesScreen: View {
    @State private var addNote = false

    var body: some View {
//        NavigationStack {
            NotesTableViewControllerRepresentable(addNote: $addNote)
                .toolbar {
                    Button {
                        addNote = true
                    } label: {
                        Image(systemName: "plus")
                    }

//                }
        }
    }
}

#Preview {
    NotesScreen()
}
