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
    @objc dynamic var version: String
    weak var source: GSource!
    weak var system: GSystem!

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
            return NSImage(named: .statusNone)
        case .upToDate:
            return NSImage(named: .statusAvailable)
        case .outdated:
            return NSImage(named: .statusPartiallyAvailable)
        case .updated:
            return NSImage(named: NSImage.Name("status-updated.tiff"))
        case .new:
            return NSImage(named: NSImage.Name("status-new.tiff"))
        case .broken:
            return NSImage(named: .statusUnavailable)
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
            return NSImage(named: NSImage.Name.addTemplate)
        case .uninstall:
            return NSImage(named: NSImage.Name.removeTemplate)
        case .deactivate:
            return NSImage(named: NSImage.Name.stopProgressTemplate)
        case .upgrade:
            return NSImage(named: NSImage.Name.refreshTemplate)
        case .fetch:
            return NSImage(named: NSImage.Name(rawValue: "source-native.tiff"))
        case .clean:
            return NSImage(named: NSImage.Name.actionTemplate)
        default:
            return nil
        }
    }
}
