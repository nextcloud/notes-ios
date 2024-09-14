//
//  NCBrandColor.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/04/17.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

let userAgent: String = {
    let appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    // Original Nextcloud useragent "Mozilla/5.0 (iOS) Nextcloud-iOS/\(appVersion)"
    return "Mozilla/5.0 (iOS) Nextcloud-iOS/\(appVersion)"
}()

class NCBrandOptions: NSObject {
    static let shared: NCBrandOptions = {
        let instance = NCBrandOptions()
        return instance
    }()
    
    var brand: String = "Nextcloud"
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
