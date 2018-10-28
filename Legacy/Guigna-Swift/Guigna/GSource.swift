import Foundation

enum GState: Int {
    case off
    case on
    case hidden
}


enum GMode: Int {
    case offline
    case online
}


@objc class GSource: NSObject {

    @objc var name: String
    @objc var categories: [AnyObject]?
    var items: [GItem]
    var agent: GAgent!
    var mode: GMode
    var status: GState
    var homepage: String!
    var logpage: String!
    var cmd: String = "CMD"

    init(name: String, agent: GAgent?) {
        self.name = name
        self.agent = agent
        items = [GItem]()
        items.reserveCapacity(50000)
        status = .on
        mode = .offline
    }

    convenience init(name: String) {
        self.init(name: name, agent: nil)
    }

    func info(_ item: GItem) -> String {
        return "\(item.name) - \(item.version)\n\(self.home(item))"
    }

    func home(_ item: GItem) -> String {
        if item.homepage != nil {
            return item.homepage
        } else {
            return homepage
        }
    }

    func log(_ item: GItem) -> String {
        return home(item)
    }

    func contents(_ item: GItem) -> String {
        return ""
    }

    func cat(_ item: GItem) -> String {
        return "[Not Available]"
    }


    func deps(_ item: GItem) -> String {
        return ""
    }


    func dependents(_ item: GItem) -> String {
        return ""
    }

}


@objc(GSourceTransformer)
class GSourceTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return false
    }

    override func transformedValue(_ source: Any?) -> Any? {
        if source == nil {
            return nil
        }
        let name: String = (source! as AnyObject).name
        switch name {
        case "MacPorts":
            return NSImage(named: NSImage.Name("system-macports.tiff"))
        case "Homebrew":
            return NSImage(named: NSImage.Name("system-homebrew.tiff"))
        case "Homebrew Casks":
            return NSImage(named: NSImage.Name("system-homebrewcasks.tiff"))
        case "macOS":
            return NSImage(named: NSImage.Name("system-macosx.tiff"))
        case "iTunes":
            return NSImage(named: NSImage.Name("system-itunes.tiff"))
        case "Fink":
            return NSImage(named: NSImage.Name("system-fink.tiff"))
        case "pkgsrc", "pkgin":
            return NSImage(named: NSImage.Name("system-pkgsrc.tiff"))
        case "FreeBSD":
            return NSImage(named: NSImage.Name("source-freebsd.tiff"))
        case "Rudix":
            return NSImage(named: NSImage.Name("system-rudix.tiff"))
        case "Native Installers":
            return NSImage(named: NSImage.Name("source-native.tiff"))
        case "Pkgsrc.se":
            return NSImage(named: NSImage.Name("source-pkgsrc.se.tiff"))
        case "Freecode":
            return NSImage(named: NSImage.Name("source-freecode.tiff"))
        case "Debian":
            return NSImage(named: NSImage.Name("source-debian.tiff"))
        case "PyPI":
            return NSImage(named: NSImage.Name("source-pypi.tiff"))
        case "RubyGems":
            return NSImage(named: NSImage.Name("source-rubygems.tiff"))
        case "CocoaPods":
            return NSImage(named: NSImage.Name("source-cocoapods.tiff"))
        case "MacUpdate":
            return NSImage(named: NSImage.Name("source-macupdate.tiff"))
        case "Mac Torrents":
            return NSImage(named: NSImage.Name("source-mactorrents.tiff"))
        case "AppShopper", "AppShopper iOS":
            return NSImage(named: NSImage.Name("source-appshopper.tiff"))
        case "Chocolatey":
            return NSImage(named: NSImage.Name("source-chocolatey.tiff"))
        case "installed":
            return NSImage(named: .statusAvailable)
        case "outdated":
            return NSImage(named: .statusPartiallyAvailable)
        case "inactive":
            return NSImage(named: .statusNone)
        case let n where n.hasPrefix("marked"):
            return NSImage(named: NSImage.Name("status-marked.tiff"))
        case let n where n.hasPrefix("new"):
            return NSImage(named: NSImage.Name("status-new.tiff"))
        case let n where n.hasPrefix("updated"):
            return NSImage(named: NSImage.Name("status-updated.tiff"))
        default:
            return nil
        }
    }
}
