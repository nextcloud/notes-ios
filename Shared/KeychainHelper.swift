//
//  KeychainHelper.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/18/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation
import KeychainAccess

struct KeychainHelper {
    private static let keychain = Keychain(service: "com.peterandlinda.CloudNotes")

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
            return FileSuffix(rawValue: UserDefaults.standard.integer(forKey: "FileSuffix")) ?? FileSuffix.txt
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "FileSuffix")
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
            return UserDefaults.standard.bool(forKey: "SyncOnStart")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "SyncOnStart")
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

    static var didSyncInBackground: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "didSyncInBackground")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "didSyncInBackground")
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
            return UserDefaults.standard.string(forKey: "notesApiVersion") ?? Router.defaultApiVersion
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

    static var directEditing: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "directEditing")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "directEditing")
        }
    }
}
