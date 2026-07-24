// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Julius Knorr
// SPDX-License-Identifier: GPL-3.0-or-later

//
//  SceneDelegate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/1/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import SwiftUI
import UIKit

@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else {
            return
        }

        windowScene.title = "NextcloudNotes"

        let contentView = ContentView()
            .environment(Store.shared)

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = .ph_iconColor
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()

        for context in connectionOptions.urlContexts {
            _ = AppDelegate.shared.handleOpen(url: context.url)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppDelegate.shared.handleDidBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        AppDelegate.shared.handleWillResignActive()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AppDelegate.shared.handleDidEnterBackground()
    }

    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        for context in urlContexts {
            _ = AppDelegate.shared.handleOpen(url: context.url)
        }
    }

}
