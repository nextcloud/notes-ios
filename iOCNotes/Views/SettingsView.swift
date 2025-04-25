// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import SwiftUI

struct SettingsView: View {
    @State private var addAccount = false
    @State private var model = SettingsModel()

    var body: some View {
        SettingsTableViewControllerRepresentable(addAccount: $addAccount)
            .ignoresSafeArea(.all)
            .toolbar {
                if model.sharedAccountsExist {
                    Button {
                        addAccount = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                }
            }
            .toolbarTitleDisplayMode(.large)
            .navigationTitle(NSLocalizedString("Settings", comment: ""))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

@Observable class SettingsModel: Identifiable {
    var sharedAccountsExist: Bool = false

    init() {
        if let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nextcloud.apps") {
            if let shareAccounts = NKShareAccounts().getShareAccount(at: dirGroupApps, application: UIApplication.shared) {
                var accountTemp = [NKShareAccounts.DataAccounts]()
                for shareAccount in shareAccounts {
                    accountTemp.append(shareAccount)
                }

                if !accountTemp.isEmpty {
                    sharedAccountsExist = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
