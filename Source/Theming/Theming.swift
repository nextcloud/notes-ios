//
//  Theming.swift
//  iOCNotes
//
//  Created by Milen on 16.08.24.
//  Copyright © 2024 Peter Hedlund. All rights reserved.
//

import Foundation
import UIKit

protocol Theming {
    func applyTheme(brandColor: UIColor, brandTextColor: UIColor)
}

extension Theming where Self: UIViewController {}
