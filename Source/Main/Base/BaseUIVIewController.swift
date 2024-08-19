//
//  BaseUIVIewController.swift
//  iOCNotes
//
//  Created by Milen on 16.08.24.
//  Copyright © 2024 Peter Hedlund. All rights reserved.
//

import Foundation
import UIKit

class BaseUIViewController: UIViewController, Theming {
    override func viewDidLoad() {
        applyTheme(brandColor: NCBrandColor.shared.customer, brandTextColor: NCBrandColor.shared.brandText)
    }

    func applyTheme(brandColor: UIColor, brandTextColor: UIColor) {}
}

class BaseUITableViewController: UITableViewController, Theming {
    override func viewDidLoad() {
        applyTheme(brandColor: NCBrandColor.shared.customer, brandTextColor: NCBrandColor.shared.brandText)
    }

    func applyTheme(brandColor: UIColor, brandTextColor: UIColor) {}
}
