import Foundation

@objc enum GStatus: Int {
    case available = 0
    case inactive
    case upToDate
    case outdated
    case updated
    case new
    case broken
}

@objc enum GMark: Int {
    case noMark = 0
    case install
    case uninstall
    case deactivate
    case upgrade
    case fetch
    case clean
}


class GItem: NSObject {
    let name: String
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
        self.mark = .noMark
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
            return NSImage(named: NSImageNameStatusNone)
        case .upToDate:
            return NSImage(named: NSImageNameStatusAvailable)
        case .outdated:
            return NSImage(named: NSImageNameStatusPartiallyAvailable)
        case .updated:
            return NSImage(named: "status-updated.tiff")
        case .new:
            return NSImage(named: "status-new.tiff")
        case .broken:
            return NSImage(named: NSImageNameStatusUnavailable)
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
            return NSImage(named: NSImageNameAddTemplate)
        case .uninstall:
            return NSImage(named: NSImageNameRemoveTemplate)
        case .deactivate:
            return NSImage(named: NSImageNameStopProgressTemplate)
        case .upgrade:
            return NSImage(named: NSImageNameRefreshTemplate)
        case .fetch:
            return NSImage(named: "source-native.tiff")
        case .clean:
            return NSImage(named: NSImageNameActionTemplate)
        default:
            return nil
        }
    }
}
