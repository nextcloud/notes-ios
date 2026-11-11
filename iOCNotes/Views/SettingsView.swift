// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import NextcloudKitUI
import SwiftUI

///
/// Combined app and user settings.
///
/// The file extension is not limited to the two extensions the picker used to offer: the Notes app of the server
/// accepts any extension, so the current one is shown and can be replaced by any valid value. It is also updated
/// programmatically by the ``NoteSessionManager`` when the server-side settings are fetched.
///
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(Store.self) var store

    @State var pathInAlert: String = ""
    @State var fileExtensionInAlert: String = ""
    @State var showLogoutConfirmation = false
    @State var showPathAlert = false
    @State var showFileExtensionAlert = false
    @State var showInvalidFileExtensionAlert = false

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

                    FormDetailView("File Extension", detail: .constant(store.fileExtension.suffix)) {
                        fileExtensionInAlert = store.fileExtension.suffix
                        showFileExtensionAlert = true
                    }
                }

                Section {
                    Toggle("Use First Line as Title", isOn: $store.useFirstLineAsTitle)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("A new note is named after its first line, like in the web app. Turn this off to keep the name a note was created with.")
                }

                Section("About This App") {
                    FormDetailView("Client Version", detail: .constant("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "nil") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "nil"))"))
                    FormDetailView("Server Version", detail: .constant(KeychainHelper.serverVersion))

                    if let url = URL(string: NCBrandOptions.shared.privacyUrl) {
                        NavigationLink("Privacy and Legal Policy") {
                            WebView(initialURL: url)
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

                    Task {
                        await NoteSessionManager.shared.updateSettings()
                    }
                } label: {
                    Text("Save")
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("Enter a name for the folder where notes should be saved on the server")
            }
            // File extension alert
            .alert("File Extension", isPresented: $showFileExtensionAlert) {
                TextField("File Extension", text: $fileExtensionInAlert)

                Button(role: .cancel) {
                    showFileExtensionAlert = false
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    showFileExtensionAlert = false
                    applyFileExtension(fileExtensionInAlert, to: $store.fileExtension)
                } label: {
                    Text("Save")
                }
                .keyboardShortcut(.defaultAction)
            } message: {
                Text("Enter the extension of note files on the server, for example .md or .org")
            }
            .alert("Invalid File Extension", isPresented: $showInvalidFileExtensionAlert) {
                Button(role: .cancel) {
                    // Keeps the previous extension.
                } label: {
                    Text("OK")
                }
            } message: {
                Text("A file extension starts with a dot and contains only letters and digits, for example .md")
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.inline)
        }
    }

    private func applyFileExtension(_ input: String, to fileExtension: Binding<FileSuffix>) {
        guard let suffix = FileSuffix(validating: input) else {
            showInvalidFileExtensionAlert = true
            return
        }

        guard suffix != fileExtension.wrappedValue else {
            return
        }

        fileExtension.wrappedValue = suffix

        Task {
            await NoteSessionManager.shared.updateSettings()
        }
    }
}

#Preview {
    SettingsView()
        .environment(Store())
}
