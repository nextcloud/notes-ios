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
            guard let layoutManager = layoutManager, let textView = textView else {
                return
            }

            let textStorage = layoutManager.textStorage
            var tappedLocation = sender.location(in: textView)
            let containerInset = textView.textContainerInset
            print("Tapped at \(tappedLocation) for text view frame \(textView.frame) with insets \(containerInset)")
            tappedLocation.x -= containerInset.left
            tappedLocation.y -= containerInset.top
            if !textView.bounds.contains(tappedLocation) {
                return
            }
            print("Tapped at adjusted location \(tappedLocation)")
            print("Tapped in text view")

            let glyphIndex = layoutManager.glyphIndex(for: tappedLocation, in: textView.textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            let range = NSRange(location: charIndex, length: 1)

            textStorage?.enumerateAttribute(.checkBox, in: range, options: .longestEffectiveRangeNotRequired) { value, _, _ in
                guard let value = value else {
                    return
                }

                var checked = false
                if let value = value as? Bool {
                    checked = value
                }

                print("Tapped in \(checked ? "Checked" : "Unchecked") box")
                if let input = textStorage?.string {
                    let character = input[input.index(input.startIndex, offsetBy: charIndex)]
                    switch character {
                    case " ":
                        print("Found space character")
                        textStorage?.replaceCharacters(in: NSRange(location: charIndex - 1, length: 3), with: "[x]")
                    case "x", "X":
                        print("Found x")
                        textStorage?.replaceCharacters(in: NSRange(location: charIndex - 1, length: 3), with: "[ ]")
                    case "[":
                        print("Found opening bracket")
                        if checked {
                            textStorage?.replaceCharacters(in: NSRange(location: charIndex, length: 3), with: "[ ]")
                        } else {
                            textStorage?.replaceCharacters(in: NSRange(location: charIndex, length: 3), with: "[x]")
                        }
                    case "]":
                        print("Found closing bracket")
                        if checked {
                            textStorage?.replaceCharacters(in: NSRange(location: charIndex - 2, length: 3), with: "[ ]")
                        } else {
                            textStorage?.replaceCharacters(in: NSRange(location: charIndex - 2, length: 3), with: "[x]")
                        }
                    default:
                        print("Found unrelated character")
                    }
                }
            }
        }
    }

}

extension CheckBoxTapHandler: UIGestureRecognizerDelegate {

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer != tapGestureRecognizer {
            return true
        }
        guard let layoutManager = layoutManager, let textView = textView else {
            return true
        }
        var result = true
        let textStorage = layoutManager.textStorage
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

        textStorage?.enumerateAttribute(.checkBox, in: range, options: .longestEffectiveRangeNotRequired) { value, _, stop in
            if value == nil {
                return
            }
            if let input = textStorage?.string {
                let character = input[input.index(input.startIndex, offsetBy: charIndex)]
                if "[ xX]".contains(character) {
                    result = false // Don't enter edit mode if checkbox is tapped
                    stop.pointee = true
                }
            }
        }
        return result
    }

}
