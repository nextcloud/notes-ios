//
//  FileExtensionTableViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 12/22/21.
//  Copyright © 2021 Peter Hedlund. All rights reserved.
//

import UIKit

class FileExtensionTableViewController: UITableViewController {

    @IBOutlet var plainTextCell: UITableViewCell!
    @IBOutlet var markdownCell: UITableViewCell!

    private var currentExtension: FileSuffix = .txt

    override func viewDidLoad() {
        super.viewDidLoad()
        currentExtension = KeychainHelper.fileSuffix
        plainTextCell.accessoryType = currentExtension == .txt ? .checkmark : .none
        markdownCell.accessoryType = currentExtension == .md ? .checkmark : .none
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            plainTextCell.accessoryType = .checkmark
            markdownCell.accessoryType = .none
            if currentExtension != .txt {
                KeychainHelper.fileSuffix = .txt
                NoteSessionManager.shared.updateSettings { [weak self] in
                    self?.currentExtension = .txt
                }
            }
        case 1:
            plainTextCell.accessoryType = .none
            markdownCell.accessoryType = .checkmark
            if currentExtension != .md {
                KeychainHelper.fileSuffix = .md
                NoteSessionManager.shared.updateSettings { [weak self] in
                    self?.currentExtension = .md
                }
            }
        default:
            break
        }
    }

}
