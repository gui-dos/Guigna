import Foundation

final class Rudix: GSystem {

    override class var prefix: String { return "/usr/local" }

    init(agent: GAgent) {
        super.init(name: "Rudix", agent: agent)
        homepage = "http://rudix.org/"
        logpage = "https://github.com/rudix-mac/rudix/commits"
        cmd = "\(prefix)/bin/rudix"
    }

    class func clampedOSVersion() -> String {
        var osVersion = G.OSVersion()
        if osVersion < "10.6" || osVersion > "10.9" {
            osVersion = "10.9"
        }
        return osVersion
    }

    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        var manifest = ""
        if mode == .online { // FIXME: manifest is not available anymore
            manifest = (try? String(contentsOf: URL(string: "http://rudix.org/download/2014/10.9/00MANIFEST.txt")!, encoding: String.Encoding.utf8)) ?? ""
        } else {
            var command = "\(cmd) search"
            let osxVersion = Rudix.clampedOSVersion()
            if G.OSVersion() != osxVersion {
                command = "/bin/sh -c export__OSX_VERSION=\(osxVersion)__;__\(cmd)__search"
                manifest = output(command)
            }
        }
        var lines = manifest.split("\n")
        lines.removeLast()
        for line in lines {
            var components = line.split("-")
            var name = components[0]
            if components.count == 4 {
                name += "-\(components[1])"
                components.remove(at: 1)
            }
            var version = components[1]
            version += "-" + components[2].split(".")[0]
            let pkg = GPackage(name: name, version: version, system: self, status: .available)
            if self[name] != nil {
                var found: Int?
                for (i, pkg) in items.enumerated() {
                    if pkg.name == name {
                        found = i
                        break
                    }
                }
                if let idx = found {
                    items.remove(at: idx)
                }
            }
            items.append(pkg)
            self[name] = pkg
        }
        self.installed() // update status
        return items as! [GPackage]
    }


    override func installed() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status != .available} as! [GPackage]
        }

        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .online {
            return pkgs
        }

        var outputLines = output("\(cmd)").split("\n")
        outputLines.removeLast()
        var status: GStatus
        for pkg in items as! [GPackage] {
            status = pkg.status
            pkg.installed = nil
            if status != .updated && status != .new {
                pkg.status = .available
            }
        }
        // self.outdated() // update status
        for line in outputLines {
            let name = line.substring(from: line.rindex(".") + 1)
            var pkg: GPackage! = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .upToDate)
                self[name] = pkg
            } else {
                if pkg.status == .available {
                    pkg.status = .upToDate
                }
            }
            pkg.installed = "" // TODO
            pkgs.append(pkg)
        }
        return pkgs
    }


    override func home(_ item: GItem) -> String {
        for line in cat(item).split("\n") {
            if line.hasPrefix("Site=") {
                homepage = line.substring(from: 5).trim()
                if homepage.hasPrefix("http") {
                    return homepage
                }
            }
        }
        return "http://rudix.org/packages/\(item.name).html"
    }


    override func log(_ item: GItem) -> String {
        return "https://github.com/rudix-mac/rudix/commits/master/Ports/\(item.name)"
    }

    override func contents(_ item: GItem) -> String {
        if item.installed != nil {
            return output("\(cmd) --files \(item.name)")
        } else {
            return "" // TODO: parse http://rudix.org/packages/%@.html
        }
    }

    override func cat(_ item: GItem) -> String {
        return (try? String(contentsOf: URL(string: "https://raw.githubusercontent.com/rudix-mac/rudix/master/Ports/\(item.name)/Makefile")!, encoding: String.Encoding.utf8)) ?? ""
    }


    override func installCmd(_ pkg: GPackage) -> String {
        var command = "\(cmd) install \(pkg.name)"
        let osxVersion = Rudix.clampedOSVersion()
        if G.OSVersion() != osxVersion {
            command = "OSX_VERSION=\(osxVersion) \(command)"
        }
        return "sudo \(command)"
    }

    override func uninstallCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) remove \(pkg.name)"
    }

    override func fetchCmd(_ pkg: GPackage) -> String {
        var command = "cd ~/Downloads ; \(cmd) --download \(pkg.name)"
        let osxVersion = Rudix.clampedOSVersion()
        if G.OSVersion() != osxVersion {
            command = "cd ~/Downloads ; OSX_VERSION=\(osxVersion) \(cmd) --download \(pkg.name)"
        }
        return command
    }

    override var hideCmd: String! {
        get {
            return "sudo mv \(prefix) \(prefix)_off"
        }
    }

    override var unhideCmd: String! {
        get {
            return "sudo mv \(prefix)_off \(prefix)"
        }
    }

    class var setupCmd: String! {
        var command = "curl -s https://raw.githubusercontent.com/rudix-mac/rpm/master/rudix.py | sudo python - install rudix"
        let osxVersion = Rudix.clampedOSVersion()
        if G.OSVersion() != osxVersion {
            command = "curl -s https://raw.githubusercontent.com/rudix-mac/rpm/master/rudix.py | sudo OSX_VERSION=\(osxVersion) python - install rudix"
        }
        return command
    }

    class var removeCmd: String! {
        return "sudo /usr/local/bin/rudix -R" // TODO: prefix
    }

}
