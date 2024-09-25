//
//  CertificateViewController.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 10/24/22.
//  Copyright © 2022 Peter Hedlund. All rights reserved.
//

import UIKit

class CertificateViewController: UIViewController {

    @IBOutlet var textView: UITextView!
    var host = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.contentInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        textView.text = ServerStatus.shared.certificateText(host)
    }

}
