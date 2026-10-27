// SPDX-FileCopyrightText: 2020 Peter Hedlund
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import BackgroundTasks
import NextcloudKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var store = Store.shared

    ///
    /// Updated by being the `NextcloudKitDelegate`.
    ///
    var networkReachability: NKTypeReachability?

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    private var pendingNoteToOpen: Note?

    /// When hosting tests, the app must not sync or touch the real store alongside them.
    static let isRunningTests: Bool = {
        let environment = ProcessInfo.processInfo.environment
        return environment["NOTES_UNDER_TEST"] == "1" || environment["XCTestConfigurationFilePath"] != nil
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NextcloudKit.shared.setup(delegate: self)

        guard !AppDelegate.isRunningTests else { return true }

        // Any install <= 35.0.0 has a bug where notes are not fully synced, as `eTag` and `lastModified` were not reset upon log out.
        // Reset once so the first sync fetches everything.
        if !KeychainHelper.didResetSyncValidators {
            KeychainHelper.eTag = ""
            KeychainHelper.lastModified = 0
            KeychainHelper.didResetSyncValidators = true
        }

        for account in store.accounts {
            NextcloudKit.shared.appendSession(
                account: account.id,
                urlBase: account.baseURL,
                user: account.userId,
                userId: account.userId,
                password: account.password,
                userAgent: userAgent,
                groupIdentifier: NCBrandOptions.shared.capabilitiesGroup
            )
        }

        _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.peterandlinda.iOCNotes.Sync", using: nil) { task in
            if let task = task as? BGAppRefreshTask {
                print(task.description)
                self.handleAppSync(task: task)
            }
        }

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
            CategoryTableViewController.self,
            EditorViewController.self,
            PreviewViewController.self,
        ]
        UIScrollView.appearance(whenContainedInInstancesOf: scrollViewArray).backgroundColor = .ph_cellBackgroundColor

        UISwitch.appearance().onTintColor = .ph_switchTintColor
        UISwitch.appearance().tintColor = .ph_switchTintColor

        UILabel.appearance().themeColor = .ph_textColor
        UILabel.appearance(whenContainedInInstancesOf: [UITextField.self]).themeColor = .ph_readTextColor

        UITextField.appearance().textColor = .ph_textColor
        
        UITextView.appearance().tintColor = .ph_selectedTextColor

        return true
    }

    ///
    /// Scene lifecycle is adopted via ``SceneDelegate``; these handlers hold the shared behaviour it forwards.
    ///
    func handleDidEnterBackground() {
        scheduleAppSync()
    }

    func handleWillResignActive() {
        if !KeychainHelper.server.isEmpty,
            let server = URL(string: KeychainHelper.server),
            let scheme = server.scheme, let host = server.host,
            let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nextcloud.apps") {
            let account = NKShareAccounts.DataAccounts(withUrl: scheme + "://" + host, user: KeychainHelper.username)
            _ = NKShareAccounts().putShareAccounts(at: dirGroupApps, app: "nextcloudnotes", dataAccounts: [account])
        }
    }
    
    func handleDidBecomeActive() {
        store.synchronize()
        DispatchQueue.main.async {
            self.openPendingNoteIfNeeded()
        }
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

        let syncTask = Task {
            await NoteSessionManager.shared.sync()

            task.setTaskCompleted(success: !Task.isCancelled)
        }

        task.expirationHandler = {
            syncTask.cancel()
        }
    }
    
    @discardableResult
    func handleOpen(url: URL) -> Bool {
        if let scheme = url.scheme, scheme == "nextcloudnotes" {
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let queryItems = urlComponents?.queryItems,
                let item = queryItems.first(where: { $0.name == "note" }),
                let content = item.value {
                Task {
                    guard let note = await NoteSessionManager.shared.add(content: content, category: "") else { return }

                    self.openEditorWhenReady(for: note)
                }
            }
        } else if url.isFileURL {
            do {
                _ = url.startAccessingSecurityScopedResource()
                let content = try String(contentsOf: url, encoding: .utf8)
                Task {
                    await NoteSessionManager.shared.add(content: content, category: "")
                }
                try FileManager.default.removeItem(at: url)
                url.stopAccessingSecurityScopedResource()
            } catch {
                print(error.localizedDescription)
            }
        }
        return true
    }

    private func openEditorWhenReady(for note: Note) {
        guard NotesPresenter.openEditor(for: note, isNewNote: true) else {
            pendingNoteToOpen = note
            return
        }

        pendingNoteToOpen = nil
    }

    private func openPendingNoteIfNeeded() {
        guard let pendingNoteToOpen else { return }
        openEditorWhenReady(for: pendingNoteToOpen)
    }
}

// MARK: - NextcloudKitDelegate

extension AppDelegate: NextcloudKitDelegate {
    func authenticationChallenge(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        DispatchQueue.global().async {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(Foundation.URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(URLSession.AuthChallengeDisposition.useCredential, nil)
            }
        }
    }

    public func networkReachabilityObserver(_ typeReachability: NKTypeReachability) {
        self.networkReachability = typeReachability
    }
}
