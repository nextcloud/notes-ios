//
//  Home.swift
//  iOCNotes
//
//  Created by Milen on 12.08.24.
//  Copyright © 2024 Peter Hedlund. All rights reserved.
//

import SwiftUI

struct Root: View {


    var body: some View {
        TabView {
            NavigationStack {
                NotesScreen()
            }
            .tabItem {
                Label(
                    title: { Text("Notes") },
                    icon: { Image(systemName: "note") }
                )
            }

            NavigationStack {
                SettingsTableViewControllerRepresentable()
            }
            .tabItem {
                Label(
                    title: { Text("Settings") },
                    icon: { Image(systemName: "gear") }
                )
            }
        }
        .tint(Color(NCBrandColor.shared.brandColor))
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

#Preview {
    Root()
}
