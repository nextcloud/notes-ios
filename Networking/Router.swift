// SPDX-FileCopyrightText: 2020 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import Version

typealias Parameters = [String: Any]

enum RouterError: Error {
    case missingURL
}

///
/// Network router for Nextcloud Notes API.
///
enum Router {
    case allNotes(exclude: String)
    case getNote(id: Int, exclude: String, etag: String)
    case createNote(parameters: Parameters)
    case updateNote(id: Int, paramters: Parameters)
    case deleteNote(id: Int)
    case settings
    case updateSettings(notesPath: String, fileSuffix: String)

    static let applicationJson = "application/json"
    static let defaultApiVersion = "0.2"

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    private var method: HTTPMethod {
        switch self {
            case .allNotes, .getNote, .settings:
                return .get
            case .createNote:
                return .post
            case .updateNote, .updateSettings:
                return .put
            case .deleteNote:
                return .delete
        }
    }

    private var path: String {
        switch self {
            case .allNotes:
                return "/notes"
            case .getNote(let id , _, _):
                return "/notes/\(id)"
            case .createNote:
                return "/notes"
            case .updateNote(let id, _):
                return "/notes/\(id)"
            case .deleteNote(let id):
                return "/notes/\(id)"
            case .settings, .updateSettings:
                return "/settings"
        }
    }

    func asURLRequest() throws -> URLRequest {
        let server = KeychainHelper.server

        guard server.isEmpty == false else {
            throw RouterError.missingURL
        }

        var apiVersion = Router.defaultApiVersion

        let version = try Version(KeychainHelper.notesApiVersion)

        if version.major == 1 {
            apiVersion = "1"
        }

        guard var components = canonicalServerComponents(from: server) else {
            throw RouterError.missingURL
        }

        let basePath = components.path
        components.path = basePath + "/index.php/apps/notes/api/v\(apiVersion)" + self.path

        guard let url = components.url else {
            throw RouterError.missingURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = self.method.rawValue

        let username = KeychainHelper.username
        let password = KeychainHelper.password
        let credential = Data("\(username):\(password)".utf8).base64EncodedString()

        urlRequest.setValue("Basic \(credential)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(Router.applicationJson, forHTTPHeaderField: "Accept")

        switch self {
            case .allNotes(let exclude):
                if !KeychainHelper.eTag.isEmpty {
                    urlRequest.setValue(KeychainHelper.eTag, forHTTPHeaderField: "If-None-Match")
                }

                var parameters = Parameters()

                if !exclude.isEmpty {
                    parameters["exclude"] = exclude
                }

                if KeychainHelper.lastModified > 0 {
                    parameters["pruneBefore"] = KeychainHelper.lastModified
                }

                Router.encode(parameters, into: &urlRequest)
            case .getNote(_, let exclude, let etag):
                if !etag.isEmpty {
                    urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
                }

                Router.encode(["exclude": exclude], into: &urlRequest)
            case .createNote(let parameters):
                Router.encode(parameters, into: &urlRequest)
            case .updateNote(_, let parameters):
                Router.encode(parameters, into: &urlRequest)
            case .updateSettings(let notesPath, let fileSuffix):
                Router.encode(["notesPath": notesPath, "fileSuffix": fileSuffix], into: &urlRequest)
            default:
                break
        }

        return urlRequest
    }
}

// MARK: - Parameter encoding

private extension Router {
    ///
    /// Encodes parameters like Alamofire's `URLEncoding.default` did: into the query
    /// string for GET/DELETE, into a form-urlencoded body for POST/PUT.
    ///
    static func encode(_ parameters: Parameters, into urlRequest: inout URLRequest) {
        guard !parameters.isEmpty else { return }

        let query = parameters
            .sorted { $0.key < $1.key }
            .map { "\(escape($0.key))=\(escape(encodedValue($0.value)))" }
            .joined(separator: "&")

        if urlRequest.httpMethod == HTTPMethod.get.rawValue || urlRequest.httpMethod == HTTPMethod.delete.rawValue {
            guard let url = urlRequest.url,
                  var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return
            }

            let existingQuery = components.percentEncodedQuery.map { $0 + "&" } ?? ""
            components.percentEncodedQuery = existingQuery + query
            urlRequest.url = components.url
        } else {
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }

            urlRequest.httpBody = Data(query.utf8)
        }
    }

    /// `.urlQueryAllowed` minus the delimiters Alamofire escaped; `/` and `?` stay literal.
    static let allowedCharacters: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return allowed
    }()

    static func escape(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? string
    }

    /// Booleans must encode as `1`/`0` — the server treats a literal `"false"` as truthy.
    static func encodedValue(_ value: Any) -> String {
        switch value {
            case let number as NSNumber where CFGetTypeID(number) == CFBooleanGetTypeID():
                return number.boolValue ? "1" : "0"
            case let bool as Bool:
                return bool ? "1" : "0"
            default:
                return "\(value)"
        }
    }
}
