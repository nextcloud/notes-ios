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
import SwiftUI

class SettingsTableViewController: UITableViewController {

    @IBOutlet var accountInformation: UITableViewCell!
    @IBOutlet var clientVersion: UITableViewCell!
    @IBOutlet var serverVersion: UITableViewCell!
    
    @IBOutlet var syncOnStartSwitch: UISwitch!
    @IBOutlet weak var offlineModeSwitch: UISwitch!
    @IBOutlet var extensionLabel: UILabel!
    @IBOutlet var folderLabel: UILabel!
    @IBOutlet weak var internalEditorSwitch: UISwitch!
    @IBOutlet weak var privacyButton: UITableViewCell!
    @IBOutlet weak var soureCodeButton: UITableViewCell!
    
    private var shareAccounts: [NKShareAccounts.DataAccounts]?

    override func viewDidLoad() {
        super.viewDidLoad()

        syncOnStartSwitch.onTintColor = NCBrandColor.shared.brandColor
        offlineModeSwitch.onTintColor = NCBrandColor.shared.brandColor
        internalEditorSwitch.onTintColor = NCBrandColor.shared.brandColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.syncOnStartSwitch.isOn = KeychainHelper.syncOnStart
        offlineModeSwitch.isOn = KeychainHelper.offlineMode
        extensionLabel.text = KeychainHelper.fileSuffix.description
        folderLabel.text = KeychainHelper.notesPath
        internalEditorSwitch.isOn = KeychainHelper.internalEditor
        tableView.reloadData()
        tableView.isScrollEnabled = false
        tableView.isScrollEnabled = true

        // Set account information
        var accountInformationContentConfiguration = UIListContentConfiguration.subtitleCell()
        accountInformationContentConfiguration.text = KeychainHelper.username
        accountInformationContentConfiguration.secondaryText = KeychainHelper.server
        accountInformation.contentConfiguration = accountInformationContentConfiguration

        // Set client version
        var clientVersionContentConfiguration = UIListContentConfiguration.valueCell()
        clientVersionContentConfiguration.text = NSLocalizedString("Client Version", comment: "Label")
        clientVersionContentConfiguration.secondaryText = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "nil") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "nil"))"
        clientVersion.contentConfiguration = clientVersionContentConfiguration

        // Set server version
        var serverVersionContentConfiguration = UIListContentConfiguration.valueCell()
        serverVersionContentConfiguration.text = NSLocalizedString("Server Version", comment: "Label")
        serverVersionContentConfiguration.secondaryText = KeychainHelper.productVersion
        serverVersion.contentConfiguration = serverVersionContentConfiguration
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            break
        case 1:
            break
        case 2:
            if indexPath.row == 0 {
                showNotesFolderAlert()
            }
        case 3:
            switch indexPath.row {
                case 2:
                    openPrivacy()
                case 3:
                    openSourceCode()
                default:
                    break
            }
        default:
            break
        }
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let vc = segue.destination
        vc.navigationItem.rightBarButtonItem = nil

        if segue.identifier == "showCertificate" {
            let certificateViewController = segue.destination as? CertificateViewController
            let host = URL(string: KeychainHelper.server)?.host
            certificateViewController?.host = host ?? ""
        }
    }

    @IBAction func syncOnStartChanged(_ sender: Any) {
        KeychainHelper.syncOnStart = syncOnStartSwitch.isOn
    }

    @IBAction func offlineModeChanged(_ sender: Any) {
        KeychainHelper.offlineMode = offlineModeSwitch.isOn
    }

    @IBAction func internalEditorChanged(_ sender: Any) {
        KeychainHelper.internalEditor = internalEditorSwitch.isOn
    }

    @IBAction func logout(_ sender: Any) {
        let alert = UIAlertController(title: NSLocalizedString("Logout", comment: "Alert title"), message: NSLocalizedString("Are you sure you want to log out?", comment: "Alert message"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Button label"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Log Out", comment: "Button label"), style: .destructive) { _ in
            Store.shared.removeAccount()
        })
        present(alert, animated: true)
    }
    
    private func openPrivacy() {
        if let url = URL(string: NCBrandOptions.shared.privacyUrl) {
            UIApplication.shared.open(url)
        }
    }

    private func openSourceCode() {
        if let url = URL(string: NCBrandOptions.shared.sourceCodeUrl) {
            UIApplication.shared.open(url)
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
}

extension SettingsTableViewController: MFMailComposeViewControllerDelegate {

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
}

struct SettingsTableViewControllerRepresentable: UIViewControllerRepresentable {
    class Coordinator: NSObject {
        var parent: SettingsTableViewControllerRepresentable
        weak var viewController: SettingsTableViewController?

        init(_ parent: SettingsTableViewControllerRepresentable) {
            self.parent = parent
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let storyboard = UIStoryboard(name: "Settings", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "SettingsTableViewController") as? SettingsTableViewController
        context.coordinator.viewController = viewController

        return viewController ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update the UI of the view controller if needed
    }
}
