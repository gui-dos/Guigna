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


@objc class GItem: NSObject {
    @objc let name: String
    @objc dynamic var version: String
    @objc weak var source: GSource!
    @objc weak var system: GSystem!

    @objc dynamic var status: GStatus
    @objc dynamic var mark: GMark
    @objc dynamic var installed: String!
    @objc dynamic var categories: String?
    @objc dynamic var license: String?
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

    override var debugDescription: String {
        return "\(name) \(version)"
    }

    init(name: String, version: String, source: GSource, status: GStatus = .available) {
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
