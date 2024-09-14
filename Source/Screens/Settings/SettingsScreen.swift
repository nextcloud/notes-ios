//
//  SettingsScreen.swift
//  iOCNotes
//
//  Created by Milen Pivchev on 14.09.24.
//  Copyright © 2024 Milen Pivchev. All rights reserved.
//

import SwiftUI

struct SettingsScreen: View {
    @State private var addAccount = false

    var body: some View {
        SettingsTableViewControllerRepresentable(addAccount: $addAccount)
            .ignoresSafeArea(.all)
            .toolbar {
                Button {
                    addAccount = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
            }
            .toolbarTitleDisplayMode(.large)
            .navigationTitle(NSLocalizedString("Settings", comment: ""))
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    SettingsScreen()
}
