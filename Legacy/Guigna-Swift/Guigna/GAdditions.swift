import Foundation
import WebKit

protocol GAppDelegate {
    var defaults: NSUserDefaultsController! { get set }
    func log(text: String)
    // var allPackages: [GPackage] { get set } // to avoid in Swift since it returns a copy
    func addItem(item: GItem) // to add an inactive package without requiring a copy of allPackages
    func removeItem(item: GItem) // TODO
    func removeItems(excludeElement: GItem -> Bool) // to remove inactive packages from allPackages in Swift
    var shellColumns: Int { get }
}

extension Array {
    
    func join(separator: String = " ") -> String {
        // return separator.join(self) // doesn't compile anymore with B6
        return self._bridgeToObjectiveC().componentsJoinedByString(separator)
        
    }
    
}


extension String {
    
    var length: Int {
        return self.characters.count
    }
    
    var exists: Bool {
        return NSFileManager.defaultManager().fileExistsAtPath((self as NSString).stringByExpandingTildeInPath)
    }
    
    func index(string: String) -> Int {
        if let range = self.rangeOfString(string) {
            return startIndex.distanceTo(range.startIndex)
        } else {
            return NSNotFound
        }
    }
    
    func rindex(string: String) -> Int {
        if let range = self.rangeOfString(string, options: .BackwardsSearch) {
            return startIndex.distanceTo(range.startIndex)
        } else {
            return NSNotFound
        }
    }
    
    func contains(string: String) -> Bool {
        return self.rangeOfString(string) != nil ? true : false
    }
    
    subscript(index: Int) -> Character {
        return self[startIndex.advancedBy(index)]
    }
    
    subscript(range: Range<Int>) -> String {
        let rangeStartIndex = startIndex.advancedBy(range.startIndex)
        return self[rangeStartIndex..<rangeStartIndex.advancedBy(range.endIndex - range.startIndex)]
    }
    
    func substring(location: Int, _ length: Int) -> String {
        let locationIndex = startIndex.advancedBy(location)
        return self[locationIndex..<locationIndex.advancedBy(length)]
    }
    
    func substringFromIndex(index: Int) -> String {
        return self[startIndex.advancedBy(index)..<endIndex]
    }
    
    func substringToIndex(index: Int) -> String {
        return self[startIndex..<startIndex.advancedBy(index)]
    }
    
    func split(delimiter: String = " ") -> [String] {
        return self.componentsSeparatedByString(delimiter)
    }
    
    func replace(string: String, _ replacement: String) -> String {
        return self.stringByReplacingOccurrencesOfString(string, withString: replacement)
    }
    
}


extension NSXMLNode {
    
    subscript(xpath: String) -> [NSXMLNode] {
        get {
            return try! self.nodesForXPath(xpath)
        }
    }
    
    func attribute(name: String) -> String! {
        if let attribute = (self as! NSXMLElement).attributeForName(name) {
            return attribute.stringValue!
        } else {
            return nil
        }
    }
    
    var href: String {
        get {
            return (self as! NSXMLElement).attributeForName("href")!.stringValue!
        }
    }
}


extension NSUserDefaultsController {
    subscript(key: String) -> NSObject! {
        get {
            if let value = self.values.valueForKey(key) as! NSObject! {
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
    
    override public func swipeWithEvent(event: NSEvent) {
        let x = event.deltaX
        if x < 0 && self.canGoForward {
            self.goForward()
        } else if x > 0 && self.canGoBack {
            self.goBack()
        }
    }
    
    override public func magnifyWithEvent(event: NSEvent) {
        let multiplier: CFloat = self.textSizeMultiplier * CFloat(event.magnification + 1.0)
        self.textSizeMultiplier = multiplier
    }
    
}
