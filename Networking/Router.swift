//
//  NoteRouter.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/3/19.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import Alamofire
import Foundation
import Version

///
/// Network router for Nextcloud Notes API.
///
enum Router: URLRequestConvertible {
    case allNotes(exclude: String)
    case getNote(id: Int, exclude: String, etag: String)
    case createNote(parameters: Parameters)
    case updateNote(id: Int, paramters: Parameters)
    case deleteNote(id: Int)
    case settings
    case updateSettings(notesPath: String, fileSuffix: String)

    static let applicationJson = "application/json"
    static let defaultApiVersion = "0.2"

    var method: HTTPMethod {
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

    var path: String {
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
            throw AFError.parameterEncodingFailed(reason: .missingURL)
        }

        var apiVersion = Router.defaultApiVersion

        do {
            let version = try Version(KeychainHelper.notesApiVersion)
            if version.major == 1 {
                apiVersion = "1"
            }
        } catch {
            throw error
        }

        let baseURLString = "\(server)/index.php/apps/notes/api/v\(apiVersion)"
        let url = try baseURLString.asURL()

        var urlRequest = URLRequest(url: url.appendingPathComponent(self.path))
        urlRequest.httpMethod = self.method.rawValue
        let username = KeychainHelper.username
        let password = KeychainHelper.password

        urlRequest.headers = [
            .authorization(username: username, password: password),
            .accept(Router.applicationJson)
        ]

        switch self {
            case .allNotes(let exclude):
                if !KeychainHelper.eTag.isEmpty {
                    urlRequest.headers.add(.ifNoneMatch(KeychainHelper.eTag))
                }

                var parameters = Parameters()

                if !exclude.isEmpty {
                    parameters["exclude"] = exclude
                }

                if KeychainHelper.lastModified > 0 {
                    parameters["pruneBefore"] = KeychainHelper.lastModified
                }

                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            case .getNote(_, let exclude, let etag):
                let parameters = ["exclude": exclude] as [String : Any]

                if !etag.isEmpty {
                    urlRequest.headers.add(.ifNoneMatch(etag))
                }

                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            case .createNote(let parameters):
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            case .updateNote(_, let parameters):
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            case .updateSettings(let notesPath, let fileSuffix):
                let parameters = ["notesPath": notesPath, "fileSuffix": fileSuffix] as [String : Any]
                urlRequest = try URLEncoding.default.encode(urlRequest, with: parameters)
            default:
                break
        }

        return urlRequest
    }
}
