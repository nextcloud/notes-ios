//
//  LayoutManager.swift
//  
//
//  Created by Peter Hedlund on 12/29/21.
//

import Foundation
import UIKit

public class LayoutManager: NSLayoutManager {

    public override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        guard let textStorage = textStorage else {
            return
        }

        let range = self.characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

        textStorage.enumerateAttribute(.checkBox, in: range, options: .longestEffectiveRangeNotRequired) { value, range, stop in
            guard let value = value else {
                super.drawGlyphs(forGlyphRange: range, at: origin)
                return
            }

            var checked = false
            if let value = value as? Bool {
                checked = value
            }

            let glyphRange = glyphRange(forCharacterRange: range, actualCharacterRange: nil)

            if let color = currentColorFor(range: range),
                let textContainer = textContainer(forGlyphAt: glyphRange.location, effectiveRange: nil),
                let context = UIGraphicsGetCurrentContext(),
                let font = currentFontFor(range: range) {

                context.saveGState()
                context.translateBy(x: origin.x, y: origin.y)
                color.setStroke()

                var rect = boundingRect(forGlyphRange: glyphRange, in: textContainer)
                rect = rect.offsetBy(dx: 0, dy: 2)
                rect.size.height = max(rect.size.height, font.lineHeight) - 3
                rect.size.width = rect.size.height
                if #available(iOS 13.0, *) {
                    if checked {
                        UIImage(systemName: "checkmark.square")?
                            .withTintColor(color, renderingMode: .alwaysOriginal)
                            .draw(in: rect)
                    } else {
                        UIImage(systemName: "square")?
                            .withTintColor(color, renderingMode: .alwaysOriginal)
                            .draw(in: rect)
                    }
                } else {
                    // Fallback on earlier versions
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
                    path.stroke()
                    if checked {
                        let checkmark = UIBezierPath()
                        let size = rect.size
                        checkmark.move(to: CGPoint(x: rect.origin.x + 22/100 * size.width, y: rect.origin.y + 52/100 * size.height))
                        checkmark.addLine(to: CGPoint(x: rect.origin.x + 38/100 * size.width, y: rect.origin.y + 68/100 * size.height))
                        checkmark.addLine(to: CGPoint(x: rect.origin.x + 76/100 * size.width, y: rect.origin.y + 30/100 * size.height))
                        checkmark.lineWidth = 2.0
                        checkmark.stroke()
                    }
                }
                context.restoreGState()
            } else {
                super.drawGlyphs(forGlyphRange: range, at: origin)
            }
        }

    }

    func currentColorFor(range: NSRange) -> UIColor? {
        guard let textStorage = textStorage else { return nil }
        guard let color = textStorage.attributes(at: range.location, effectiveRange: nil)[NSAttributedString.Key.foregroundColor] as? UIColor else { return nil }
        return color
    }

    func currentFontFor(range: NSRange) -> UIFont? {
        guard let textStorage = textStorage else { return nil }
        guard let font = textStorage.attributes(at: range.location, effectiveRange: nil)[NSAttributedString.Key.font] as? UIFont else { return nil }
        return font
    }

}
