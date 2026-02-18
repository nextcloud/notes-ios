//
//  AttachmentStore.swift
//  iOCNotes
//
//  Created by oli-ver on 15/08/25.
//  Copyright © 2025 Nextcloud GmbH. All rights reserved.
//

import Foundation
import os

final class AttachmentStore {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AttachmentStore")
    static let shared = AttachmentStore()
    private let root: URL

    private init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.root = base.appendingPathComponent("NoteAttachments", isDirectory: true)
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    // Normalizes relative paths and stores them in .../Caches/NoteAttachments/<noteId>/<relativePath>.
    func fileURL(noteId: Int, relativePath: String) -> URL {
        let safe = relativePath
            .replacingOccurrences(of: "://", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let noteFolder = root.appendingPathComponent(String(noteId), isDirectory: true)
        return noteFolder.appendingPathComponent(safe)
    }

    func contains(noteId: Int, path: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(noteId: noteId, relativePath: path).path)
    }

    @discardableResult
    func store(data: Data, noteId: Int, path: String) throws -> URL {
        let url = fileURL(noteId: noteId, relativePath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        logger.debug("Stored \(path, privacy: .public) for noteId \(noteId, privacy: .public) with url \(url, privacy: .public)")
        return url
    }

    func removeAll(for noteId: Int) {
        let dir = root.appendingPathComponent(String(noteId), isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    func purgeAll() {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
}
