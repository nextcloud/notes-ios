//
//  LoginViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/23/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import PKHUD
import UIKit
import WebKit

class LoginViewController: UIViewController {

    var serverAddress = ""
    var user: String?

    private var webView: WKWebView?
    private var ignoreNavigationFailure = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        webView = WKWebView(frame: .zero, configuration: config)
        webView!.navigationDelegate = self
        view.addSubview(webView!)

        webView!.translatesAutoresizingMaskIntoConstraints = false
        webView!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0).isActive = true
        webView!.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive = true
        webView!.topAnchor.constraint(equalTo: view.topAnchor, constant: 0).isActive = true
        webView!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0).isActive = true

        var address = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !address.contains("://"),
           !address.hasPrefix("http") {
            address = "https://\(address)"
        }
        address = address.replacingOccurrences(of: "/index.php", with: "")
        var urlString = "\(address)/index.php/login/flow"
        if let user = self.user {
            urlString += "?user=\(user)"
        }
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)

            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let appName = "NextcloudNotes" // Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let userAgent = "Mozilla/5.0 (iOS) \(appName)/\(appVersion ?? "")"
            let language = Locale.preferredLanguages[0] as String

            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.addValue(language, forHTTPHeaderField: "Accept-Language")
            request.setValue("true", forHTTPHeaderField: "OCS-APIREQUEST")
            webView!.customUserAgent = userAgent
            webView!.navigationDelegate = self

            HUD.show(.progress)
            webView!.load(request)
        }
    }

    private func completeLogin() {
        let hudTitle = NSLocalizedString("Logged In", comment: "HUD title when logged in")
        let statusSubtitle = NSLocalizedString("Checking server status", comment: "HUD subtitle when checking server status")
        let capabilitiesSubtitle = NSLocalizedString("Checking server capabilities", comment: "HUD subtitle when checking server capabilities")
        let settingsSubtitle = NSLocalizedString("Checking server settings", comment: "HUD subtitle when checking server settings")
        HUD.show(.labeledProgress(title: hudTitle, subtitle: statusSubtitle))
        NoteSessionManager.shared.status() {
            HUD.show(.labeledProgress(title: hudTitle, subtitle: capabilitiesSubtitle))
            NoteSessionManager.shared.capabilities() {
                HUD.show(.labeledProgress(title: hudTitle, subtitle: settingsSubtitle))
                NoteSessionManager.shared.settings { [weak self] in
                    print("All Done")
                    HUD.hide()
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
}

extension LoginViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("decidePolicyFor")
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation")
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation")

        guard let url = webView.url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.scheme == "nc", let path = components?.path {
            let pathItems = path.components(separatedBy: "&")
            print(pathItems)
            if let serverItem = pathItems.first(where: { $0.hasPrefix("/server:") }) {
                KeychainHelper.server = String(serverItem.dropFirst(8))
            }
            if let userItem = pathItems.first(where: { $0.hasPrefix("user:") }) {
                KeychainHelper.username = String(userItem.dropFirst(5))
            }
            if let passwordItem = pathItems.first(where: { $0.hasPrefix("password:") }) {
                KeychainHelper.password = String(passwordItem.dropFirst(9))
            }
            if !KeychainHelper.server.isEmpty, !KeychainHelper.username.isEmpty, !KeychainHelper.password.isEmpty {
                ignoreNavigationFailure = true
                completeLogin()
            } else {
                navigationController?.popViewController(animated: true)
            }
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("didCommit")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("didFailProvisionalNavigation \(error.localizedDescription)")

        if !ignoreNavigationFailure {
            let alertController = UIAlertController(title: NSLocalizedString("Error", comment: "An error message title"),
                                                    message: error.localizedDescription,
                                                    preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Caption of OK button"), style: .cancel, handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
            alertController.addAction(cancelAction)
            ignoreNavigationFailure = false
            present(alertController, animated: true, completion: nil)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("didFail \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil);
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
        HUD.hide()
    }

}
