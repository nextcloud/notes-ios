//
//  BaseUIVIewController.swift
//  iOCNotes
//
//  Created by Milen Pivchev on 16.08.24.
//  Copyright © 2024 Milen Pivchev. All rights reserved.
//

import Foundation
import UIKit

class BaseUIViewController: UIViewController, Theming {
    override func viewDidLoad() {
        applyTheme(brandColor: NCBrandColor.shared.brandColor, brandTextColor: NCBrandColor.shared.brandTextColor)
    }

    func applyTheme(brandColor: UIColor, brandTextColor: UIColor) {}
}

class BaseUITableViewController: UITableViewController, Theming {
    override func viewDidLoad() {
        applyTheme(brandColor: NCBrandColor.shared.brandColor, brandTextColor: NCBrandColor.shared.brandTextColor)
    }

    func applyTheme(brandColor: UIColor, brandTextColor: UIColor) {}
}
