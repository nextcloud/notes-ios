//
//  Theme.swift
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

public struct Theme {

    public enum BuiltIn: String {
        case Base16TomorrowDark = "base16-tomorrow-dark"
        case Base16TomorrowLight = "base16-tomorrow-light"
        case BluesClues = "blues-clues"
        case OneDarkCustom = "one-dark-custom"
        case OneLightCustom = "one-light-custom"
        case OneDark = "one-dark"
        case OneLight = "one-light"
        case SolarizedDark = "solarized-dark"
        case SolarizedLight = "solarized-light"
        case SystemMinimal = "system-minimal"

        public func theme() -> Theme {
            return Theme(self.rawValue)
        }
    }

    /// The body style for the Notepad editor.
    public var body: Style = Style()
    /// The background color of the Notepad.
    public var backgroundColor: UniversalColor = UniversalColor.clear
    /// The tint color (AKA cursor color) of the Notepad.
    public var tintColor: UniversalColor = UniversalColor.blue

    /// All of the other styles for the Notepad editor.
    public var styles: [Style] = []
    

    /// Build a theme from a JSON theme file.
    ///
    /// - parameter name: The name of the JSON theme file.
    ///
    /// - returns: The Theme.
    public init(_ name: String) {
        let bundleUrl = Bundle.main.url(forResource: "Themes", withExtension: "bundle")!
        let bundle =  Bundle(url: bundleUrl)!
        let url = bundle.url(forResource: "json/\(name)", withExtension: "json")!

        if let data = convertFile(url) {
            configure(data)
        }
    }
    
    public init(themePath: URL) {
        if let data = convertFile(themePath) {
            configure(data)
        }
    }
    
    public init() {
    }

    /// Configures all of the styles for the Theme.
    ///
    /// - parameter data: The dictionary data form the parsed JSON file.
    mutating func configure(_ data: [String: AnyObject]) {
        if let editorStyles = data["editor"] as? [String: AnyObject] {
            configureEditor(editorStyles)
        }

        if var allStyles = data["styles"] as? [String: AnyObject] {
            if let bodyStyles = allStyles["body"] as? [String: AnyObject], let parsedBodyStyles = parse(bodyStyles) {
                body = Style(element: .body, attributes: parsedBodyStyles)
            } else { // Create a default body font so other styles can inherit from it.
                let attributes = [NSAttributedString.Key.foregroundColor: UniversalColor.label]
                body = Style(element: .body, attributes: attributes)
            }

            allStyles.removeValue(forKey: "body")
            for (element, attributes) in allStyles {
                if let attributes = attributes as? [String : AnyObject], let parsedStyles = parse(attributes) {
                    if let regexString = attributes["regex"] as? String {
                        let regex = regexString.toRegex()
                        styles.append(Style(regex: regex, attributes: parsedStyles))
                    }
                    else {
                        styles.append(Style(element: Element.unknown.from(string: element), attributes: parsedStyles))
                    }
                }
            }
        }
    }

    /// Sets the background color, tint color, etc. of the Notepad editor.
    ///
    /// - parameter attributes: The attributes to parse for the editor.
    mutating func configureEditor(_ attributes: [String: AnyObject]) {
        if let bgColor = attributes["backgroundColor"] {
            let value = bgColor as! String
            backgroundColor = UniversalColor(hexString: value)
        }

        if let tint = attributes["tintColor"] {
            let value = tint as! String
            tintColor = UniversalColor(hexString: value)
        }
    }

    /// Parses attributes from shorthand JSON to real attributed string key constants.
    ///
    /// - parameter attributes: The attributes to parse.
    ///
    /// - returns: The converted attribute/key constant pairings.
    func parse(_ attributes: [String: AnyObject]) -> [NSAttributedString.Key: Any]? {
        var stringAttributes = [NSAttributedString.Key: Any]()

        if let color = attributes["color"] as? String {
            stringAttributes[NSAttributedString.Key.foregroundColor] = UniversalColor(hexString: color)
        } else {
            stringAttributes[NSAttributedString.Key.foregroundColor] = UniversalColor.label
        }
        
        let bodyFont = body.attributes[NSAttributedString.Key.font] as? UniversalFont
        // if size is set use custom size, otherwise use body font size, otherwise fallback to 15 points
        let fontSize: CGFloat = attributes["size"] as? CGFloat ?? (bodyFont?.pointSize ?? (UniversalFont(style: .body)?.pointSize ?? 15))
        let fontTraits = attributes["traits"] as? String ?? ""
        var font: UniversalFont?

        var textStyle: UniversalFont.TextStyle = .body
        if let style = attributes["style"] as? String  {
            switch style {
            case "body":
                break
            case "title1":
                textStyle = .title1
            case "title2":
                textStyle = .title2
            case "title3":
                textStyle = .title3
            default:
                break
            }
        }
        font = UniversalFont.preferredFont(forTextStyle: textStyle)

        if let fontName = attributes["font"] as? String, fontName != "System", !fontName.hasPrefix(".") {
            // use custom font if set
            font = UniversalFont(name: fontName, size: fontSize)?.with(traits: fontTraits)
        } else if let bodyFont = bodyFont, bodyFont.fontName != "System", !bodyFont.fontName.hasPrefix(".") {
            // use body font if set
            font = UniversalFont(name: bodyFont.fontName, size: fontSize)?.with(traits: fontTraits)
        } else {
#if os(iOS)
            switch fontTraits {
            case "bold":
                font = font?.bold()
            case "italic":
                font = font?.italic()
            case "monospace":
                font = UniversalFont(style: textStyle, design: .monospaced)
            case "strikeThrough":
                stringAttributes[NSAttributedString.Key.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            default:
                break
            }
#else
            // use system font in all other cases
            font = UniversalFont.systemFont(ofSize: fontSize).with(traits: fontTraits, size: fontSize)
#endif
        }

        stringAttributes[NSAttributedString.Key.font] = font
        return stringAttributes
    }

    /// Converts a file from JSON to a [String: AnyObject] dictionary.
    ///
    /// - parameter path: The path to the JSON file.
    ///
    /// - returns: The new dictionary.
    func convertFile(_ path: URL) -> [String: AnyObject]? {
        do {
            let json = try String(contentsOf: path, encoding: .utf8)
            if let data = json.data(using: .utf8) {
                do {
                    return try JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject]
                } catch let error as NSError {
                    print(error)
                }
            }
        } catch let error as NSError {
            print(error)
        }

        return nil
    }
}
