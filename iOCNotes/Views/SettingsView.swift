// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import SwiftNextcloudUI
import SwiftUI

///
/// Combined app and user settings.
///
/// The management of the file extension is a bit complicated at the moment.
/// It is not just a two-way binding to the store but also programmatically updated by the ``NoteSessionManager`` when server-side settings are fetched.
/// A loop of property value change and server requests must be avoided as it is with the current implementation.
///
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(Store.self) var store

    @State var fileExtension: FileSuffix?
    @State var initialFileExtensionDefinition = false

    @State var pathInAlert: String = ""
    @State var showLogoutConfirmation = false
    @State var showPathAlert = false

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section("Account") {
                    VStack(alignment: .leading) {
                        Text(verbatim: KeychainHelper.username)
                        Text(verbatim: KeychainHelper.server)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Text("Log Out")
                    }
                }

                Section("Synchronization") {
                    Toggle("Synchronize on Start", isOn: $store.launchSynchronization)
                    Toggle("Offline Mode", isOn: $store.offlineMode)
                }

                Section("Server Settings") {
                    FormDetailView("Notes Path", detail: $store.notesPath) {
                        pathInAlert = $store.notesPath.wrappedValue
                        showPathAlert = true
                    }

                    Toggle("Internal Editor", isOn: $store.internalEditor)

                    Picker("File Extension", selection: $fileExtension) {
                        Text(verbatim: "Plain Text (*.txt)")
                            .tag(FileSuffix.txt)

                        Text(verbatim: "Markdown (*.md)")
                            .tag(FileSuffix.md)
                    }
                    .onAppear {
                        initialFileExtensionDefinition = true
                        fileExtension = store.fileExtension
                    }
                    .onChange(of: fileExtension) {
                        guard initialFileExtensionDefinition == false else {
                            initialFileExtensionDefinition = false
                            return
                        }

                        guard let fileExtension else {
                            return
                        }

                        store.fileExtension = fileExtension

                        NoteSessionManager.shared.updateSettings {
                            // Nothing to do here yet.
                        }
                    }
                }

                Section("About This App") {
                    FormDetailView("Client Version", detail: .constant("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "nil") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "nil"))"))
                    FormDetailView("Server Version", detail: .constant(KeychainHelper.productVersion))

                    if let url = URL(string: NCBrandOptions.shared.privacyUrl) {
                        NavigationLink("Privacy and Legal Policy") {
                            WebView(initialURL: .constant(url))
                        }
                    }

                    if let url = URL(string: NCBrandOptions.shared.sourceCodeUrl) {
                        Button {
                            openURL(url)
                        } label: {
                            Text("Show Source Code on GitHub")
                        }
                    }
                }
            }
            // Logout Confirmation Alert
            .alert("Logout", isPresented: $showLogoutConfirmation) {
                Button(role: .cancel) {
                    showLogoutConfirmation = false
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    showLogoutConfirmation = false
                    store.removeAccount()
                } label: {
                    Text("Log Out")
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("Are you sure you want to log out?")
            }
            // Notes path alert
            .alert("Notes Path", isPresented: $showPathAlert) {
                TextField("Notes Path", text: $pathInAlert)

                Button(role: .cancel) {
                    showPathAlert = false
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    showPathAlert = false
                    $store.notesPath.wrappedValue = pathInAlert

                    NoteSessionManager.shared.updateSettings {
                        // Nothing to do here yet.
                    }
                } label: {
                    Text("Save")
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("Enter a name for the folder where notes should be saved on the server")
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environment(Store())
}
