//
//  Style.swift
//  Notepad
//
//  Created by Rudd Fawcett on 10/14/16.
//  Copyright © 2016 Rudd Fawcett. All rights reserved.
//

import Foundation

public struct Style {
    var regex: NSRegularExpression!
    public var priority: Int
    public var attributes: [NSAttributedString.Key: Any] = [:]

    public init(element: Element, priority: Int, attributes: [NSAttributedString.Key: Any]) {
        self.regex = element.toRegex()
        self.priority = priority
        self.attributes = attributes
    }

    public init(regex: NSRegularExpression, priority: Int, attributes: [NSAttributedString.Key: Any]) {
        self.priority = priority
        self.regex = regex
        self.attributes = attributes
    }

    public init() {
        self.priority = Int.max
        self.regex = Element.unknown.toRegex()
    }
}
