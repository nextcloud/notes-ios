// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import NextcloudKitUI
import SwiftUI

///
/// Combined app and user settings.
///
/// The sections follow the order in which a user meets them: the account, how editing feels, how notes are
/// synchronized, where they live on the server, and finally the versions and links. Values that belong to the
/// server (notes path, file extension) are written back to it; the display mode and the title rule are local.
///
struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(Store.self) var store

    @State private var pathInAlert = ""
    @State private var fileExtensionInAlert = ""
    @State private var showLogoutConfirmation = false
    @State private var showPathAlert = false
    @State private var showFileExtensionAlert = false
    @State private var showInvalidFileExtensionAlert = false

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section {
                    LabeledContent {
                        Text(verbatim: KeychainHelper.username)
                    } label: {
                        Label(String(localized: "Signed in as", comment: "Settings label showing the account name"), systemImage: "person.crop.circle")
                    }

                    LabeledContent {
                        Text(verbatim: KeychainHelper.server)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label(String(localized: "Server", comment: "Settings label showing the server address"), systemImage: "cloud")
                    }

                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        Label(String(localized: "Log Out", comment: "Settings action to sign out"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }

                Section {
                    Toggle(isOn: $store.showMarkdownSource) {
                        Label(String(localized: "Show Markdown Source", comment: "Settings toggle showing the Markdown characters"), systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    Toggle(String(localized: "Use First Line as Title", comment: "Settings toggle naming a new note after its first line"), isOn: $store.useFirstLineAsTitle)

                    Toggle(String(localized: "Always Use Internal Editor", comment: "Settings toggle for the built-in editor"), isOn: $store.internalEditor)
                } header: {
                    Text("Editing")
                } footer: {
                    Text("The editor shows formatted text: a bold word is bold, a heading is larger, and the Markdown characters stay hidden while typing. Show Markdown Source displays them for editing; the note is saved as Markdown either way.")
                }

                Section {
                    Toggle(String(localized: "Synchronize on Start", comment: "Settings toggle for synchronizing at launch"), isOn: $store.launchSynchronization)

                    Toggle(String(localized: "Offline Mode", comment: "Settings toggle for offline mode"), isOn: $store.offlineMode)
                } header: {
                    Text("Synchronization")
                } footer: {
                    Text("Offline Mode stops every request to the server. Changes stay on this device and are uploaded once it is turned off again.")
                }

                Section {
                    Button {
                        pathInAlert = store.notesPath
                        showPathAlert = true
                    } label: {
                        SettingsDetailRow(title: "Notes Path", detail: store.notesPath)
                    }
                    .buttonStyle(.plain)

                    Button {
                        fileExtensionInAlert = store.fileExtension.suffix
                        showFileExtensionAlert = true
                    } label: {
                        SettingsDetailRow(title: "File Extension", detail: store.fileExtension.suffix)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Server")
                } footer: {
                    Text("Both values are stored on the server and apply to every client that uses this account.")
                }

                Section {
                    LabeledContent {
                        Text(verbatim: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"))")
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(String(localized: "Client Version", comment: "Settings label for the app version"))
                    }

                    LabeledContent {
                        Text(verbatim: KeychainHelper.serverVersion)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(String(localized: "Server Version", comment: "Settings label for the server version"))
                    }

                    if let url = URL(string: NCBrandOptions.shared.privacyUrl) {
                        NavigationLink {
                            WebView(initialURL: url)
                        } label: {
                            Label(String(localized: "Privacy and Legal Policy", comment: "Settings link to the privacy policy"), systemImage: "hand.raised")
                        }
                    }

                    if let url = URL(string: NCBrandOptions.shared.sourceCodeUrl) {
                        Button {
                            openURL(url)
                        } label: {
                            Label(String(localized: "Source Code on GitHub", comment: "Settings link to the source code"), systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle(String(localized: "Settings", comment: "Title of the settings tab"))
            .toolbarTitleDisplayMode(.inline)
            .alert(String(localized: "Logout", comment: "Title of the logout confirmation"), isPresented: $showLogoutConfirmation) {
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
            .alert(String(localized: "Notes Path", comment: "Title of the alert to change the notes folder"), isPresented: $showPathAlert) {
                TextField(String(localized: "Notes Path", comment: "Placeholder of the notes folder field"), text: $pathInAlert)

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
                Text("Enter the name of the folder where notes are saved on the server.")
            }
            .alert(String(localized: "File Extension", comment: "Title of the alert to change the file extension"), isPresented: $showFileExtensionAlert) {
                TextField(String(localized: "File Extension", comment: "Placeholder of the file extension field"), text: $fileExtensionInAlert)

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
                Text("Enter the extension of note files on the server, for example .md or .org.")
            }
            .alert(String(localized: "Invalid File Extension", comment: "Title of the alert shown for an invalid file extension"), isPresented: $showInvalidFileExtensionAlert) {
                Button(role: .cancel) {
                    // Keeps the previous extension.
                } label: {
                    Text("OK")
                }
            } message: {
                Text("A file extension starts with a dot and contains only letters and digits, for example .md.")
            }
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

///
/// A settings row whose value is stored on the server.
///
/// It carries the disclosure chevron because it is tappable: without it the row read like plain text.
///
private struct SettingsDetailRow: View {
    let title: LocalizedStringKey
    let detail: String

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                Text(verbatim: detail)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        } label: {
            Text(title)
                .foregroundStyle(.primary)
        }
        .contentShape(.rect)
    }
}

#Preview {
    SettingsView()
        .environment(Store())
}
