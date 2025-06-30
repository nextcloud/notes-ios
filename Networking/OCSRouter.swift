// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Alamofire
import Foundation

///
/// Network router for server capabilities endpoint.
///
/// > Notice: This implementation might be obsolete and redundant because of available NextcloudKit features.
///
enum OCSRouter: URLRequestConvertible {
    case capabilities

    var method: HTTPMethod {
        switch self {
            case .capabilities:
                return .get
        }
    }

    var path: String {
        switch self {
        case .capabilities:
            return "/capabilities"
        }
    }

    func asURLRequest() throws -> URLRequest {
        let serverAddress = KeychainHelper.server

        guard serverAddress.isEmpty == false else {
            throw AFError.parameterEncodingFailed(reason: .missingURL)
        }

        var endpointComponents = URLComponents()
        
        if let serverAddressURL = URL(string: serverAddress),
            let serverAddressComponents = URLComponents(url: serverAddressURL, resolvingAgainstBaseURL: false) {
            endpointComponents.scheme = serverAddressComponents.scheme
            endpointComponents.host = serverAddressComponents.host
            endpointComponents.port = serverAddressComponents.port
            endpointComponents.path = serverAddressComponents.path
            
            var serverAddressPathComponents = serverAddressURL.pathComponents

            if serverAddressPathComponents.last == "index.php" {
                serverAddressPathComponents = serverAddressPathComponents.dropLast()
            }

            var sanitizedPath = serverAddressPathComponents.joined(separator: "/")

            if sanitizedPath.last == "/" {
                sanitizedPath = String(sanitizedPath.dropLast())
            }

            if sanitizedPath.hasPrefix("//") {
                sanitizedPath = String(sanitizedPath.dropFirst())
            }

            endpointComponents.path = [sanitizedPath, "ocs/v1.php/cloud", self.path].joined(separator: "/")
        }

        let url = try endpointComponents.url ?? serverAddress.asURL()

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = self.method.rawValue

        let username = KeychainHelper.username
        let password = KeychainHelper.password

        urlRequest.headers = [
            .authorization(username: username, password: password),
            .accept(Router.applicationJson),
            .ocsAPIRequest(true)
        ]

        return urlRequest
    }
}


