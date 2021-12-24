//
//  LoginWebViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/23/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import UIKit
import WebKit

class LoginWebViewController: UIViewController {

    @IBOutlet var webView: WKWebView!

    var serverAddress = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        var address = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !address.contains("://"),
           !address.hasPrefix("http") {
            address = "https://\(address)"
        }
        address = address.replacingOccurrences(of: "/index.php", with: "")
        let urlString = "\(address)/index.php/login/flow"
        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)

            let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let appName = "CloudNotes" // Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let userAgent = "Mozilla/5.0 (iOS) \(appName)/\(appVersion ?? "")"
            let language = Locale.preferredLanguages[0] as String

            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.addValue(language, forHTTPHeaderField: "Accept-Language")
            request.setValue("true", forHTTPHeaderField: "OCS-APIREQUEST")
            webView.customUserAgent = userAgent
            webView.navigationDelegate = self
            webView.load(request)
        }
    }

    private func completeLogin() {
        NoteSessionManager.shared.status() {
            NoteSessionManager.shared.capabilities() {
                NoteSessionManager.shared.settings { [weak self] in
                    print("All Done")
                    self?.navigationController?.popViewController(animated: true)
                }
            }
        }
    }
}

extension LoginWebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {

        guard let url = webView.url else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        print(components?.scheme ?? "")
        print(components?.path ?? "")
        print(components?.fragment ?? "")
        print(components?.user ?? "")
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
                completeLogin()
            } else {
                navigationController?.popViewController(animated: true)
            }
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {

    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        //
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil);
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("didStartProvisionalNavigation");
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        activityIndicator.stopAnimating()
//        print("didFinishProvisionalNavigation");
//
//        if loginFlowV2Available {
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                NCCommunication.shared.getLoginFlowV2Poll(token: self.loginFlowV2Token, endpoint: self.loginFlowV2Endpoint) { (server, loginName, appPassword, errorCode, errorDescription) in
//                    if errorCode == 0 && server != nil && loginName != nil && appPassword != nil {
//                        self.createAccount(server: server!, username: loginName!, password: appPassword!)
//                    }
//                }
//            }
//        }
    }


}
