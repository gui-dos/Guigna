import Foundation

@objc enum GStatus: Int {
    case Available = 0
    case Inactive
    case UpToDate
    case Outdated
    case Updated
    case New
    case Broken
}

@objc enum GMark: Int {
    case NoMark = 0
    case Install
    case Uninstall
    case Deactivate
    case Upgrade
    case Fetch
    case Clean
}


class GItem: NSObject {
    var name: String
    dynamic var version: String
    weak var source: GSource!
    weak var system: GSystem!
    
    dynamic var status: GStatus
    dynamic var mark: GMark
    dynamic var installed: String!
    dynamic var categories: String?
    dynamic var license: String?
    var _description: String?
    override var description: String {
        get {
            if _description != nil {
                return _description!
            } else {
                return ""
            }
        }
        set {
            self._description = newValue}
    }
    var homepage: String!
    var screenshots: String!
    var URL: String!
    var id: String!
    
    init(name: String, version: String, source: GSource, status: GStatus) {
        self.name = name
        self.version = version
        self.source = source
        self.system = nil
        self.status = status
        self.mark = .NoMark
    }
    
    var info: String {
        get {
            return source.info(self)
        }
    }
    
    var home: String {
        get {
            return source.home(self)
        }
    }
    
    var log: String {
        get {
            return source.log(self)
        }
    }
    
    var contents: String {
        get {
            return source.contents(self)
        }
    }
    
    var cat: String {
        get {
            return source.cat(self)
        }
    }
    
    var deps: String {
        get {
            return source.deps(self)
        }
    }
    
    var dependents: String {
        get {
            return source.dependents(self)
        }
    }
}


@objc(GStatusTransformer)
class GStatusTransformer: NSValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    override func transformedValue(value: AnyObject?) -> AnyObject? {
        if value == nil {
            return nil
        }
        let status = GStatus(rawValue: value!.integerValue)!
        switch status {
        case .Inactive:
            return NSImage(named: NSImageNameStatusNone)
        case .UpToDate:
            return NSImage(named: NSImageNameStatusAvailable)
        case .Outdated:
            return NSImage(named: NSImageNameStatusPartiallyAvailable)
        case .Updated:
            return NSImage(named: "status-updated.tiff")
        case .New:
            return NSImage(named: "status-new.tiff")
        case .Broken:
            return NSImage(named: NSImageNameStatusUnavailable)
        default:
            return nil
        }
    }
}


@objc(GMarkTransformer)
class GMarkTransformer: NSValueTransformer {
    
    override class func transformedValueClass() -> AnyClass {
        return NSImage.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    override func transformedValue(value: AnyObject?) -> AnyObject? {
        if value == nil {
            return nil
        }
        let mark = GMark(rawValue: value!.integerValue)!
        switch mark {
        case .Install:
            return NSImage(named: NSImageNameAddTemplate)
        case .Uninstall:
            return NSImage(named: NSImageNameRemoveTemplate)
        case .Deactivate:
            return NSImage(named: NSImageNameStopProgressTemplate)
        case .Upgrade:
            return NSImage(named: NSImageNameRefreshTemplate)
        case .Fetch:
            return NSImage(named: "source-native.tiff")
        case .Clean:
            return NSImage(named: NSImageNameActionTemplate)
        default:
            return nil
        }
    }
}


