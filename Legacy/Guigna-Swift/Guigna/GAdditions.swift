import Foundation
import WebKit

protocol GAppDelegate {
    var defaults: NSUserDefaultsController! { get set }
    func log(_ text: String)
    func status(_ msg: String)
    // var allPackages: [GPackage] { get set } // to avoid in Swift since it returns a copy
    func addItem(_ item: GItem) // to add an inactive package without requiring a copy of allPackages
    func removeItem(_ item: GItem) // TODO
    func removeItems(_ excludeElement: (GItem) -> Bool) // to remove inactive packages from allPackages in Swift
    var shellColumns: Int { get }
}

extension Array {

    func join(_ separator: String = " ") -> String {
        return self._bridgeToObjectiveC().componentsJoined(by: separator)
    }

}


extension String {

    var length: Int {
        return self.characters.count
    }

    var exists: Bool {
        return FileManager.default.fileExists(atPath: (self as NSString).expandingTildeInPath)
    }

    func index(_ string: String) -> Int {
        if let range = self.range(of: string) {
            return self.distance(from: startIndex, to: range.lowerBound)
        } else {
            return NSNotFound
        }
    }

    func rindex(_ string: String) -> Int {
        if let range = self.range(of: string, options: .backwards) {
            return self.distance(from: startIndex, to: range.lowerBound)
        } else {
            return NSNotFound
        }
    }

    subscript(index: Int) -> Character {
        return self[self.index(startIndex, offsetBy: index)]
    }

    subscript(range: CountableRange<Int>) -> String {
        let lowerIndex = self.index(startIndex, offsetBy: range.lowerBound)
        return self[lowerIndex..<self.index(lowerIndex, offsetBy: range.upperBound - range.lowerBound)]
    }

    subscript(range: CountableClosedRange<Int>) -> String {
        let lowerIndex = self.index(startIndex, offsetBy: range.lowerBound)
        return self[lowerIndex...self.index(lowerIndex, offsetBy: range.upperBound - range.lowerBound)]
    }
    func substring(_ location: Int, _ length: Int) -> String {
        let locationIndex = self.index(startIndex, offsetBy: location)
        return self[locationIndex..<self.index(locationIndex, offsetBy: length)]
    }

    func substring(from index: Int) -> String {
        return self[self.index(startIndex, offsetBy: index)..<endIndex]
    }

    func substring(to index: Int) -> String {
        return self[startIndex..<self.index(startIndex, offsetBy: index)]
    }

    func split(_ delimiter: String = " ") -> [String] {
        return self.components(separatedBy: delimiter)
    }

    func replace(_ string: String, _ replacement: String) -> String {
        return self.replacingOccurrences(of: string, with: replacement)
    }

    func trim(_ characters: String = "") -> String {
        var charSet: CharacterSet
        if characters.isEmpty {
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
    subscript(key: String) -> Any! {
        get {
            if let value = (self.values as AnyObject).value(forKey: key) as Any! {
                return value
            } else {
                return nil
            }
        }
        set(newValue) {
            (self.values as AnyObject).setValue(newValue, forKey: key)
        }
    }
}


extension WebView {

    override open func swipe(with event: NSEvent) {
        let x = event.deltaX
        if x < 0 && self.canGoForward {
            self.goForward()
        } else if x > 0 && self.canGoBack {
            self.goBack()
        }
    }

    override open func magnify(with event: NSEvent) {
        let multiplier: CFloat = self.textSizeMultiplier * CFloat(event.magnification + 1.0)
        self.textSizeMultiplier = multiplier
    }
    
}
