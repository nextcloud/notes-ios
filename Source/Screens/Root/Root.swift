//
//  Home.swift
//  iOCNotes
//
//  Created by Milen Pivchev on 12.08.24.
//  Copyright © 2024 Milen Pivchev. All rights reserved.
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
                SettingsScreen()
            }
            .tabItem {
                Label(
                    title: { Text("Settings") },
                    icon: { Image(systemName: "gear") }
                )
            }
        }
        .tint(Color(NCBrandColor.shared.brandColor))
    }
}

#Preview {
    Root()
}
