// SPDX-FileCopyrightText: 2019 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import KeychainAccess

struct KeychainHelper {
    ///
    /// The credentials of the account.
    ///
    /// `afterFirstUnlock` keeps the account readable in the background and right after a reboot, once the
    /// device has been unlocked: with the default accessibility the first synchronization after a restart
    /// found an empty keychain, treated the user as signed out and surfaced `401` and "Not logged in".
    ///
    private static let keychain = Keychain(service: "com.peterandlinda.CloudNotes")
        .accessibility(.afterFirstUnlock)

    ///
    /// A computed property to automatically derive the account identifier for the currently only possible account from ``server`` and ``username``.
    ///
    static var account: String? {
        guard let parsedComponents = URLComponents(string: server) else {
            return nil
        }

        guard let scheme = parsedComponents.scheme else {
            return nil
        }

        guard let host = parsedComponents.host else {
            return nil
        }

        var assembledComponents = URLComponents()
        assembledComponents.scheme = scheme
        assembledComponents.host = host

        if let port = parsedComponents.port {
            assembledComponents.port = port
        }

        guard let baseURL = assembledComponents.url?.absoluteString else {
            return nil
        }

        return "\(username) \(baseURL)"
    }

    static var serverMajorVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: "ServerMajorVersion")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ServerMajorVersion")
        }
    }

    static var serverMinorVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: "ServerMinorVersion")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ServerMinorVersion")
        }
    }

    static var serverMicroVersion: Int {
        get {
            return UserDefaults.standard.integer(forKey: "ServerMicroVersion")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ServerMicroVersion")
        }
    }

    static var username: String {
        get {
            return keychain["username"] ?? ""
        }
        set {
            keychain["username"] = newValue
        }
    }

    static var password: String {
        get {
            return keychain["password"] ?? ""
        }
        set {
            keychain["password"] = newValue
        }
    }

    static var server: String {
        get {
            return UserDefaults.standard.string(forKey: "Server") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "Server")
        }
    }

    static var notesPath: String {
        get {
            return UserDefaults.standard.string(forKey: "NotesPath") ?? Constants.notesPath
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "NotesPath")
        }
    }

    static var fileSuffix: FileSuffix {
        get {
            if let stored = UserDefaults.standard.string(forKey: "FileSuffixString"),
               let suffix = FileSuffix(validating: stored) {
                return suffix
            }

            // Installs older than custom extensions stored the index of the former enum.
            switch UserDefaults.standard.integer(forKey: "FileSuffix") {
                case 1:
                    return .md
                default:
                    return .txt
            }
        }
        set {
            UserDefaults.standard.set(newValue.suffix, forKey: "FileSuffixString")
            UserDefaults.standard.set(newValue == .md ? 1 : 0, forKey: "FileSuffix")
        }
    }

    static var version: String? {
        get {
            return UserDefaults.standard.string(forKey: "version")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "version")
        }
    }

    static var syncOnStart: Bool {
        get {
            // The app always synchronized on start before this setting took effect, so keep that for users who never
            // changed it.
            return UserDefaults.standard.object(forKey: "SyncOnStart") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SyncOnStart")
        }
    }

    ///
    /// Whether a new note takes its title from its first line, as the web app does.
    ///
    /// Off keeps the name the note was created with, which is what users of synced Markdown files
    /// asked for: editing a note must not rename the file on the server.
    ///
    static var useFirstLineAsTitle: Bool {
        get {
            return UserDefaults.standard.object(forKey: "UseFirstLineAsTitle") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "UseFirstLineAsTitle")
        }
    }

    ///
    /// Whether the editor shows the Markdown characters instead of the formatted text.
    ///
    /// Off is the reading mode: a note looks like a rich text document, the delimiters are invisible, and
    /// it stays editable. On shows `**bold**` and `# heading`, for people who want to edit the source.
    /// Either way the note is saved as Markdown.
    ///
    static var showMarkdownSource: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "ShowMarkdownSource")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ShowMarkdownSource")
        }
    }

    static var offlineMode: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "OfflineMode")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "OfflineMode")
            NotificationCenter.default.post(name: .offlineModeChanged, object: nil)
        }
    }

    static var allowUntrustedCertificate: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "AllowUntrustedCertificate")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "AllowUntrustedCertificate")
        }
    }

    static var dbReset: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "dbReset")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "dbReset")
        }
    }

    static var groupByCategory: Bool {
        get {
            if UserDefaults.standard.object(forKey: "GroupByCategory") == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: "GroupByCategory")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "GroupByCategory")
        }
    }

    static var sectionExpandedInfo: DisclosureSections {
        get {
            if let data = UserDefaults.standard.value(forKey: "Sections") as? Data,
                let result = try? JSONDecoder().decode(DisclosureSections.self, from: data) {
                return result
            }
            return DisclosureSections()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "Sections")
            }
        }
    }
    
    static var notesApiVersion: String {
        get {
            // An empty string can linger from older builds and would make every request fail version parsing.
            guard let version = UserDefaults.standard.string(forKey: "notesApiVersion"), !version.isEmpty else {
                return Router.defaultApiVersion
            }

            return version
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notesApiVersion")
        }
    }

    static var notesVersion: String {
        get {
            return UserDefaults.standard.string(forKey: "notesVersion") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notesVersion")
        }
    }

    static var productVersion: String {
        get {
            return UserDefaults.standard.string(forKey: "productVersion") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "productVersion")
        }
    }
    
    static var productName: String {
        get {
            return UserDefaults.standard.string(forKey: "productName") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "productName")
        }
    }

    ///
    /// The version of the server as reported by its capabilities, e.g. `32.0.3`.
    ///
    /// The capabilities are fetched on every synchronization, while the `/status.php` product version is only
    /// known once a status request succeeded. Falling back to the latter keeps the value useful on servers that
    /// do not report capabilities.
    ///
    static var serverVersion: String {
        guard serverMajorVersion > 0 else {
            return productVersion
        }

        return "\(serverMajorVersion).\(serverMinorVersion).\(serverMicroVersion)"
    }

    /// Any install <= 35.0.0 has a bug where notes are not fully synced, as `eTag` and `lastModified` were not reset upon log out. Reset once so the first sync fetches everything.
    static var didResetSyncValidators: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "didResetSyncValidators")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "didResetSyncValidators")
        }
    }

    static var eTag: String {
        get {
            return UserDefaults.standard.string(forKey: "eTag") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "eTag")
        }
    }

    static var lastModified: Int {
        get {
            return UserDefaults.standard.integer(forKey: "lastModified")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastModified")
        }
    }

    static var internalEditor: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "InternalEditor")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "InternalEditor")
        }
    }

    static var directEditingSupportsFileId: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "directEditingSupportsFileId")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "directEditingSupportsFileId")
        }
    }

    static var shouldShowOnboarding: Bool {
        get {
            if UserDefaults.standard.object(forKey: "shouldShowOnboarding") == nil {
                return true
            }

            return UserDefaults.standard.bool(forKey: "shouldShowOnboarding")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "shouldShowOnboarding")
        }
    }
}
