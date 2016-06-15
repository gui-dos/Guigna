import Foundation
import WebKit

protocol GAppDelegate {
    var defaults: NSUserDefaultsController! { get set }
    func log(_ text: String)
    // var allPackages: [GPackage] { get set } // to avoid in Swift since it returns a copy
    func addItem(_ item: GItem) // to add an inactive package without requiring a copy of allPackages
    func removeItem(_ item: GItem) // TODO
    func removeItems(_ excludeElement: (GItem) -> Bool) // to remove inactive packages from allPackages in Swift
    var shellColumns: Int { get }
}

extension Array {

    func join(_ separator: String = " ") -> String {
        // return separator.join(self) // doesn't compile anymore with B6
        return self._bridgeToObjectiveC().componentsJoined(by: separator)

    }

}


extension String {

    var length: Int {
        return self.characters.count
    }

    var exists: Bool {
        return FileManager.default().fileExists(atPath: (self as NSString).expandingTildeInPath)
    }

    func index(_ string: String) -> Int {
        if let range = self.range(of: string) {
            return characters.distance(from: startIndex, to: range.lowerBound)
        } else {
            return NSNotFound
        }
    }

    func rindex(_ string: String) -> Int {
        if let range = self.range(of: string, options: .backwardsSearch) {
            return characters.distance(from: startIndex, to: range.lowerBound)
        } else {
            return NSNotFound
        }
    }

    func contains(_ string: String) -> Bool {
        return self.range(of: string) != nil ? true : false
    }

    subscript(index: Int) -> Character {
        return self[characters.index(startIndex, offsetBy: index)]
    }

    subscript(range: Range<Int>) -> String {
        let rangeStartIndex = characters.index(startIndex, offsetBy: range.lowerBound)
        return self[rangeStartIndex..<<#T##String.CharacterView corresponding to `rangeStartIndex`##String.CharacterView#>.index(rangeStartIndex, offsetBy: range.endIndex - range.startIndex)]
    }

    func substring(_ location: Int, _ length: Int) -> String {
        let locationIndex = characters.index(startIndex, offsetBy: location)
        return self[locationIndex..<<#T##String.CharacterView corresponding to `locationIndex`##String.CharacterView#>.index(locationIndex, offsetBy: length)]
    }

    func substringFromIndex(_ index: Int) -> String {
        return self[characters.index(startIndex, offsetBy: index)..<endIndex]
    }

    func substringToIndex(_ index: Int) -> String {
        return self[startIndex..<characters.index(startIndex, offsetBy: index)]
    }

    func split(_ delimiter: String = " ") -> [String] {
        return self.components(separatedBy: delimiter)
    }

    func replace(_ string: String, _ replacement: String) -> String {
        return self.replacingOccurrences(of: string, with: replacement)
    }

    func trim(_ characters: String = "") -> String {
        var charSet: CharacterSet
        if characters.length == 0 {
            charSet = CharacterSet.whitespacesAndNewlines
        } else {
            charSet = CharacterSet(charactersIn: characters)
        }
        return self.trimmingCharacters(in: charSet)
    }

    func trim(_ characterSet: CharacterSet) -> String {
        return self.trimmingCharacters(in: characterSet)
    }

}


extension XMLNode {

    subscript(xpath: String) -> [XMLNode] {
        get {
            return try! self.nodes(forXPath: xpath)
        }
    }

    func attribute(_ name: String) -> String! {
        if let attribute = (self as! XMLElement).attribute(forName: name) {
            return attribute.stringValue!
        } else {
            return nil
        }
    }

    var href: String {
        get {
            return (self as! XMLElement).attribute(forName: "href")!.stringValue!
        }
    }
}


extension NSUserDefaultsController {
    subscript(key: String) -> NSObject! {
        get {
            if let value = self.values.value(forKey: key) as! NSObject! {
                return value
            } else {
                return nil
            }
        }
        set(newValue) {
            self.values.setValue(newValue, forKey: key)
        }
    }
}


extension WebView {

    override public func swipe(with event: NSEvent) {
        let x = event.deltaX
        if x < 0 && self.canGoForward {
            self.goForward()
        } else if x > 0 && self.canGoBack {
            self.goBack()
        }
    }

    override public func magnify(with event: NSEvent) {
        let multiplier: CFloat = self.textSizeMultiplier * CFloat(event.magnification + 1.0)
        self.textSizeMultiplier = multiplier
    }
    
}
