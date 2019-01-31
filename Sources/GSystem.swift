import Foundation

class GSystem: GSource {

    class var name: String { return "Guigna" }
    class var prefix: String { return "" }

    var prefix: String
    var index: [String: GPackage]
    var defaults: [String: AnyObject]?

    override init(name: String, agent: GAgent! = nil) {
        prefix = type(of: self).prefix
        index = [String: GPackage](minimumCapacity: 50000)
        super.init(name: name, agent: agent)
        status = .on
    }

    required init(agent: GAgent) {
        prefix = type(of: self).prefix
        index = [String: GPackage](minimumCapacity: 50000)
        super.init(name: type(of: self).name, agent: agent)
        status = .on
    }


    func defaults(_ key: String) -> Any? {
        if self.agent != nil {
            return self.agent.appDelegate?.defaults[key]
        } else {
            return self.defaults?[key]
        }
    }

    func setDefaults(_ value: AnyObject, forKey key: String) {
        self.defaults?[key] = value
        self.agent?.appDelegate?.defaults[key] = value as! NSObject
    }

    @discardableResult
    func list() -> [GPackage] {
        return []
    }

    @discardableResult
    func installed() -> [GPackage] {
        return []
    }

    @discardableResult
    func outdated() -> [GPackage] {
        return []
    }

    func inactive() -> [GPackage] {
        return []
    }

    var isHidden: Bool {
        get {
            return "\(prefix)_off".exists
        }
    }

    func key(package pkg: GPackage) -> String {
        return "\(pkg.name)-\(name)"
    }

    subscript(name: String) -> GPackage! {
        get {
            return index["\(name)-\(self.name)"]
        }
        set(pkg) {
            index["\(name)-\(self.name)"] = pkg
        }
    }

    func categoriesList() -> [String] {
        var categories = Set<String>()
        for item in self.items {
            if let cats = item.categories {
                categories.formUnion(cats.split())
            }
        }
        var categoriesArray = Array(categories)
        categoriesArray.sort { $0 < $1 }
        return categoriesArray
    }

    func availableCommands() -> [[String]] {
        return [["help", "CMD help"], ["man", "man CMD | col -b"]]
    }

    func installCmd(_ pkg: GPackage) -> String {
        return "\(cmd) install \(pkg.name)"
    }

    func uninstallCmd(_ pkg: GPackage) -> String {
        return "\(cmd) uninstall \(pkg.name)"
    }

    func deactivateCmd(_ pkg: GPackage) -> String {
        return "\(cmd) deactivate \(pkg.name)"
    }

    func upgradeCmd(_ pkg: GPackage) -> String {
        return "\(cmd) upgrade \(pkg.name)"
    }

    func fetchCmd(_ pkg: GPackage) -> String {
        return "\(cmd) fetch \(pkg.name)"
    }

    func cleanCmd(_ pkg: GPackage) -> String {
        return "\(cmd) clean \(pkg.name)"
    }

    func options(_ pkg: GPackage) -> String! {
        return nil
    }


    var updateCmd: String! {
        get {
            return nil
        }
    }


    var hideCmd: String! {
        get {
            return nil
        }
    }

    var unhideCmd: String! {
        get {
            return nil
        }
    }

    func verbosifiedCmd(_ command: String) -> String {
        return command.replace("\(cmd)", "\(cmd) -d")
    }

    func output(_ command: String) -> String {
        return agent.output(command)
    }

    class var list: [GPackage] {
        get {
            let manager: GSystem = self.init(agent: GAgent())
            let pkgs = manager.list()
            return pkgs
        }
    }
}
