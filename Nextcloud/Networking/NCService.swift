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
    var jsonCapabilities: JSON?

    // MARK: -

    @objc public func startRequestServicesServer(completion: @escaping () -> Void) {

        guard !KeychainHelper.server.isEmpty,
              !KeychainHelper.username.isEmpty,
              !KeychainHelper.password.isEmpty,
              let server = URL(string: KeychainHelper.server),
              let scheme = server.scheme,
              let host = server.host
        else { return }

        let urlBase = scheme + "://" + host
        let user = KeychainHelper.username
        let password = KeychainHelper.password
        let account: String = "\(user) \(urlBase)"

        settingAccount(account, urlBase: urlBase, user: user, userId: user, password: password)
        requestServerCapabilities(completion: completion)
    }

    private func settingAccount(_ account: String, urlBase: String, user: String, userId: String, password: String) {

        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: urlBase)
    }

    private func requestServerCapabilities(completion: @escaping () -> Void) {

        NextcloudKit.shared.getCapabilities { account, data, error in
            if error == .success, let data = data {
                data.printJson()
                self.jsonCapabilities = JSON(data)
                if let jsonCapabilities = NCService.shared.jsonCapabilities,
                   let version = jsonCapabilities[NCElementsJSON.shared.capabilitiesNotesVersion].string,
                   let apiVersion = jsonCapabilities[NCElementsJSON.shared.capabilitiesNotesApiVersion].array?.last?.string {
                    KeychainHelper.notesVersion = version
                    KeychainHelper.notesApiVersion = apiVersion
                }
            }  else {
                self.jsonCapabilities = nil
            }
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

