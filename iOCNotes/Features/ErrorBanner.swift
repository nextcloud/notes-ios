// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftMessages
import UIKit

/// The text of a user-facing failure.
struct ErrorMessage: Equatable {
    let title: String
    let body: String
}

///
/// Decides whether an error is worth showing, so a server that keeps failing cannot cover the screen
/// with the same banner over and over.
///
struct ErrorBannerPolicy {
    /// The time during which an identical message is not shown again.
    var repeatInterval: TimeInterval = 20

    /// The last time each distinct message was shown.
    private var lastShown = [String: Date]()

    mutating func shouldShow(_ message: ErrorMessage, at date: Date) -> Bool {
        // Old entries are dropped first so the dictionary cannot grow with every distinct failure.
        lastShown = lastShown.filter { date.timeIntervalSince($0.value) < repeatInterval }

        let key = "\(message.title)\u{0}\(message.body)"

        if lastShown[key] != nil {
            return false
        }

        lastShown[key] = date
        return true
    }
}

///
/// The error banners of the app.
///
/// A banner hides itself after a few seconds and can also be dismissed with its button, which issues
/// reported as missing: a banner that stayed forever covered the note being edited and could not be
/// closed by tapping it.
///
enum ErrorBanner {
    /// How long a message stays visible.
    static let visibleDuration: TimeInterval = 8

    private static let lock = NSLock()
    private static var policy = ErrorBannerPolicy()

    /// Shows `message` unless the same message was shown moments ago.
    static func show(_ message: ErrorMessage) {
        lock.lock()
        let appears = policy.shouldShow(message, at: Date())
        lock.unlock()

        guard appears else { return }

        // Callers come from the main actor as well as from background tasks.
        Task { @MainActor in
            present(message)
        }
    }

    @MainActor
    private static func present(_ message: ErrorMessage) {
        #if !os(OSX)
        var config = SwiftMessages.defaultConfig
        config.duration = .seconds(seconds: visibleDuration)
        config.interactiveHide = true
        // A banner at the top covers the least of the text being typed on a phone.
        config.presentationStyle = .top
        config.dimMode = .none
        config.preferredStatusBarStyle = .default

        SwiftMessages.show(config: config) {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.error, iconStyle: .default)
            view.configureDropShadow()
            view.configureContent(title: message.title,
                                  body: message.body,
                                  iconImage: Icon.error.image,
                                  iconText: nil,
                                  buttonImage: nil,
                                  buttonTitle: NSLocalizedString("Dismiss", comment: "Dismisses an error message")) { _ in
                SwiftMessages.hide()
            }
            return view
        }
        #endif
    }
}
