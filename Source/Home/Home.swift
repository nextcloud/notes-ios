//
//  Home.swift
//  iOCNotes
//
//  Created by Milen on 12.08.24.
//  Copyright © 2024 Peter Hedlund. All rights reserved.
//

import SwiftUI

struct Home: View {
    var body: some View {
        TabView {
            NavigationStack {
                NotesTableViewControllerRepresentable()
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
    }
}

#Preview {
    Home()
}
