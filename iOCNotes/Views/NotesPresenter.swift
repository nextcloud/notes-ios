// SPDX-FileCopyrightText: 2025 Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit

///
/// Bridges the SwiftUI notes list to the remaining UIKit screens (note editor, category picker and share sheet).
///
/// These screens are presented modally from the current top view controller, matching the behaviour the storyboard
/// segues provided before the list was rewritten in SwiftUI.
///
enum NotesPresenter {
    ///
    /// Open the given note when direct editing is available and the
    /// built-in editor otherwise. Direct editing uploads a note that only exists locally first.
    ///
    @discardableResult
    static func openEditor(for note: Note, isNewNote: Bool) -> Bool {
        guard isDirectEditingAvailable, !note.addNeeded || NoteSessionManager.isOnline else {
            return openInBuiltInEditor(note: note, isNewNote: isNewNote)
        }

        return openInDirectEditing(note: note, isNewNote: isNewNote)
    }

    @discardableResult
    private static func openInBuiltInEditor(note: Note, isNewNote: Bool) -> Bool {
        let storyboard = UIStoryboard(name: "Main_iPhone", bundle: nil)
        guard let navigationController = storyboard.instantiateViewController(withIdentifier: "Editor") as? UINavigationController,
              let editor = navigationController.topViewController as? EditorViewController,
              let presenter = UIApplication.topViewController() else {
            return false
        }

        editor.note = note
        editor.isNewNote = isNewNote
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true)
        return true
    }

    ///
    /// Present the category picker for the given note.
    ///
    static func openCategories(for note: Note, categories: [String]) {
        let storyboard = UIStoryboard(name: "Categories", bundle: Bundle.main)
        guard let navigationController = storyboard.instantiateViewController(withIdentifier: "CategoryNavigationController") as? UINavigationController,
              let categoryController = navigationController.topViewController as? CategoryTableViewController,
              let presenter = UIApplication.topViewController() else {
            return
        }

        categoryController.categories = categories
        categoryController.note = note
        presenter.present(navigationController, animated: true)
    }

    ///
    /// Present the share sheet for the given note.
    ///
    static func share(note: Note, exporter: inout NoteExporter?) {
        guard !note.content.isEmpty,
              let presenter = UIApplication.topViewController() else {
            return
        }

        let bounds = presenter.view.bounds
        let anchor = CGRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1)
        let noteExporter = NoteExporter(title: note.title, text: note.content, viewController: presenter, from: anchor, in: presenter.view)
        exporter = noteExporter
        noteExporter.showMenu()
    }

    ///
    /// Whether notes should open in the server's collaborative text editor instead of the built-in one.
    ///
    private static var isDirectEditingAvailable: Bool {
        guard KeychainHelper.internalEditor == false,
              KeychainHelper.directEditingSupportsFileId else {
            return false
        }

        let reachability = AppDelegate.shared.networkReachability
        return reachability == .reachableCellular || reachability == .reachableEthernetOrWiFi
    }

    private static func openInDirectEditing(note: Note, isNewNote: Bool) -> Bool {
        guard let account = KeychainHelper.account,
              let presenter = UIApplication.topViewController(),
              let viewer = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText else {
            return false
        }

        viewer.fileName = note.title

        viewer.loadLink = {
            try await directEditingURL(for: note, account: account)
        }

        viewer.switchToInternalEditor = {
            guard note.managedObjectContext != nil else { return }

            openInBuiltInEditor(note: note, isNewNote: isNewNote)
        }

        let navigationController = UINavigationController(rootViewController: viewer)
        navigationController.modalPresentationStyle = .fullScreen
        presenter.present(navigationController, animated: true)

        return true
    }

    @MainActor
    private static func directEditingURL(for note: Note, account: String) async throws -> URL {
        if note.addNeeded {
            await NoteSessionManager.shared.add(note: note)

            guard note.managedObjectContext != nil, !note.addNeeded else {
                throw NKError(errorCode: NSURLErrorCannotCreateFile, errorDescription: NSLocalizedString("Error Adding Note", comment: "The title of an error message"))
            }
        }

        let result = await NextcloudKit.shared.openFileForDirectEditingAsync(fileNamePath: KeychainHelper.notesPath, fileId: String(note.id), editorId: "text", account: account)

        guard result.error == .success else { throw result.error }

        guard let link = result.url, let url = URL(string: link) else { throw NKError.invalidResponseError }

        return url
    }
}
