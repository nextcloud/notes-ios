//
//  AppDelegate.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 2/12/19.
//  Copyright © 2020 Peter Hedlund. All rights reserved.
//

import UIKit
import BackgroundTasks
import NextcloudKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var notesTableViewController: NotesTableViewController?
    var networkReachability: NKCommon.TypeReachability?
    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    private let operationQueue = OperationQueue()
    private var updateFrcDelegateNeeded = true
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let appName = "NextcloudNotes" // Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let userAgent = "Mozilla/5.0 (iOS) \(appName)/\(appVersion ?? "")"

        NextcloudKit.shared.setup(delegate: NCNetworking.shared)
        NextcloudKit.shared.setup(userAgent: userAgent)

        _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.peterandlinda.iOCNotes.Sync", using: nil) { task in
            if let task = task as? BGAppRefreshTask {
                print(task.description)
                self.handleAppSync(task: task)
            }
        }

        window?.tintColor = .ph_iconColor

        if #available(iOS 15, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
        UINavigationBar.appearance().barTintColor = .ph_popoverButtonColor
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().tintColor = .ph_iconColor

        UIToolbar.appearance().barTintColor = .ph_popoverButtonColor
        UIToolbar.appearance().tintColor = .ph_iconColor

        UIBarButtonItem.appearance().tintColor = .ph_textColor

        UITableViewCell.appearance().backgroundColor = .ph_cellBackgroundColor

        let scrollViewArray = [
            NotesTableViewController.self,
            CategoryTableViewController.self,
            EditorViewController.self,
            PreviewViewController.self,
            SettingsTableViewController.self,
            LoginViewController.self
        ]
        UIScrollView.appearance(whenContainedInInstancesOf: scrollViewArray).backgroundColor = .ph_cellBackgroundColor

        UISwitch.appearance().onTintColor = .ph_switchTintColor
        UISwitch.appearance().tintColor = .ph_switchTintColor

        UILabel.appearance().themeColor = .ph_textColor
        UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).themeColor = .ph_readTextColor

        UITextField.appearance().textColor = .ph_textColor

        UITextView.appearance().tintColor = .ph_selectedTextColor
        
//        if let splitViewController = self.window?.rootViewController as? UISplitViewController {
//            if let firstNavigationController = splitViewController.viewControllers.first as? UINavigationController {
//                notesTableViewController = firstNavigationController.topViewController as? NotesTableViewController
//                
//            }
//            if let secondNavigationController = splitViewController.viewControllers.last as? UINavigationController {
//                if #available(iOS 14.0, *) {
//                    //
//                } else {
//                    secondNavigationController.topViewController?.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
//                }
//            }
//        }

        // Create the SwiftUI view that provides the window contents.
               let contentView = Home()

               // Use a UIHostingController as the window root view controller.
               let window = UIWindow(frame: UIScreen.main.bounds)
               window.rootViewController = UIHostingController(rootView: contentView)
               self.window = window
               window.makeKeyAndVisible()

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        notesTableViewController?.updateFrcDelegate(update: .disable)
        updateFrcDelegateNeeded = true
        scheduleAppSync()
    }

    func applicationWillResignActive(_ application: UIApplication) {

        if !KeychainHelper.server.isEmpty,
            let server = URL(string: KeychainHelper.server),
            let scheme = server.scheme, let host = server.host,
            let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nextcloud.apps") {
            let account = NKShareAccounts.DataAccounts(withUrl: scheme + "://" + host, user: KeychainHelper.username)
            _ = NKShareAccounts().putShareAccounts(at: dirGroupApps, app: "nextcloudnotes", dataAccounts: [account])
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NCService.shared.startRequestServicesServer { }
        updateFrcDelegateIfNeeded()
    }
    
    private func updateFrcDelegateIfNeeded() {
        guard updateFrcDelegateNeeded else {
            return
        }
        
        updateFrcDelegateNeeded = false
        notesTableViewController?.updateFrcDelegate(update: .enable(withFetch: KeychainHelper.didSyncInBackground))
        KeychainHelper.didSyncInBackground = false
    }
        
    func scheduleAppSync() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        let request = BGAppRefreshTaskRequest(identifier: "com.peterandlinda.iOCNotes.Sync")
       request.earliestBeginDate = Date(timeIntervalSinceNow: 600)
       do {
          try BGTaskScheduler.shared.submit(request)
       } catch {
          print("Could not schedule app refresh: \(error)")
       }
    }
    
    func handleAppSync(task: BGAppRefreshTask) {
        // Schedule a new refresh task
        scheduleAppSync()
        
        // Create an operation that performs the main part of the background task
        let operation = SyncOperation()
        
        // Provide an expiration handler for the background task
        // that cancels the operation
        task.expirationHandler = {
           operation.cancel()
        }

        // Inform the system that the background task is complete
        // when the operation completes
        operation.completionBlock = {
            KeychainHelper.didSyncInBackground = true
            task.setTaskCompleted(success: !operation.isCancelled)
        }

        // Start the operation
        operationQueue.addOperation(operation)
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if let scheme = url.scheme, scheme == "nextcloudnotes" {
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = urlComponents?.queryItems,
                let item = queryItems.first(where: { $0.name == "note" }),
                let content = item.value {
                // Make sure we connect the delegate up, as this is called before the app is active
                updateFrcDelegateIfNeeded()
                self.notesTableViewController?.addNote(content: content)
            }
        } else if url.isFileURL {
            do {
                _ = url.startAccessingSecurityScopedResource()
                let content = try String(contentsOf: url, encoding: .utf8)
                NoteSessionManager.shared.add(content: content, category: "")
                try FileManager.default.removeItem(at: url)
                url.stopAccessingSecurityScopedResource()
            } catch {
                print(error.localizedDescription)
            }
        }
        return true
    }
}

extension UIApplication {
    
    class func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(base: selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    
}

