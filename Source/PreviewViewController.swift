// SPDX-FileCopyrightText: 2016-2021 Peter Hedlund
// SPDX-FileCopyrightText: 2026 Julian Schneider
// SPDX-License-Identifier: BSD-2-Clause

import UIKit

class PreviewViewController: UIViewController {

    var content: String?
    var noteTitle: String?

    /// Whether tapping a checkbox may change the note. Read only notes cannot be written back.
    var allowsCheckBoxToggling = true

    /// Called when tapping a checkbox has changed the note.
    var onContentChanged: ((String) -> Void)?

    private var previewWebView: PreviewWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = noteTitle
        guard let content else {
            return
        }
        do {
            let previewWebView = try PreviewWebView(markdown: content) {
                print("Markdown was rendered.")
            }
            previewWebView.onCheckBoxTapped = { [weak self] checkBox in
                self?.toggleCheckBox(checkBox)
            }
            self.previewWebView = previewWebView

            previewWebView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(previewWebView)
            NSLayoutConstraint.activate([
                previewWebView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                previewWebView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                previewWebView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                previewWebView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            ])
        } catch {
            //
        }
    }

    /// Ticks or clears the tapped checkbox and shows the result right away.
    private func toggleCheckBox(_ checkBox: PreviewCheckBoxes.CheckBox) {
        guard allowsCheckBoxToggling,
              let current = content,
              let toggled = PreviewCheckBoxes.toggling(current, at: checkBox) else {
            return
        }
        content = toggled
        previewWebView?.update(markdown: toggled)
        onContentChanged?(toggled)
    }

}
