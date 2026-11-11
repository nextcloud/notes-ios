// SPDX-FileCopyrightText: 2021 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

///
/// The extension of the note files on the server.
///
/// Nextcloud Notes accepts any file extension, so this is a validated string and not a fixed set: an
/// installation configured with `.org` or `.markdown` keeps working instead of silently falling back
/// to `.txt`.
///
struct FileSuffix: Hashable, Sendable {
    static let txt = FileSuffix(valid: ".txt")
    static let md = FileSuffix(valid: ".md")

    /// The suffix including the leading dot, e.g. `.md`.
    let suffix: String

    ///
    /// Creates a suffix from user or server input.
    ///
    /// - Parameter suffix: `.md`, `md` and `.MD` all normalize to `.md`.
    ///
    init?(validating suffix: String) {
        let normalized = suffix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let withDot = normalized.hasPrefix(".") ? normalized : "." + normalized
        let name = withDot.dropFirst()

        // File extensions are short and may only contain ASCII letters and digits, which keeps the value
        // safe to use in the file name the server creates.
        guard !name.isEmpty,
              name.count <= 16,
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
            return nil
        }

        self.suffix = withDot
    }

    private init(valid suffix: String) {
        self.suffix = suffix
    }

    /// Whether this is one of the extensions the app offers by name.
    var isKnown: Bool {
        self == .txt || self == .md
    }
}

extension FileSuffix: CustomStringConvertible {
    var description: String {
        switch self {
            case .txt:
                return NSLocalizedString("Plain Text (\(suffix))", comment: "Extension for plain text")
            case .md:
                return NSLocalizedString("Markdown (\(suffix))", comment: "Extension for markdown")
            default:
                return suffix
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
