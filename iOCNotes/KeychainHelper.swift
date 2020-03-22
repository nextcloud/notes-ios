//
//  KeychainHelper.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/18/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import Foundation
import KeychainAccess

private protocol AnyOptional {
    var isNil: Bool { get }
}

extension Optional: AnyOptional {
    var isNil: Bool { self == nil }
}

@propertyWrapper struct UserDefaultsBacked<Value> {
    let key: String
    let defaultValue: Value
    var storage: UserDefaults = .standard

    var wrappedValue: Value {
        get {
            let value = storage.value(forKey: key) as? Value
            return value ?? defaultValue
        }
        set {
            if let optional = newValue as? AnyOptional, optional.isNil {
                storage.removeObject(forKey: key)
            } else {
                storage.setValue(newValue, forKey: key)
            }
        }
    }
}

extension UserDefaultsBacked where Value: ExpressibleByNilLiteral {
    init(key: String, storage: UserDefaults = .standard) {
        self.init(key: key, defaultValue: nil, storage: storage)
    }
}

@propertyWrapper struct KeychainBacked {
    let key: String
    let keychain = Keychain(service: "com.peterandlinda.CloudNotes")

    var wrappedValue: String {
        get { keychain[key] ?? "" }
        set { keychain[key] = newValue }
    }
}

struct KeychainHelper {

    @KeychainBacked(key: "username")
    static var username: String

    @KeychainBacked(key: "password")
    static var password: String

    @UserDefaultsBacked(key: "Server", defaultValue: "")
    static var server: String

    @UserDefaultsBacked(key: "version")
    static var version: String?

    @UserDefaultsBacked(key: "SyncOnStart", defaultValue: false)
    static var syncOnStart: Bool

    @UserDefaultsBacked(key: "OfflineMode", defaultValue: false)
    static var offlineMode: Bool

    @UserDefaultsBacked(key: "AllowUntrustedCertificate", defaultValue: false)
    static var allowUntrustedCertificate: Bool

    @UserDefaultsBacked(key: "IsNextCloud", defaultValue: false)
    static var isNextCloud: Bool

    @UserDefaultsBacked(key: "dbReset", defaultValue: false)
    static var dbReset: Bool
    
    static var sectionExpandedInfo: ExpandableSectionType {
        get {
            if let data = UserDefaults.standard.value(forKey: "Sections") as? Data,
                let result = try? JSONDecoder().decode(ExpandableSectionType.self, from: data) {
                return result
            }
            return ExpandableSectionType()
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "Sections")
            }
        }
    }
    
}
