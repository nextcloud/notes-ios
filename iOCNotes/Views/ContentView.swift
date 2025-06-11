// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftNextcloudUI
import SwiftUI

///
/// Top level router for views based on availability of local accounts.
///
/// See ``NotesView``, ``SettingsView`` and ``ServerAddressView`` for previews in context of this.
///
struct ContentView: View {
    @Environment(Store.self) var store

    @State var selection: Int = 0

    var sharedAccounts: [SharedAccount] {
        store.sharedAccounts.compactMap {
            guard let url = URL(string: $0.url) else {
                return nil
            }

            let image: Image

            if let uiImage = $0.image {
                image = Image(uiImage: uiImage)
            } else {
                image = Image(systemName: "person.circle.fill")
            }

            return SharedAccount($0.user, on: url, with: image)
        }
    }

    var body: some View {
        if store.accounts.isEmpty {
            ServerAddressView(backgroundColor: .constant(Color.accent), brandImage: Image("BrandLogo"), delegate: store, sharedAccounts: sharedAccounts, userAgent: userAgent)
                .onAppear {
                    // The store must update its list of shared accounts when the login user interface is about to appear.
                    store.readSharedAccounts()
                }
        } else {
            TabView(selection: $selection) {
                NavigationStack {
                    NotesView()
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
                .tag(0)

                SettingsView()
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
                .tag(1)
            }
            .tint(Color(NCBrandColor.shared.brandColor))
        }
    }
}
