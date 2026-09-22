// SPDX-FileCopyrightText: 2016-2021 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import UIKit

class PreviewViewController: UIViewController {

    var content: String?
    var noteTitle: String?
    var noteDate: String?

    override func viewDidLoad() {
        super.viewDidLoad()
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

                let previewWebView = try PreviewWebView(markdown: content) {
                    print("Markdown was rendered.")
                }

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
        self.navigationItem.title = noteTitle
    }

}
