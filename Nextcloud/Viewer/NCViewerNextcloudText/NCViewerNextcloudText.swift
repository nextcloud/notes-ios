// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import WebKit
import JGProgressHUD
import NextcloudKit

class NCViewerNextcloudText: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    var webView = WKWebView()
    var bottomConstraint: NSLayoutConstraint?
    var fileName: String?
    let hud = JGProgressHUD()

    var loadLink: (() async throws -> URL)?

    var switchToInternalEditor: (() -> Void)?

    private var isLoaded = false
    private var isShowingLoadError = false
    private var isClosed = false

    // MARK: - View Life Cycle

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // navigationController?.setNavigationBarHidden(true, animated: true)
        navigationItem.title = fileName
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.close()
        })

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let contentController = config.userContentController
        contentController.add(self, name: "DirectEditingMobileInterface")

        webView = WKWebView(frame: CGRect.zero, configuration: config)
        webView.navigationDelegate = self
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 0).isActive = true
        webView.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: 0).isActive = true
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0).isActive = true
        bottomConstraint = webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0)
        bottomConstraint?.isActive = true

        webView.customUserAgent = getCustomUserAgentNCText()

        hud.show(in: view)

        loadEditor()
    }

    private func loadEditor() {
        // Like Android, stop waiting after 10 seconds; a late load still replaces the error.
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self, !isLoaded else { return }

            failToLoad(with: URLError(.timedOut))
        }

        Task {
            do {
                guard let url = try await loadLink?(), !isClosed else { return }

                var request = URLRequest(url: url)
                request.addValue("true", forHTTPHeaderField: "OCS-APIRequest")
                let language = NSLocale.preferredLanguages[0] as String
                request.addValue(language, forHTTPHeaderField: "Accept-Language")

                webView.load(request)
            } catch {
                failToLoad(with: error)
            }
        }
    }

    private func failToLoad(with error: Error) {
        // Text starting a new navigation cancels the previous one; that isn't a failure.
        guard !isLoaded, !isShowingLoadError, !isClosed, (error as NSError).code != NSURLErrorCancelled else { return }

        isShowingLoadError = true
        hud.dismiss()

        let detail = (error as? NKError)?.errorDescription ?? error.localizedDescription
        let messageFormat = NSLocalizedString("Cannot open file for direct editing: %@", comment: "Direct editing failure followed by the underlying error")
        let alert = UIAlertController(title: NSLocalizedString("Error", comment: "Title of an error alert"), message: String(format: messageFormat, detail), preferredStyle: .alert)

        if let switchToInternalEditor {
            alert.addAction(UIAlertAction(title: NSLocalizedString("Switch to Internal Editor", comment: "Action offered when the collaborative editor fails to load"), style: .default) { [weak self] _ in
                self?.viewUnload(completion: switchToInternalEditor)
            })
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("Close", comment: "Closes the editor that failed to load"), style: .cancel) { [weak self] _ in
            self?.viewUnload()
        })

        let showAlert = { [weak self] in
            self?.present(alert, animated: true)
        }

        // A quick failure can land while this screen is still being presented.
        if transitionCoordinator?.animate(alongsideTransition: nil, completion: { _ in showAlert() }) != true {
            showAlert()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // navigationController?.setNavigationBarHidden(false, animated: true)

        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func viewUnload(completion: (() -> Void)? = nil) {
        isClosed = true

        // The content controller retains its handler, so release it to break the cycle.
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "DirectEditingMobileInterface")
        self.dismiss(animated: true, completion: completion)
        // navigationController?.popViewController(animated: true)
    }

    private func close() {
        let script = """
        (function () {
          var closeIcons = document.getElementsByClassName("icon-close");
          if (closeIcons.length > 0) {
            closeIcons[0].click();
            return true;
          }
          return false;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard result as? Bool == true else {
                self?.viewUnload()
                return
            }

            // Text replies with a "close" message once saved; don't get stuck if it never does.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                guard let self, view.window != nil else { return }

                viewUnload()
            }
        }
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

    func getCustomUserAgentNCText() -> String {
        let version: String = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        let userAgent: String = "Mozilla/5.0 (iOS) NextcloudNotes/ " + version
        // return [NSString stringWithFormat:@"Mozilla/5.0 (iOS) %@/%@", userAgent, appVersion];
        if UIDevice.current.userInterfaceIdiom == .phone {
            // NOTE: Hardcoded (May 2022)
            // Tested for iPhone SE (1st), iOS 12; iPhone Pro Max, iOS 15.4
            // 605.1.15 = WebKit build version
            // 15E148 = frozen iOS build number according to: https://chromestatus.com/feature/4558585463832576
            return userAgent + " " + "AppleWebKit/605.1.15 Mobile/15E148"
        } else {
            return userAgent
        }
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        if message.name == "DirectEditingMobileInterface" {

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
                print("loaded")
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

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        failToLoad(with: error)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        failToLoad(with: error)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        hud.dismiss()

        if isShowingLoadError {
            isShowingLoadError = false
            presentedViewController?.dismiss(animated: true)
        }
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
