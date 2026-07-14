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
    /// Open the given note, using the server's collaborative text editor when direct editing is available and the
    /// built-in editor otherwise.
    ///
    @discardableResult
    static func openEditor(for note: Note, isNewNote: Bool) -> Bool {
        if isDirectEditingAvailable {
            return openInDirectEditing(note: note)
        }

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
              KeychainHelper.directEditing,
              KeychainHelper.directEditingSupportsFileId else {
            return false
        }

        let reachability = AppDelegate.shared.networkReachability
        return reachability == .reachableCellular || reachability == .reachableEthernetOrWiFi
    }

    private static func openInDirectEditing(note: Note) -> Bool {
        guard let account = KeychainHelper.account,
              UIApplication.topViewController() != nil else {
            return false
        }

        NextcloudKit.shared.textOpenFile(fileNamePath: KeychainHelper.notesPath, fileId: String(note.id), editor: "text", account: account) { _, url, _, error in
            DispatchQueue.main.async {
                guard let presenter = UIApplication.topViewController() else { return }

                if error == .success,
                   let url,
                   let viewController = UIStoryboard(name: "NCViewerNextcloudText", bundle: nil).instantiateInitialViewController() as? NCViewerNextcloudText {
                    viewController.editor = "text"
                    viewController.link = url
                    viewController.fileName = note.title
                    viewController.modalPresentationStyle = .fullScreen
                    presenter.present(viewController, animated: true)
                } else {
                    let title = NSLocalizedString("Error", comment: "Title of an error alert")
                    let messageFormat = NSLocalizedString("Cannot open file for direct editing: %@", comment: "Direct editing failure followed by the underlying error")
                    let alert = UIAlertController(title: title, message: String(format: messageFormat, error.localizedDescription), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default))
                    presenter.present(alert, animated: true)
                }
            }
        }

        return true
    }
}
