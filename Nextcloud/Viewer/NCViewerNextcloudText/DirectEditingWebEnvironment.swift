// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import WebKit

///
/// Owns the long-lived WebKit state used by the direct editing (Nextcloud Text) web view.
///
/// The Text app and server ship large JS/CSS bundles. Previously every editor open used an
/// ephemeral `WKWebsiteDataStore` and a freshly created `WKWebView`, forcing a full
/// re-download and re-parse of those bundles every single time. This singleton keeps the web
/// state alive so that:
///
/// - A **persistent** website data store caches the bundles, service worker and localStorage
///   on disk, surviving across editor opens and app launches.
/// - A shared `WKProcessPool` keeps the web content process (and its warm in-memory caches /
///   JIT-compiled JS) alive within a session.
/// - A single reusable `WKWebView` is moved into each `NCViewerNextcloudText` on open and
///   detached on dismiss instead of being rebuilt from scratch.
///
final class DirectEditingWebEnvironment {

    static let shared = DirectEditingWebEnvironment()

    private let processPool = WKProcessPool()

    ///
    /// The live content controller for the reusable web view. Held explicitly because
    /// `WKWebView.configuration` returns a copy, so script message handlers must be registered
    /// through this original reference to take effect.
    ///
    let userContentController = WKUserContentController()

    ///
    /// Persistent, shared configuration used for the reusable web view.
    ///
    private lazy var configuration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.processPool = processPool
        configuration.userContentController = userContentController
        return configuration
    }()

    ///
    /// The single reusable web view. Attaching it to a view controller reuses its cached state
    /// and warm web content process across editor opens.
    ///
    private(set) lazy var webView: WKWebView = {
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = Self.customUserAgent
        webView.translatesAutoresizingMaskIntoConstraints = false
        return webView
    }()

    private var hasPrewarmedConnection = false

    private init() { }

    // MARK: - Prewarming

    ///
    /// Eagerly create the web view (spinning up the web content process) and warm the TLS/HTTP
    /// connection to the server, so the first editor asset requests reuse an open connection and
    /// any already-cached bundles.
    ///
    /// This deliberately does **not** call `textOpenFile` for any note — that would open a
    /// server-side edit session/lock and have side effects. It only warms transport and the
    /// rendering process. Idempotent and cheap to call repeatedly.
    ///
    func prewarm() {
        // Touching the lazy property forces creation of the web content process.
        _ = webView

        guard hasPrewarmedConnection == false else {
            return
        }

        guard let url = URL(string: KeychainHelper.server), url.scheme != nil else {
            return
        }

        hasPrewarmedConnection = true

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 10

        // Warms the TLS/HTTP2 connection to the host; the response itself is ignored.
        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - Logout

    ///
    /// Remove all cached web data (bundles, cookies, service workers, localStorage) so nothing
    /// leaks to the next account. Call on logout.
    ///
    func clearData(completion: (() -> Void)? = nil) {
        let dataStore = configuration.websiteDataStore
        let types = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: types) { records in
            dataStore.removeData(ofTypes: types, for: records) {
                completion?()
            }
        }
    }

    // MARK: - User Agent

    ///
    /// Spoofed user agent so the server serves the mobile Text editor variant.
    ///
    static var customUserAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let userAgent = "Mozilla/5.0 (iOS) NextcloudNotes/ " + version

        if UIDevice.current.userInterfaceIdiom == .phone {
            // NOTE: Hardcoded (May 2022)
            // 605.1.15 = WebKit build version
            // 15E148 = frozen iOS build number according to: https://chromestatus.com/feature/4558585463832576
            return userAgent + " " + "AppleWebKit/605.1.15 Mobile/15E148"
        } else {
            return userAgent
        }
    }
}
