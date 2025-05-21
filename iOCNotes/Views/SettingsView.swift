// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        SettingsTableViewControllerRepresentable()
            .ignoresSafeArea(.all)
            .toolbarTitleDisplayMode(.large)
            .navigationTitle(String(localized: "Settings", comment: ""))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    let store = Store()

    store.accounts = [
        AccountTransferObject(baseURL: "http://localhost:8080", password: "password", serverVersion: ServerVersionTransferObject(major: 31, minor: 0, micro: 0), userId: "admin")
    ]

    return ContentView(selection: 1)
        .environment(store)
}
