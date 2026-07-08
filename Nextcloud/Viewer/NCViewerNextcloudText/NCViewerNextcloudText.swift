//
//  NCViewerNextcloudText.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/12/19.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import WebKit
import JGProgressHUD

class NCViewerNextcloudText: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    private static let messageHandlerName = "DirectEditingMobileInterface"

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    // The web view is shared and reused across editor opens so its cached bundles and warm
    // web content process are not thrown away every time. See `DirectEditingWebEnvironment`.
    private var webView: WKWebView { DirectEditingWebEnvironment.shared.webView }
    var bottomConstraint: NSLayoutConstraint?
    var link: String = ""
    var editor: String = ""
    var fileName: String?
    let hud = JGProgressHUD()
    private var hasDismissedHud = false

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = fileName

        attachSharedWebView()
        hud.show(in: view)

        // The URL may not be available yet when the controller is presented (see
        // `NotesTableViewController.openTextWebView`); `load(link:)` is called once it arrives.
        if !link.isEmpty {
            load(link: link)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // Only tear down the shared web view when this controller is actually going away, not
        // when it is merely covered (e.g. by an alert).
        if isBeingDismissed || isMovingFromParent {
            detachSharedWebView()
        }
    }

    @objc func viewUnload() {
        self.dismiss(animated: true)
    }

    // MARK: - Shared web view

    private func attachSharedWebView() {
        let contentController = webView.configuration.userContentController
        // Remove any handler a previous presentation registered before adding this one, so the
        // shared content controller does not retain a dismissed controller.
        contentController.removeScriptMessageHandler(forName: Self.messageHandlerName)
        contentController.add(self, name: Self.messageHandlerName)

        webView.navigationDelegate = self
        webView.removeFromSuperview()
        view.addSubview(webView)

        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0)
        bottomConstraint?.isActive = true
    }

    private func detachSharedWebView() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageHandlerName)

        if webView.navigationDelegate === self {
            webView.navigationDelegate = nil
        }

        webView.removeFromSuperview()

        // Reset so the next open does not briefly show this note's editor.
        if let blank = URL(string: "about:blank") {
            webView.load(URLRequest(url: blank))
        }
    }

    // MARK: - Loading

    ///
    /// Load the editor at the given URL. Safe to call after the controller has been presented,
    /// which allows the presentation animation and connection warm-up to overlap the URL fetch.
    ///
    func load(link: String) {
        self.link = link

        guard let url = URL(string: link) else {
            handleLoadFailure(message: nil)
            return
        }

        var request = URLRequest(url: url)
        request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
        let language = NSLocale.preferredLanguages[0] as String
        request.addValue(language, forHTTPHeaderField: "Accept-Language")

        webView.load(request)
    }

    private func dismissHud() {
        guard !hasDismissedHud else { return }
        hasDismissedHud = true
        hud.dismiss()
    }

    private func handleLoadFailure(message: String?) {
        dismissHud()

        let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default) { [weak self] _ in
            self?.viewUnload()
        })
        present(alert, animated: true)
    }

    // MARK: - NotificationCenter

    @objc func keyboardDidShow(notification: Notification) {

        guard let info = notification.userInfo else { return }
        guard let frameInfo = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardFrame = frameInfo.cgRectValue
        let height = keyboardFrame.size.height
        bottomConstraint?.constant = -height
    }

    @objc func keyboardWillHide(notification: Notification) {
        bottomConstraint?.constant = 0
    }

    // MARK: -

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        if message.name == Self.messageHandlerName {

            if message.body as? String == "close" {
                viewUnload()
            }

            if message.body as? String == "share" {
                // NCActionCenter.shared.openShare(viewController: self, metadata: metadata, indexPage: .sharing)
            }

            if message.body as? String == "loading" {
                print("loading")
            }

            if message.body as? String == "loaded" {
                // The editor JS is interactive; dismiss the loading indicator now.
                dismissHud()
            }

            if message.body as? String == "paste" {
                self.paste(self)
            }
        }
    }

    // MARK: -

    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation")
    }

    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation")
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // The editor JS may still be initializing after the navigation finishes; the bridge
        // posts a "loaded" message when it is interactive. Give it a short grace period, then
        // dismiss as a fallback in case that message never arrives on this server version.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.dismissHud()
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    private func handleNavigationError(_ error: Error) {
        // Cancelled loads happen when we replace the content (e.g. resetting to about:blank on
        // dismiss) and are not real failures.
        if (error as NSError).code == NSURLErrorCancelled {
            return
        }
        handleLoadFailure(message: error.localizedDescription)
    }
}

extension NCViewerNextcloudText: UINavigationControllerDelegate {

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)

        if parent == nil {
           // NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSourceNetworkForced, userInfo: ["serverUrl": self.metadata.serverUrl])
        }
    }
}
