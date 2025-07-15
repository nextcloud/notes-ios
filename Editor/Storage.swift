//
//  Storage.swift
//  Notepad
//
//  Created by Rudd Fawcett on 10/14/16.
//  Copyright © 2016 Rudd Fawcett. All rights reserved.
//

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

public class Storage: NSTextStorage {
    /// The Theme for the Notepad.
    public var theme: Theme? {
        didSet {
            let wholeRange = NSRange(location: 0, length: (self.string as NSString).length)

            self.beginEditing()
            self.applyStyles(wholeRange)
            self.edited(.editedAttributes, range: wholeRange, changeInLength: 0)
            self.endEditing()
        }
    }

    /// The underlying text storage implementation.
    var backingStore = NSTextStorage()

    override public var string: String {
        get {
            return backingStore.string
        }
    }

    override public init() {
        super.init()
    }
    
    override public init(attributedString attrStr: NSAttributedString) {
        super.init(attributedString:attrStr)
        backingStore.setAttributedString(attrStr)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required public init(itemProviderData data: Data, typeIdentifier: String) throws {
        fatalError("init(itemProviderData:typeIdentifier:) has not been implemented")
    }
    
    #if os(macOS)
    required public init?(pasteboardPropertyList propertyList: Any, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required public init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    #endif

    /// Finds attributes within a given range on a String.
    ///
    /// - parameter location: How far into the String to look.
    /// - parameter range:    The range to find attributes for.
    ///
    /// - returns: The attributes on a String within a certain range.
    override public func attributes(at location: Int, longestEffectiveRange range: NSRangePointer?, in rangeLimit: NSRange) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, longestEffectiveRange: range, in: rangeLimit)
    }

    /// Replaces edited characters within a certain range with a new string.
    ///
    /// - parameter range: The range to replace.
    /// - parameter str:   The new string to replace the range with.
    override public func replaceCharacters(in range: NSRange, with str: String) {
        self.beginEditing()
        backingStore.replaceCharacters(in: range, with: str)
        let len = (str as NSString).length
        let change = len - range.length
        self.edited([.editedCharacters, .editedAttributes], range: range, changeInLength: change)
        self.endEditing()
    }

    /// Sets the attributes on a string for a particular range.
    ///
    /// - parameter attrs: The attributes to add to the string for the range.
    /// - parameter range: The range in which to add attributes.
    public override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        self.beginEditing()
        backingStore.setAttributes(attrs, range: range)
        self.edited(.editedAttributes, range: range, changeInLength: 0)
        self.endEditing()
    }
    
    /// Retrieves the attributes of a string for a particular range.
    ///
    /// - parameter at: The location to begin with.
    /// - parameter range: The range in which to retrieve attributes.
    public override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key : Any] {
        return backingStore.attributes(at: location, effectiveRange: range)
    }
    
    /// Processes any edits made to the text in the editor.
    override public func processEditing() {
        let backingString = backingStore.string
        if let nsRange = backingString.range(from: NSMakeRange(NSMaxRange(editedRange), 0)) {
            let indexRange = backingString.lineRange(for: nsRange)
            let extendedRange: NSRange = NSUnionRange(editedRange, backingString.nsRange(from: indexRange))
            applyStyles(extendedRange)
        }
        super.processEditing()
    }

    /// Applies styles to a range on the backingString.
    ///
    /// - parameter range: The range in which to apply styles.
    func applyStyles(_ range: NSRange) {
        guard let theme = self.theme else {
            return
        }

        let backingString = backingStore.string
        backingStore.setAttributes(theme.body.attributes, range: range)

        // First, find all fenced code block ranges
        let codeBlockRanges = findCodeBlockRanges(in: backingString, range: range)

        let sortedStyles = theme.styles.sorted {
            $0.priority > $1.priority
        }

        for style in sortedStyles {
            style.regex.enumerateMatches(in: backingString, options: .withoutAnchoringBounds, range: range, using: { (match, flags, stop) in
                guard let match = match,
                      match.resultType == NSTextCheckingResult.CheckingType.regularExpression,
                      let pattern = match.regularExpression?.pattern else {
                          return
                      }
                
                // Skip all formatting styling if it's inside a code block
                if shouldExcludeFromCodeBlock(pattern) && isInsideCodeBlock(match.range(at: 0), codeBlockRanges: codeBlockRanges) {
                    return
                }
                
//                for i in 0..<match.numberOfRanges {
//                    print("\(pattern) matched at \(match.range(at: i))")
//                }
                if pattern == Element.checkBoxUnchecked.rawValue {
//                    for i in 0..<match.numberOfRanges {
//                        let startIndex = backingString.index(backingString.startIndex, offsetBy: match.range(at: i).location)
//                        let endIndex = backingString.index(backingString.startIndex, offsetBy: match.range(at: i).location + match.range(at: i).length)
//                        print("listItemUnordered matched at \(match.range(at: i)) chars '\(backingString[startIndex..<endIndex])'")
//                    }
                    backingStore.addAttribute(.checkBoxOpen, value: true, range: match.range(at: 3))
                    backingStore.addAttributes(style.attributes, range: match.range(at: 3))
                } else if pattern == Element.checkBoxChecked.rawValue {
                    backingStore.addAttribute(.checkBoxChecked, value: true, range: match.range(at: 3))
                    backingStore.addAttributes(style.attributes, range: match.range(at: 3))
                } else if pattern == Element.listItemUnordered.rawValue {
//                    for i in 0..<match.numberOfRanges {
//                        let startIndex = backingString.index(backingString.startIndex, offsetBy: match.range(at: i).location)
//                        let endIndex = backingString.index(backingString.startIndex, offsetBy: match.range(at: i).location + match.range(at: i).length)
//                        print("listItemUnordered matched at \(match.range(at: i)) chars '\(backingString[startIndex..<endIndex])'")
//                    }
                    let range = match.range(at: 2)
                    backingStore.addAttribute(.listItemUnordered, value: true, range: range)
                    backingStore.addAttributes(style.attributes, range: range)
                } else if pattern == Element.listItemOrdered.rawValue {
                    backingStore.addAttribute(.listItemOrdered, value: true, range: range)
                    backingStore.addAttributes(style.attributes, range: range)
                } else {
                    backingStore.addAttributes(style.attributes, range: match.range(at: 0))
                }
            })
        }
    }
    
    /// Finds all fenced code block ranges in the given text range.
    ///
    /// - parameter text: The text to search for code blocks.
    /// - parameter range: The range to search within.
    ///
    /// - returns: An array of NSRange objects representing the content inside code blocks.
    private func findCodeBlockRanges(in text: String, range: NSRange) -> [NSRange] {
        var codeBlockRanges: [NSRange] = []
        
        // Find fenced code blocks (```...```)
        let fencedCodeRegex = Element.codeFenced.toRegex()
        fencedCodeRegex.enumerateMatches(in: text, options: .withoutAnchoringBounds, range: range) { (match, flags, stop) in
            if let match = match, match.numberOfRanges >= 3 {
                // Group 2 contains the content inside the fenced code block
                let contentRange = match.range(at: 2)
                if contentRange.location != NSNotFound {
                    codeBlockRanges.append(contentRange)
                }
            }
        }
        
        return codeBlockRanges
    }
    
    /// Checks if a given pattern should be excluded from code blocks.
    ///
    /// - parameter pattern: The regex pattern to check.
    ///
    /// - returns: True if the pattern should not be applied inside code blocks.
    private func shouldExcludeFromCodeBlock(_ pattern: String) -> Bool {
        // Exclude all text formatting inside code blocks
        return pattern == Element.h1.rawValue || 
               pattern == Element.h2.rawValue || 
               pattern == Element.h3.rawValue ||
               pattern == Element.bold.rawValue ||
               pattern == Element.italic.rawValue ||
               pattern == Element.boldItalic.rawValue ||
               pattern == Element.strikeThrough.rawValue ||
               pattern == Element.codeInline.rawValue ||
               pattern == Element.url.rawValue ||
               pattern == Element.image.rawValue ||
               pattern == Element.listItemUnordered.rawValue ||
               pattern == Element.listItemOrdered.rawValue ||
               pattern == Element.checkBoxUnchecked.rawValue ||
               pattern == Element.checkBoxChecked.rawValue ||
               pattern == Element.quote.rawValue
    }
    
    /// Checks if a given range is inside any of the code block ranges.
    ///
    /// - parameter range: The range to check.
    /// - parameter codeBlockRanges: Array of code block ranges.
    ///
    /// - returns: True if the range is inside a code block.
    private func isInsideCodeBlock(_ range: NSRange, codeBlockRanges: [NSRange]) -> Bool {
        for codeBlockRange in codeBlockRanges {
            if NSLocationInRange(range.location, codeBlockRange) {
                return true
            }
        }
        return false
    }
}
