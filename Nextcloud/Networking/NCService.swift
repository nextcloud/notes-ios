//
//  NCService.swift
//  iOCNotes
//
//  Created by Marino Faggiana on 17/03/23.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import SwiftyJSON

class NCService: NSObject {
    @objc static let shared: NCService = {
        let instance = NCService()
        return instance
    }()

    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    // MARK: -

    @objc public func startRequestServicesServer(completion: @escaping () -> Void) {
        NextcloudKit.shared.setup()

        for account in Store.shared.accounts {
            NextcloudKit.shared.appendSession(
                account: account.id,
                urlBase: account.baseURL,
                user: account.userId,
                userId: account.userId,
                password: account.password,
                userAgent: userAgent,
                nextcloudVersion: account.serverVersion.major,
                groupIdentifier: NCBrandOptions.shared.capabilitiesGroup
            )

            requestServerCapabilities(account: account.id, completion: completion)
        }
    }

    private func requestServerCapabilities(account: String, completion: @escaping () -> Void) {
        let capabilitiesDirectEditingSupportsFileId = [
            "ocs",
            "data",
            "capabilities",
            "files",
            "directEditing",
            "supportsFileId"
        ]

        let capabilitiesDirectEditing = [
            "ocs",
            "data",
            "capabilities",
            "richdocuments",
            "direct_editing"
        ]

        let capabilitiesNotesVersion = [
            "ocs",
            "data",
            "capabilities",
            "notes",
            "version"
        ]

        let capabilitiesNotesApiVersion = [
            "ocs",
            "data",
            "capabilities",
            "notes",
            "api_version"
        ]

        let serverVersion = [
            "ocs",
            "data",
            "version",
        ]

        NextcloudKit.shared.getCapabilities(account: account) { _, data, error in
            if error == .success, let data = data?.data {
                let jsonCapabilities = JSON(data)
                KeychainHelper.directEditing = jsonCapabilities[capabilitiesDirectEditing].boolValue
                KeychainHelper.directEditingSupportsFileId = jsonCapabilities[capabilitiesDirectEditingSupportsFileId].boolValue
                KeychainHelper.notesVersion = jsonCapabilities[capabilitiesNotesVersion].stringValue
                KeychainHelper.notesApiVersion = jsonCapabilities[capabilitiesNotesApiVersion].array?.last?.string ?? ""
                KeychainHelper.serverMajorVersion = jsonCapabilities[serverVersion]["major"].int ?? 0
                KeychainHelper.serverMinorVersion = jsonCapabilities[serverVersion]["minor"].int ?? 0
                KeychainHelper.serverMicroVersion = jsonCapabilities[serverVersion]["micro"].int ?? 0
            }

            NextcloudKit.shared.updateSession(account: account, nextcloudVersion: KeychainHelper.serverMajorVersion)

            completion()
        }
    }
}

extension Data {

    func printJson() {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: [])
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("Inavlid data")
                return
            }
            print(jsonString)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    func jsonToString() -> String {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: [])
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                print("Inavlid data")
                return ""
            }
            return jsonString
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        return ""
    }
}

