//
//  LayoutManager.swift
//  
//
//  Created by Peter Hedlund on 12/29/21.
//

import Foundation
import UIKit

public class LayoutManager: NSLayoutManager { }

extension LayoutManager: NSLayoutManagerDelegate {
    public func layoutManager(_ layoutManager: NSLayoutManager, shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>, properties props: UnsafePointer<NSLayoutManager.GlyphProperty>, characterIndexes charIndexes: UnsafePointer<Int>, font aFont: UIFont, forGlyphRange glyphRange: NSRange) -> Int {

        guard let textStorage = textStorage else {
            layoutManager.setGlyphs(glyphs, properties: props, characterIndexes: charIndexes,
                                    font: aFont, forGlyphRange: glyphRange)
            return glyphRange.length
        }

        let firstCharIndex = charIndexes[0]
        let lastCharIndex = charIndexes[glyphRange.length - 1]
        let charactersRange = NSRange(location: firstCharIndex, length: lastCharIndex - firstCharIndex + 1)

        var unorderedListRanges = [NSRange]()
        var checkBoxOpenRanges = [NSRange]()
        var checkBoxCheckedRanges = [NSRange]()
        textStorage.enumerateAttribute(.listItemUnordered, in: charactersRange, options: []) { value, range, _ in
            if value != nil {
                unorderedListRanges.append(range)
            }
        }
        textStorage.enumerateAttribute(.checkBoxOpen, in: charactersRange, options: []) { value, range, _ in
            if value != nil {
                checkBoxOpenRanges.append(range)
            }
        }

        textStorage.enumerateAttribute(.checkBoxChecked, in: charactersRange, options: []) { value, range, _ in
            if value != nil {
                checkBoxCheckedRanges.append(range)
            }
        }

        let finalGlyphs = UnsafeMutablePointer<CGGlyph>(mutating: glyphs)
        let myCharacters: [UniChar] = [0x2022, 0x25A1, 0x2611] // 25A1 square 2611 checked
        var myGlyphs = [CGGlyph](repeating: 0, count: myCharacters.count)
        let canEncode = CTFontGetGlyphsForCharacters(aFont, myCharacters, &myGlyphs, myCharacters.count)
        if !canEncode {
            print("! Failed to get the glyphs for characters \(myCharacters).")
        }

        var modifiedGlyphProperties = [NSLayoutManager.GlyphProperty]()
        let glyphRangeLength = glyphRange.length
        for i in 0 ..< glyphRangeLength {
            var glyphProperties = props[i]
            let characterIndex = charIndexes[i]

            let filteredCheckboxRanges = checkBoxOpenRanges.filter { NSLocationInRange(characterIndex, $0) }
            if !filteredCheckboxRanges.isEmpty {
                if i < 2 {
                    glyphProperties.insert(.null)
                } else {
                    finalGlyphs[2] = myGlyphs[1]
                }
            }
            let filteredCheckBoxCheckedRanges = checkBoxCheckedRanges.filter { NSLocationInRange(characterIndex, $0) }
            if !filteredCheckBoxCheckedRanges.isEmpty {
                if i < 2 {
                    glyphProperties.insert(.null)
                } else {
                    finalGlyphs[2] = myGlyphs[2]
                }
            }
            let filteredReplacementRanges = unorderedListRanges.filter { NSLocationInRange(characterIndex, $0) }
            if !filteredReplacementRanges.isEmpty {
                finalGlyphs[0] = myGlyphs[0]
            }
            modifiedGlyphProperties.append(glyphProperties)
        }

        modifiedGlyphProperties.withUnsafeBufferPointer { modifiedGlyphPropertiesBufferPointer in
            guard let modifiedGlyphPropertiesPointer = modifiedGlyphPropertiesBufferPointer.baseAddress else {
                fatalError("Could not get base address of modifiedGlyphProperties")
            }

            layoutManager.setGlyphs(glyphs, properties: modifiedGlyphPropertiesPointer, characterIndexes: charIndexes, font: aFont, forGlyphRange: glyphRange)
        }

        return glyphRange.length
    }

}
