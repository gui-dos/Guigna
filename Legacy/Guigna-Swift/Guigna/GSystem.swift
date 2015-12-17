import Foundation

class GSystem: GSource {

    class var prefix: String { return "" }

    var prefix: String
    var index: [String: GPackage]
    var defaults: [String: AnyObject]?

    override init(name: String, agent: GAgent!) {
        prefix = self.dynamicType.prefix
        index = [String: GPackage](minimumCapacity: 50000)
        super.init(name: name, agent: agent)
        status = .On
    }

    func defaults(key: String) -> AnyObject? {
        if self.agent != nil {
            return self.agent.appDelegate?.defaults[key]
        } else {
            return self.defaults?[key]
        }
    }

    func setDefaults(value: AnyObject, forKey key: String) {
        self.defaults?[key] = value
        self.agent?.appDelegate?.defaults[key] = value as! NSObject
    }

    func list() -> [GPackage] {
        return []
    }

    func installed() -> [GPackage] {
        return []
    }

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
                categories.unionInPlace(cats.split())
            }
        }
        var categoriesArray = Array(categories)
        categoriesArray.sortInPlace { $0 < $1 }
        return categoriesArray
    }

    func availableCommands() -> [[String]] {
        return [["help", "CMD help"], ["man", "man CMD | col -b"]]
    }

    func installCmd(pkg: GPackage) -> String {
        return "\(cmd) install \(pkg.name)"
    }

    func uninstallCmd(pkg: GPackage) -> String {
        return "\(cmd) uninstall \(pkg.name)"
    }

    func deactivateCmd(pkg: GPackage) -> String {
        return "\(cmd) deactivate \(pkg.name)"
    }

    func upgradeCmd(pkg: GPackage) -> String {
        return "\(cmd) upgrade \(pkg.name)"
    }

    func fetchCmd(pkg: GPackage) -> String {
        return "\(cmd) fetch \(pkg.name)"
    }

    func cleanCmd(pkg: GPackage) -> String {
        return "\(cmd) clean \(pkg.name)"
    }

    func options(pkg: GPackage) -> String! {
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

    func verbosifiedCmd(command: String) -> String {
        return command.replace("\(cmd)", "\(cmd) -d")
    }

    func output(command: String) -> String! {
        return agent.output(command)
    }
}
