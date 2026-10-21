//
//  TapHandler.swift
//  
//
//  Created by Peter Hedlund on 12/30/21.
//

import UIKit

public class CheckBoxTapHandler: NSObject {

    public let tapGestureRecognizer: UITapGestureRecognizer

    public var layoutManager: NSLayoutManager?
    public var textView: UITextView?

    public override init() {
        tapGestureRecognizer = UITapGestureRecognizer()
        super.init()
        tapGestureRecognizer.addTarget(self, action: #selector(handleTap(sender:)))
        tapGestureRecognizer.delegate = self
    }

    @objc func handleTap(sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            guard let layoutManager = layoutManager, let textView = textView, let textStorage = layoutManager.textStorage, !textStorage.string.isEmpty else {
                return
            }

            var tappedLocation = sender.location(in: textView)
            let containerInset = textView.textContainerInset
            tappedLocation.x -= containerInset.left
            tappedLocation.y -= containerInset.top
            if !textView.bounds.contains(tappedLocation) {
                return
            }

            let glyphIndex = layoutManager.glyphIndex(for: tappedLocation, in: textView.textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let range = NSRange(location: charIndex, length: 1)

            var clearRanges = [NSRange]()
            var checkRanges = [NSRange]()

            textStorage.enumerateAttributes(in: range, options: .longestEffectiveRangeNotRequired) { attributes, range, _ in
                for attribute in attributes {
                    switch attribute.key {
                    case .checkBoxOpen:
                        checkRanges.append(range)
                    case .checkBoxChecked:
                        clearRanges.append(range)
                    default:
                        break
                    }
                }
            }

            for range in checkRanges {
                textStorage.replaceCharacters(in: NSRange(location: range.location - 2, length: 3), with: "[x]")
            }

            for range in clearRanges {
                textStorage.replaceCharacters(in: NSRange(location: range.location - 2, length: 3), with: "[ ]")
            }
        }
    }

}

extension CheckBoxTapHandler: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer != tapGestureRecognizer {
            return true
        }
        guard let layoutManager = layoutManager, let textView = textView, let textStorage = layoutManager.textStorage, !textStorage.string.isEmpty else {
            return true
        }
        var result = true
        var tappedLocation = gestureRecognizer.location(in: textView)
        let containerInset = textView.textContainerInset
        tappedLocation.x -= containerInset.left
        tappedLocation.y -= containerInset.top
        if !textView.bounds.contains(tappedLocation) {
            return true
        }

        let glyphIndex = layoutManager.glyphIndex(for: tappedLocation, in: textView.textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let range = NSRange(location: charIndex, length: 1)

        textStorage.enumerateAttribute(.checkBoxOpen, in: range, options: .longestEffectiveRangeNotRequired) { value, _, stop in
            if value == nil {
                return
            }
            if CheckBoxTapHandler.isCheckBoxCharacter(in: textStorage.string, at: charIndex) {
                result = false // Don't enter edit mode if checkbox is tapped
                stop.pointee = true
            }
        }
        textStorage.enumerateAttribute(.checkBoxChecked, in: range, options: .longestEffectiveRangeNotRequired) { value, _, stop in
            if value == nil {
                return
            }
            if CheckBoxTapHandler.isCheckBoxCharacter(in: textStorage.string, at: charIndex) {
                result = false // Don't enter edit mode if checkbox is tapped
                stop.pointee = true
            }
        }
        return result
    }


    /// Whether the character at a layout manager index (UTF-16 units) belongs to a checkbox such as `[ ]` or `[x]`.
    ///
    /// The index must not be used as a `Character` offset into the `String`: with emoji earlier in the note the two
    /// differ, which read the wrong character or crashed with "String index is out of bounds".
    static func isCheckBoxCharacter(in text: String, at utf16Index: Int) -> Bool {
        let string = text as NSString
        guard utf16Index >= 0, utf16Index < string.length else {
            return false
        }
        return "[ xX]".utf16.contains(string.character(at: utf16Index))
    }
}
