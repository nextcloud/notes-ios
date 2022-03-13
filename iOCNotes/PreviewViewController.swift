//
//  PreviewViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 7/9/16.
//  Copyright © 2016-2021 Peter Hedlund. All rights reserved.
//

import PKHUD
import UIKit

class PreviewViewController: UIViewController {

    @IBOutlet var editBarButton: UIBarButtonItem!

    var previewWebView: PreviewWebView?

    var content: String?
    var noteTitle: String?
    var noteDate: String?

    var note: CDNote? {
        didSet {
            if note != oldValue, let note = note {
                HUD.show(.progress)
                if !KeychainHelper.openInPreview {
                    content = note.content
                    noteTitle = note.title
                    noteDate = "\(note.modified)"
                    configure()
                    HUD.hide()
                } else {
                    NoteSessionManager.shared.get(note: note, completion: { [weak self] in
                        self?.content = note.content
                        self?.noteTitle = note.title
                        self?.noteDate = "\(note.modified)"
                        self?.configure()
                        HUD.hide()
                    })
                }
            }
        }
    }

    override func viewDidLoad() {
        do {
            previewWebView = try PreviewWebView()
            if let previewWebView = previewWebView {
                previewWebView.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(previewWebView)
                NSLayoutConstraint.activate([
                    previewWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    previewWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    previewWebView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    previewWebView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
                ])
            }
            navigationItem.rightBarButtonItem = editBarButton
        } catch {
            //
        }
    }

    @IBAction func onEditBarButton(_ sender: Any) {
        let editorController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "editorViewController") as! EditorViewController
//        editorViewController = editorController
//        let note = manager.fetchedResultsController.object(at: indexPath)
        editorController.note = note
        editorController.isNewNote = false
//        isAddingFromButton = false
#if !targetEnvironment(macCatalyst)
        if #available(iOS 14.0, *) {
            //
        } else {
            editorController.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
        }
        editorController.navigationItem.leftItemsSupplementBackButton = true
        editorController.navigationItem.title = noteTitle
        if splitViewController?.displayMode == .allVisible || splitViewController?.displayMode == .primaryOverlay {
            UIView.animate(withDuration: 0.3, animations: {
                self.splitViewController?.preferredDisplayMode = .primaryHidden
            }, completion: nil)
        }
#endif
        navigationController?.pushViewController(editorController, animated: true)
    }

    private func configure() {
        var previewContent = ""
        if let noteTitle = noteTitle {
            previewContent.append("# \(noteTitle)\n")
        }
        if let noteDate = noteDate {
            previewContent.append("*\(noteDate)*\n\n")
        }
        if let content = content {
            do {
                previewContent.append(content)
                try previewWebView?.loadHTML(previewContent)
            } catch {
                //
            }
        }
        self.navigationItem.title = noteTitle
    }

}
