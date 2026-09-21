// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2017 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

let userAgent: String = {
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    // Original Nextcloud useragent "Mozilla/5.0 (iOS) Nextcloud-iOS/\(appVersion)"
    return "Mozilla/5.0 (iOS) \(appName ?? "")/\(appVersion ?? "")"
}()

class NCBrandOptions: NSObject {
    static let shared: NCBrandOptions = {
        let instance = NCBrandOptions()
        return instance
    }()

    private override init() {}

    var brandName: String = "Nextcloud"
    var textCopyrightNextcloudiOS: String = "Nextcloud Hydrogen for iOS %@ © 2024"
    var textCopyrightNextcloudServer: String = "Nextcloud Server %@"
    var loginBaseUrl: String = "https://cloud.nextcloud.com"

    var privacyUrl: String = "https://nextcloud.com/privacy"
    var sourceCodeUrl: String = "https://github.com/nextcloud/notes-ios"

    var capabilitiesGroup: String = "group.it.twsweb.Crypto-Cloud"
    var capabilitiesGroupApps: String = "group.com.nextcloud.apps"

    var disableCustomLoginUrl: Bool = false
    var disableMultiAccount: Bool = false
}

class NCBrandColor: NSObject {
    static let shared: NCBrandColor = {
        let instance = NCBrandColor()
        return instance
    }()

    let brandColor: UIColor = UIColor(red: 0.0 / 255.0, green: 130.0 / 255.0, blue: 201.0 / 255.0, alpha: 1.0)
    var brandTextColor: UIColor = .white
}
