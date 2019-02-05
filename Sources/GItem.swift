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

