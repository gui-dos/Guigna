import Foundation

final class HomebrewCasks: GSystem {
    
    override class var name: String { return "Homebrew Casks"}
    override class var prefix: String { return "/usr/local" }

    required init(agent: GAgent) {
        super.init(agent: agent)
        homepage = "http://brew.sh/"
        logpage = "http://github.com/homebrew/homebrew-cask/commits"
        cmd = "\(prefix)/bin/brew"
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        var outputLines = output("/bin/sh -c /usr/bin/grep__\"__version__[\\\":]\"__-r__/\(prefix)/Homebrew/Library/Taps/homebrew/homebrew-*/Casks").split("\n")
        outputLines.removeLast()
        let whitespaceCharacterSet = CharacterSet.whitespaces
        for line in outputLines {
            let components = line.trim(whitespaceCharacterSet).split()
            var name = (components[0] as NSString).lastPathComponent
            name = name.substring(to: name.length - 4)
            var version = components.last!
            let offset = version.hasPrefix(":") ? 1 : 2
            version = version.substring(1, version.length - offset)
            let repo = line.split("/Taps/")[1].split("/Casks/")[0].replace("homebrew-", "")
            var pkg = GPackage(name: name, version: version, system: self)
            // avoid duplicate entries (i.e. aquamacs, opensesame)
            if self[pkg.name] != nil {
                let prevPackage = self[pkg.name]
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
                if prevPackage!.version > version {
                    pkg = prevPackage!
                }
            }
            pkg.repo = repo
            items.append(pkg)
            self[name] = pkg
        }
        outputLines = output("/bin/sh -c /usr/bin/grep__\"license__\"__-r__/\(prefix)/Homebrew/Library/Taps/homebrew/homebrew-*/Casks").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.trim(whitespaceCharacterSet).split()
            var name = (components[0] as NSString).lastPathComponent
            name = name.substring(to: name.length - 4)
            if let pkg = self[name] {
                var license = components.last!
                if license.hasPrefix(":") {
                    license = license.substring(1, license.length - 1)
                    pkg.license = license
                }
            }
        }
        outputLines = output("/bin/sh -c /usr/bin/grep__\"name__'\"__-r__/\(prefix)/Homebrew/Library/Taps/homebrew/homebrew-*/Casks").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.trim(whitespaceCharacterSet).split(".rb:  name '")
            let name = (components[0] as NSString).lastPathComponent
            if let pkg = self[name] {
                pkg.description = String((components.last!).dropLast())
            }
        }
        self.installed() // update status
        return items as! [GPackage]
    }

    // TODO: port from Homebrew

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

        var outputLines = output("\(cmd) list").split("\n")
        outputLines.removeLast()
        var status: GStatus

        // TODO: remove inactive packages from items and allPackages

        for pkg in items as! [GPackage] {
            status = pkg.status
            pkg.installed = nil
            if status != .updated && status != .new {
                pkg.status = .available
            }
        }
        // self.outdated() // update status
        for line in outputLines {
            let name = line
            if name == "Error:" {
                return pkgs
            }
            var version = output("/bin/ls \(prefix)/Caskroom/\(name)").trim()
            // TODO: manage multiple versions
            version = version.replace("\n", ", ")
            var pkg: GPackage! = self[name]
            let latestVersion: String! = (pkg == nil) ? "" : pkg.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .upToDate)
                self[name] = pkg
            } else {
                if pkg.status == .available {
                    pkg.status = .upToDate
                }
            }
            pkg.installed = version // TODO
            if latestVersion != nil {
                if !version.hasSuffix(latestVersion) {
                    pkg.status = .outdated
                }
            }
            pkgs.append(pkg)
        }
        return pkgs
    }

    // TODO: use `brew cask outdated`
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

        for pkg in installed() {
            if pkg.status == .outdated {
                pkgs.append(pkg)
            }
        }
        return pkgs

    }


    override func info(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) info \(item.name)")
        } else {
            return super.info(item)
        }
    }

    override func home(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) info \(item.name)").split("\n")[1]
        } else {
            var homepage = ""
            for line in cat(item).split("\n") {
                let idx = line.index("homepage")
                if idx != NSNotFound {
                    homepage = line.substring(from: idx + 8).trim()
                    if homepage.contains("http") {
                        return homepage.trim("'\"")
                    }
                }
            }
        }
        return log(item)
    }

    override func log(_ item: GItem) -> String {
        var path = ""
        if (item as! GPackage).repo == nil {
            path = "homebrew/homebrew-cask/commits/master/Casks"
        } else {
            let tokens = (item as! GPackage).repo!.split("/")
            let user = tokens[0]
            path = "\(user)/homebrew-\(tokens[1])/commits/master/Casks"
        }
        return "http://github.com/\(path)/\(item.name).rb"
    }

    override func contents(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) list \(item.name)")
        } else {
            return ""
        }
    }

    override func cat(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) cat \(item.name)")
        } else {
            // TODO: repo
            return (try? String(contentsOfFile: "\(prefix)_off/Homebrew/Library/Taps/homebrew/homebrew-cask/Casks/\(item.name).rb", encoding: .utf8)) ?? ""
        }
    }

    override func deps(_ item: GItem) -> String {
        return ""
    }

    override func dependents(_ item: GItem) -> String {
        return ""
    }


    override func installCmd(_ pkg: GPackage) -> String {
        var options: String! = pkg.markedOptions
        if options == nil {
            options = ""
        } else {
            options = "--" + options!.replace(" ", " --")
        }
        return "\(cmd) install \(options!) \(pkg.name)".replace("  ", " ")
    }


    override func uninstallCmd(_ pkg: GPackage) -> String {
        return "\(cmd) zap \(pkg.name)"
    }


    override func upgradeCmd(_ pkg: GPackage) -> String {
        return "\(cmd) upgrade \(pkg.name)"
    }

    override func cleanCmd(_ pkg: GPackage) -> String {
        return "\(cmd) zap \(pkg.name) ; \(cmd) cleanup \(pkg.name)"
    }

    //    override var updateCmd: String! {
    //    get {
    //        return "\(cmd) update"
    //    }
    //    }

    override var hideCmd: String! {
        get {
            return "for dir in bin etc include lib opt share; do sudo mv \(prefix)/\"$dir\"{,_off}; done"
        }
    }

    override var unhideCmd: String! {
        get {
            return "for dir in bin etc include lib opt share; do sudo mv \(prefix)/\"$dir\"{_off,}; done"
        }
    }

    class var setupCmd: String! {
        return "\(prefix)/bin/brew tap homebrew/cask"
    }

    class var removeCmd: String! {
        return "\(prefix)/bin/brew untap homebrew/cask"
    }
    
    override func verbosifiedCmd(_ command: String) -> String {
        var tokens = command.split()
        tokens.insert("-v", at: 2)
        return tokens.join()
    }
    
}
