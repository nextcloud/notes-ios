// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                NotesScreen()
            }
            .tabItem {
                Label(
                    title: {
                        Text("Notes")
                    },
                    icon: {
                        Image(systemName: "note")
                    }
                )
            }

            NavigationStack {
                SettingsScreen()
            }
            .tabItem {
                Label(
                    title: {
                        Text("Settings")
                    },
                    icon: {
                        Image(systemName: "gear")
                    }
                )
            }
        }
        .tint(Color(NCBrandColor.shared.brandColor))
    }
}

#Preview {
    ContentView()
}
