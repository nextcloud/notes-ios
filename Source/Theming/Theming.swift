// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

protocol Theming {
    func applyTheme(brandColor: UIColor, brandTextColor: UIColor)
}

extension Theming where Self: UIViewController {}
