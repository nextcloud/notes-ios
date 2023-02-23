//
//  SettingsTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/19/19.
//  Copyright © 2019 Peter Hedlund. All rights reserved.
//

import UIKit
import MessageUI
import NextcloudKit

class SettingsTableViewController: UITableViewController {

    @IBOutlet var serverTextField: UITextField!
    @IBOutlet var syncOnStartSwitch: UISwitch!
    @IBOutlet weak var offlineModeSwitch: UISwitch!
    @IBOutlet var extensionLabel: UILabel!
    @IBOutlet var folderLabel: UILabel!

    private var shareAccounts: [NKShareAccounts.DataAccounts]?
    private var user: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        /*
        if let dirGroupApps = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nextcloud.apps") {
            if let shareAccounts = NKShareAccounts().getShareAccount(at: dirGroupApps, application: UIApplication.shared) {
                var accountTemp = [NKShareAccounts.DataAccounts]()
                for shareAccount in shareAccounts {
                    accountTemp.append(shareAccount)
                }
                if !accountTemp.isEmpty {
                    self.shareAccounts = accountTemp
                    let image = UIImage(systemName: "person.badge.plus")
                    let navigationItemTalk = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(openShareAccountsViewController))
                    self.navigationItem.leftBarButtonItem = navigationItemTalk
                }
            }
        }
        */
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.serverTextField.text = KeychainHelper.server
        self.user = nil
        self.syncOnStartSwitch.isOn = KeychainHelper.syncOnStart
        offlineModeSwitch.isOn = KeychainHelper.offlineMode
        extensionLabel.text = KeychainHelper.fileSuffix.description
        folderLabel.text = KeychainHelper.notesPath
        tableView.reloadData()
        tableView.isScrollEnabled = false
        tableView.isScrollEnabled = true
    }
    
    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return updateFooter()
        } else {
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            break
        case 1:
            break
        case 2:
            if indexPath.row == 1 {
                showNotesFolderAlert()
            }
        default:
            break
        }
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination
        vc.navigationItem.rightBarButtonItem = nil
        if segue.identifier == "loginSegue",
           let loginWebViewController = segue.destination as? LoginViewController,
           let serverAddress = serverTextField.text, !serverAddress.isEmpty {
            KeychainHelper.server = ""
            KeychainHelper.username = ""
            KeychainHelper.password = ""
            loginWebViewController.serverAddress = serverAddress
            loginWebViewController.user = self.user
        } else if segue.identifier == "showCertificate" {
            let certificateViewController = segue.destination as? CertificateViewController
            let host = URL(string: KeychainHelper.server)?.host
            certificateViewController?.host = host ?? ""
        }
    }

    @IBAction func onLogin(_ sender: Any) {
        ServerStatus.shared.reset()
        Task {
            do {
                if let serverAddress = serverTextField.text, !serverAddress.isEmpty {
                    KeychainHelper.server = ""
                    KeychainHelper.username = ""
                    KeychainHelper.password = ""
                    var address = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                    if !address.contains("://"),
                       !address.hasPrefix("http") {
                        address = "https://\(address)"
                    }
                    KeychainHelper.server = address
                    try await ServerStatus.shared.check()
                    KeychainHelper.allowUntrustedCertificate = false
                    performSegue(withIdentifier: "loginSegue", sender: self)
                }
            } catch (let error as NSError) {
                print(error.localizedDescription)
                if error.code == NSURLErrorServerCertificateUntrusted {
                    let alertController = UIAlertController(title: NSLocalizedString("The certificate for this server is invalid", comment: ""),
                                                            message: NSLocalizedString("Do you want to connect to the server anyway?", comment: ""),
                                                            preferredStyle: .alert)

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .default, handler: { [weak self] _ in
                        if let host = URL(string: KeychainHelper.server)?.host {
                            ServerStatus.shared.writeCertificate(host: host)
                            KeychainHelper.allowUntrustedCertificate = true
                            self?.performSegue(withIdentifier: "loginSegue", sender: self)
                        }
                    }))

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("No", comment: ""), style: .default, handler: { _ in
                        KeychainHelper.allowUntrustedCertificate = false
                    }))

                    alertController.addAction(UIAlertAction(title: NSLocalizedString("View Certificate", comment: ""), style: .default, handler: { [weak self] _ in
                        self?.performSegue(withIdentifier: "showCertificate", sender: self)
                    }))
                    self.present(alertController, animated: true)
                } else {
                    let alertController = UIAlertController(title: NSLocalizedString("Connection error", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { _ in }))
                    self.present(alertController, animated: true, completion: { })
                }
            }
        }
    }

    @IBAction func syncOnStartChanged(_ sender: Any) {
        KeychainHelper.syncOnStart = syncOnStartSwitch.isOn
    }
    
    @IBAction func offlineModeChanged(_ sender: Any) {
        KeychainHelper.offlineMode = offlineModeSwitch.isOn
    }

    @IBAction func onDone(_ sender: Any) {
        dismiss(animated: true) {
            if let presentationController = self.presentationController {
                presentationController.delegate?.presentationControllerDidDismiss?(presentationController)
            }
        }
    }

    private func showNotesFolderAlert() {
        var nameTextField: UITextField?
        let folderPath = KeychainHelper.notesPath
        let alertController = UIAlertController(title: NSLocalizedString("Notes Folder", comment: "Title of alert to change notes folder"),
                                                message: NSLocalizedString("Enter a name for the folder where notes should be saved on the server", comment: "Message of alert to change notes folder"),
                                                preferredStyle: .alert)
        alertController.addTextField { textField in
            nameTextField = textField
            textField.text = folderPath
            textField.keyboardType = .default
        }
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Caption of Cancel button"), style: .cancel, handler: nil)
        let renameAction = UIAlertAction(title: NSLocalizedString("Save", comment: "Caption of Save button"), style: .default) { _ in
            guard let newName = nameTextField?.text,
                !newName.isEmpty,
                newName != folderPath else {
                    return
            }
            KeychainHelper.notesPath = newName
            NoteSessionManager.shared.updateSettings { [weak self] in
                self?.folderLabel.text = KeychainHelper.notesPath
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(renameAction)
        present(alertController, animated: true, completion: nil)
    }

    private func updateFooter() -> String {
        guard !KeychainHelper.productName.isEmpty,
            !KeychainHelper.productVersion.isEmpty,
            !KeychainHelper.server.isEmpty
            else {
            return NSLocalizedString("Not logged in", comment: "Message about not being logged in")
        }
        let notesVersion = KeychainHelper.notesVersion.isEmpty ? "" : "\(KeychainHelper.notesVersion) "
        let format = NSLocalizedString("Using Notes %@on %@ %@.", comment:"Message with Notes version, product name and version")
        return String.localizedStringWithFormat(format, notesVersion, KeychainHelper.productName, KeychainHelper.productVersion)
    }

}

extension SettingsTableViewController: MFMailComposeViewControllerDelegate {

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
}

extension SettingsTableViewController: NCShareAccountsDelegate {

    // MARK: - Talk accounts View Controller

    @objc func openShareAccountsViewController() {

        if let shareAccounts = self.shareAccounts, let vc = UIStoryboard(name: "NCShareAccounts", bundle: nil).instantiateInitialViewController() as? NCShareAccounts {

            vc.accounts = shareAccounts
            vc.enableTimerProgress = false
            vc.dismissDidEnterBackground = false
            vc.delegate = self

            let screenHeighMax = UIScreen.main.bounds.height - (UIScreen.main.bounds.height/5)
            let numberCell = shareAccounts.count
            let height = min(CGFloat(numberCell * Int(vc.heightCell) + 45), screenHeighMax)

            let popup = NCPopupViewController(contentController: vc, popupWidth: 300, popupHeight: height+20)

            self.present(popup, animated: true)
        }
    }

    func selected(url: String, user: String) {
        serverTextField.text = url
        self.user = user
    }
}
