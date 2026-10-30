// SPDX-FileCopyrightText: 2016-2021 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import UIKit

class PreviewViewController: UIViewController {

    var content: String?
    var noteTitle: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        if let content = content {
            do {
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
