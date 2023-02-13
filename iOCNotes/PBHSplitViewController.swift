//
//  PBHSplitViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 10/13/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit

class PBHSplitViewController: UISplitViewController {

    var editorViewController: EditorViewController?
    var notesTableViewController: NotesTableViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        preferredDisplayMode = .allVisible
    }

    @IBAction func onFileNew(sender: Any?) {
        notesTableViewController?.onAdd(sender: sender)
    }
    
    @IBAction func onViewSync(sender: Any?) {
        notesTableViewController?.onRefresh(sender: sender)
    }
}

extension PBHSplitViewController: UISplitViewControllerDelegate {

    func splitViewController(_ svc: UISplitViewController, willChangeTo displayMode: UISplitViewController.DisplayMode) {
        guard svc == self else {
            return
        }
        if displayMode == .allVisible || displayMode == .primaryOverlay {
            self.editorViewController?.noteView.resignFirstResponder()
        }
        if traitCollection.horizontalSizeClass == .regular,
            traitCollection.userInterfaceIdiom == .pad {
            if displayMode == .allVisible {
                editorViewController?.noteView.updateInsets(size: 50)
                DispatchQueue.main.async { [weak self] in
                    self?.editorViewController?.noteView.isScrollEnabled = false
                    self?.editorViewController?.noteView.isScrollEnabled = true
                }
            } else {
                if (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height) {
                    editorViewController?.noteView.updateInsets(size: 178)
                } else {
                    editorViewController?.noteView.updateInsets(size: 50)
                }
            }
        } else {
            editorViewController?.noteView.updateInsets(size: 20)
        }
    }
    
    func targetDisplayModeForAction(in svc: UISplitViewController) -> UISplitViewController.DisplayMode {
        if svc.displayMode == .primaryHidden {
            if svc.traitCollection.horizontalSizeClass == .regular,
            [.landscapeLeft, .landscapeRight].contains(UIDevice.current.orientation) {
                return .allVisible
            }
            return .primaryOverlay
        }
        return .primaryHidden
    }

    override func collapseSecondaryViewController(_ secondaryViewController: UIViewController, for splitViewController: UISplitViewController) {
        self.editorViewController?.note = nil
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }

    @available(iOS 14.0, *)
    func splitViewController(_ splitViewController: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        return .primary
    }

    @objc func onAddButtonAction(sender: UIBarButtonItem) {
        editorViewController?.onAdd(sender)
    }

    @objc func onRefreshButtonAction(sender: UIBarButtonItem) {
        notesTableViewController?.onRefresh(sender: sender)
    }

    @objc func onBackButtonAction(sender: UIBarButtonItem) {
        editorViewController?.navigationController?.popViewController(animated: true)
    }

    @objc func onPreviewButtonAction(sender: UIBarButtonItem) {
        editorViewController?.onPreview(sender)
    }
    
    @objc func onShareButtonAction(sender: UIBarButtonItem) {
            editorViewController?.onActivities(sender)
    }
    
    @IBAction func onPreferences(sender: Any) {
    }
    
}
