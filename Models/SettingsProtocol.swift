//
//  SettingsProtocol.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/21/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import Foundation

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
        notesPath = try values.decodeIfPresent(String.self, forKey: .notesPath) ?? "Notes"
        fileSuffix = try values.decodeIfPresent(String.self, forKey: .fileSuffix) ?? ".txt"
    }

    init(notesPath: String, fileSuffix: String) {
        self.notesPath = notesPath
        self.fileSuffix = fileSuffix
    }
}
