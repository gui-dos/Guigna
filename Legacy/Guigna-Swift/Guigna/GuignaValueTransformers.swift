import Foundation

@objc(GStatusTransformer)
class GStatusTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        if value == nil {
            return nil
        }
        let status = GStatus(rawValue: (value! as AnyObject).intValue)!
        switch status {
        case .inactive:
            return NSImage(named: NSImage.statusNoneName)
        case .upToDate:
            return NSImage(named: NSImage.statusAvailableName)
        case .outdated:
            return NSImage(named: NSImage.statusPartiallyAvailableName)
        case .updated:
            return NSImage(named: "status-updated.tiff")
        case .new:
            return NSImage(named: "status-new.tiff")
        case .broken:
            return NSImage(named: NSImage.statusUnavailableName)
        default:
            return nil
        }
    }
}



@objc(GMarkTransformer)
class GMarkTransformer: ValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        if value == nil {
            return nil
        }
        let mark = GMark(rawValue: (value! as AnyObject).intValue)!
        switch mark {
        case .install:
            return NSImage(named: NSImage.addTemplateName)
        case .uninstall:
            return NSImage(named: NSImage.removeTemplateName)
        case .deactivate:
            return NSImage(named: NSImage.stopProgressTemplateName)
        case .upgrade:
            return NSImage(named: NSImage.refreshTemplateName)
        case .fetch:
            return NSImage(named: "source-native.tiff")
        case .clean:
            return NSImage(named: NSImage.actionTemplateName)
        default:
            return nil
        }
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
            return NSImage(named: "system-macports.tiff")
        case "Homebrew":
            return NSImage(named: "system-homebrew.tiff")
        case "Homebrew Casks":
            return NSImage(named: "system-homebrewcasks.tiff")
        case "macOS":
            return NSImage(named: "system-macosx.tiff")
        case "iTunes":
            return NSImage(named: "system-itunes.tiff")
        case "Fink":
            return NSImage(named: "system-fink.tiff")
        case "pkgsrc", "pkgin":
            return NSImage(named: "system-pkgsrc.tiff")
        case "FreeBSD":
            return NSImage(named: "source-freebsd.tiff")
        case "Rudix":
            return NSImage(named: "system-rudix.tiff")
        case "Native Installers":
            return NSImage(named: "source-native.tiff")
        case "Pkgsrc.se":
            return NSImage(named: "source-pkgsrc.se.tiff")
        case "Freecode":
            return NSImage(named: "source-freecode.tiff")
        case "Debian":
            return NSImage(named: "source-debian.tiff")
        case "PyPI":
            return NSImage(named: "source-pypi.tiff")
        case "RubyGems":
            return NSImage(named: "source-rubygems.tiff")
        case "CocoaPods":
            return NSImage(named: "source-cocoapods.tiff")
        case "MacUpdate":
            return NSImage(named: "source-macupdate.tiff")
        case "Mac Torrents":
            return NSImage(named: "source-mactorrents.tiff")
        case "AppShopper", "AppShopper iOS":
            return NSImage(named: "source-appshopper.tiff")
        case "Chocolatey":
            return NSImage(named: "source-chocolatey.tiff")
        case "installed":
            return NSImage(named: NSImage.statusAvailableName)
        case "outdated":
            return NSImage(named: NSImage.statusPartiallyAvailableName)
        case "inactive":
            return NSImage(named: NSImage.statusNoneName)
        case let n where n.hasPrefix("marked"):
            return NSImage(named: "status-marked.tiff")
        case let n where n.hasPrefix("new"):
            return NSImage(named: "status-new.tiff")
        case let n where n.hasPrefix("updated"):
            return NSImage(named: "status-updated.tiff")
        default:
            return nil
        }
    }
}

