import Foundation

final class MacPorts: GSystem {

    override class var prefix: String { return "/opt/local"}

    init(agent: GAgent) {
        super.init(name: "MacPorts", agent: agent)
        homepage = "http://www.macports.org"
        logpage = "http://trac.macports.org/timeline"
        cmd = "\(prefix)/bin/port"
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        if (defaults("MacPortsParsePortIndex") as? Bool ?? false) == false && mode == .offline {
            var outputLines = output("\(cmd) list").split("\n")
            outputLines.removeLast()
            let whitespaceCharacterSet = CharacterSet.whitespaces
            for line in outputLines {
                var components = line.split("@")
                let name = components[0].trim(whitespaceCharacterSet)
                components = components[1].split()
                let version = components[0]
                // let revision = "..."
                let categories = components.last!.split("/")[0]
                let pkg = GPackage(name: name, version: version, system: self, status: .available)
                pkg.categories = categories
                items.append(pkg)
                self[name] = pkg
            }

        } else {
            var portIndex = ""
            if mode == .online { // TODO: fetch PortIndex
                portIndex = (try? String(contentsOfFile: ("~/Library/Application Support/Guigna/MacPorts/PortIndex" as NSString).expandingTildeInPath, encoding: .utf8)) ?? ""
            } else {
                portIndex = (try? String(contentsOfFile: "\(prefix)/var/macports/sources/rsync.macports.org/release/tarballs/ports/PortIndex", encoding: .utf8)) ?? ""
            }
            let s =  Scanner(string: portIndex)
            s.charactersToBeSkipped = CharacterSet(charactersIn: "")
            let endsCharacterSet = NSMutableCharacterSet.whitespacesAndNewlines()
            endsCharacterSet.addCharacters(in: "}")
            var str: NSString? = nil
            var name: NSString? = nil
            var key: NSString? = nil
            let value: NSMutableString = ""
            var version: String?
            var revision: String?
            var categories: String?
            var description: String?
            var homepage: String?
            var license: String?
            while true {
                if !s.scanUpTo(" ", into: &name) {
                    break
                }
                s.scanUpTo("\n", into: nil)
                s.scanString("\n", into: nil)
                while true {
                    s.scanUpTo(" ", into: &key)
                    s.scanString(" ", into: nil)
                    s.scanUpToCharacters(from: endsCharacterSet as CharacterSet, into: &str)
                    value.setString(str! as String)
                    var range = value.range(of: "{")
                    while range.location != NSNotFound {
                        value.replaceCharacters(in: range, with: "")
                        if s.scanUpTo("}", into: &str) {
                            value.append(str! as String)
                        }
                        s.scanString("}", into: nil)
                        range = value.range(of: "{")
                    }
                    switch key! {
                    case "version":
                        version = value as String
                    case "revision":
                        revision = value as String
                    case "categories":
                        categories = value as String
                    case "description":
                        description = value as String
                    case "homepage":
                        homepage = value as String
                    case "license":
                        license = value as String
                    default:
                        break
                    }
                    if s.scanString("\n", into: nil) {
                        break
                    }
                    s.scanString(" ", into: nil)
                }
                let pkg = GPackage(name: name! as String, version: "\(version!)_\(revision!)", system: self, status: .available)
                pkg.categories = categories!
                pkg.description = description!
                pkg.license = license!
                if self.mode == .online {
                    pkg.homepage = homepage
                }
                items.append(pkg)
                self[name! as String] = pkg
            }
        }
        self.installed() // update status
        return items as! [GPackage]
    }


    @discardableResult
    override func installed() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status != .available} as! [GPackage]
        }
        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .online {
            return pkgs
        }

        var outputLines = output("\(cmd) installed").split("\n")
        outputLines.removeLast()
        outputLines.remove(at: 0)
        let itemsCount = items.count
        let notInactiveItems = items.filter { $0.status != .inactive}
        if itemsCount != notInactiveItems.count {
            items = notInactiveItems
            self.agent.appDelegate!.removeItems({ $0.status == .inactive && $0.system === self}) // TODO: ugly
        }
        var status: GStatus
        for pkg in items as! [GPackage] {
            status = pkg.status
            pkg.installed = nil
            if status != .updated && status != .new {
                pkg.status = .available
            }
        }
        self.outdated() // index outdated ports
        let whitespaceCharacterSet = CharacterSet.whitespaces
        for line in outputLines {
            var components = line.trim(whitespaceCharacterSet).split()
            let name = components[0]
            var version = components[1].substring(from: 1)
            var variants: String! = nil
            let idx = version.index("+")
            if idx != NSNotFound {
                variants = version.substring(from: idx + 1).split("+").join()
                version = version.substring(to: idx)
            }
            if variants != nil {
                variants = variants.replace(" ", "+")
                version = "\(version) +\(variants)"
            }
            status = components.count == 2 ? .inactive : .upToDate
            var pkg: GPackage! = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if status == .inactive {
                pkg = nil
            }
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: status)
                if status != .inactive {
                    self[name] = pkg
                } else {
                    items.append(pkg)
                    self.agent.appDelegate!.addItem(pkg)  // TODO: ugly
                }
            } else {
                if pkg.status == .available {
                    pkg.status = status
                }
            }
            pkg.installed = version
            pkg.options = variants
            pkgs.append(pkg)
        }
        return pkgs
    }


    @discardableResult
    override func outdated() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status == .outdated} as! [GPackage]
        }

        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .online {
            return pkgs
        }

        var outputLines = output("\(cmd) outdated").split("\n")
        outputLines.removeLast()
        outputLines.remove(at: 0)
        for line in outputLines {
            let components = line.split(" < ")[0].split()
            let name = components[0]
            let version = components.last!
            var pkg = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg!.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .outdated)
                self[name] = pkg
            } else {
                pkg!.status = .outdated
            }
            pkg!.installed = version
            pkgs.append(pkg!)
        }
        return pkgs
    }


    override func inactive() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status == .inactive} as! [GPackage]
        }
        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .online {
            return pkgs
        }

        for pkg in installed() {
            if pkg.status == .inactive {
                pkgs.append(pkg)
            }
        }
        return pkgs
    }


    override func info(_ item: GItem) -> String {
        if self.isHidden {
            return super.info(item)
        }
        if mode == .online {
            // TODO: format keys and values
            var info = agent.nodes(URL: "http://www.macports.org/ports.php?by=name&substr=\(item.name)", XPath: "//div[@id=\"content\"]/dl")[0].stringValue!
            let keys = agent.nodes(URL: "http://www.macports.org/ports.php?by=name&substr=\(item.name)", XPath: "//div[@id=\"content\"]/dl//i")
            var stringValue: String!
            for key in keys {
                stringValue = key.stringValue!
                info = info.replace(stringValue, "\n\n\(stringValue)\n")
            }
            return info
        }
        let columns = agent.appDelegate!.shellColumns
        return output("/bin/sh -c export__COLUMNS=\(columns)__;__\(cmd)__info__\(item.name)")
    }


    override func home(_ item: GItem) -> String {
        if self.isHidden {
            var homepage: String
            for line in cat(item).split("\n") {
                if line.contains("homepage") {
                    homepage = line.substring(from: 8).trim()
                    if homepage.hasPrefix("http") {
                        return homepage
                    }
                }
            }
            return log(item)
        }
        if mode == .online {
            return item.homepage
        }
        let url = output("\(cmd) -q info --homepage \(item.name)")
        return url.substring(to: url.length - 1)
    }

    override func log(_ item: GItem) -> String {
        let category = item.categories!.split()[0]
        return "http://trac.macports.org/log/trunk/dports/\(category)/\(item.name)/Portfile"
    }

    override func contents(_ item: GItem) -> String {
        if self.isHidden || mode == .online {
            return "[Not Available]"
        }
        return output("\(cmd) contents \(item.name)")
    }

    override func cat(_ item: GItem) -> String {
        if self.isHidden || mode == .online {
            return (try? String(contentsOf: URL(string: "http://trac.macports.org/browser/trunk/dports/\(item.categories!.split()[0])/\(item.name)/Portfile?format=txt")!, encoding: .utf8)) ?? ""
        }
        return output("\(cmd) cat \(item.name)")
    }

    override func deps(_ item: GItem) -> String {
        if self.isHidden || mode == .online {
            return "[Cannot compute the dependencies now]"
        }
        return output("\(cmd) rdeps --index \(item.name)")
    }

    override func dependents(_ item: GItem) -> String {
        if self.isHidden || mode == .online {
            return ""
        }
        // TODO only when status == installed
        if item.status != .available {
            return output("\(cmd) dependents \(item.name)")
        } else {
            return "[\(item.name) not installed]"
        }
    }

    override func options(_ pkg: GPackage) -> String! {
        var variants: String! = nil
        let infoOutput = output("\(cmd) info --variants \(pkg.name)").trim()
        if infoOutput.length > 10 {
            variants = infoOutput.substring(from: 10).split(", ").join()
        }
        return variants
    }

    override func installCmd(_ pkg: GPackage) -> String {
        var variants: String! = pkg.markedOptions
        if variants == nil {
            variants = ""
        } else {
            variants = "+" + variants!.replace(" ", "+")
        }
        return "sudo \(cmd) install \(pkg.name) \(variants!)".trim()
    }

    override func uninstallCmd(_ pkg: GPackage) -> String {
        if pkg.status == .outdated || pkg.status == .updated {
            return "sudo \(cmd) -f uninstall \(pkg.name); sudo \(cmd) clean --all \(pkg.name)"
        } else {
            return "sudo \(cmd) -f uninstall \(pkg.name) @\(pkg.installed!)"
        }
    }

    override func deactivateCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) deactivate \(pkg.name)"
    }

    override func upgradeCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) upgrade \(pkg.name)"
    }

    override func fetchCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) fetch \(pkg.name)"
    }

    override func cleanCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) clean --all \(pkg.name)"
    }

    override var updateCmd: String! {
        get {
            if mode == .online {
                return "sudo cd; cd ~/Library/Application\\ Support/Guigna/Macports; /usr/bin/rsync -rtzv rsync://rsync.macports.org/release/tarballs/PortIndex_darwin_15_i386/PortIndex PortIndex"
            } else {
                return "sudo \(cmd) -d selfupdate"
            }
        }
    }

    override var hideCmd: String! {
        get {
            return "sudo mv \(prefix) \(prefix)_off"}
    }

    override var unhideCmd: String! {
        get {
            return "sudo mv \(prefix)_off \(prefix)"}
    }

}
