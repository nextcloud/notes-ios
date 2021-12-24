//
//  SettingsProtocol.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/21/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Foundation

enum FileSuffix: Int, CustomStringConvertible {
    case txt = 0
    case md

    var description: String {
        switch self {
        case .txt:
            return NSLocalizedString("Plain Text (\(suffix))", comment: "Extension for plain text")
        case .md:
            return NSLocalizedString("Markdown (\(suffix))", comment: "Extension for markdown")
        }
    }

    var suffix: String {
        switch self {
        case .txt:
            return ".txt"
        case .md:
            return ".md"
        }
    }

}

protocol SettingsProtocol {
    var notesPath: String {get set}
    var fileSuffix: String {get set}
}

struct SettingsStruct: Codable, SettingsProtocol {

    var notesPath: String
    var fileSuffix: String

    enum CodingKeys: String, CodingKey {
        case notesPath
        case fileSuffix
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        notesPath = try values.decodeIfPresent(String.self, forKey: .notesPath) ?? Constants.notesPath
        fileSuffix = try values.decodeIfPresent(String.self, forKey: .fileSuffix) ?? FileSuffix.txt.suffix
    }

    init(notesPath: String, fileSuffix: String) {
        self.notesPath = notesPath
        self.fileSuffix = fileSuffix
    }
}
