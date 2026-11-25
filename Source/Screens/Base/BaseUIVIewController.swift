// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

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
