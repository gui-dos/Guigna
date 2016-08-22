import Foundation

final class HomebrewCasks: GSystem {

    override class var prefix: String { return "/usr/local" }

    init(agent: GAgent) {
        super.init(name: "Homebrew Casks", agent: agent)
        homepage = "http://caskroom.io"
        logpage = "http://github.com/caskroom/homebrew-cask/commits"
        cmd = "\(prefix)/bin/brew cask"
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        var outputLines = output("/bin/sh -c /usr/bin/grep__\"__version__\"__-r__/\(prefix)/Library/Taps/caskroom/homebrew-*/Casks").split("\n")
        outputLines.removeLast()
        let whitespaceCharacterSet = CharacterSet.whitespaces
        for line in outputLines {
            let components = line.trim(whitespaceCharacterSet).split()
            var name = (components[0] as NSString).lastPathComponent
            name = name.substring(to: name.length - 4)
            var version = components.last!
            if !(version.hasPrefix("'") || version.hasPrefix(":")) {
                let prev = components[components.count - 2]
                if prev.hasPrefix("'") {
                    version = "\(prev) \(version)"
                } else {
                    continue
                }
            }
            let offset = version.hasPrefix(":") ? 1 : 2
            version = version.substring(1, version.length - offset)
            let repo = line.split("/Taps/")[1].split("/Casks/")[0].replace("homebrew-", "")
            var pkg = GPackage(name: name, version: version, system: self, status: .available)
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
        outputLines = output("/bin/sh -c /usr/bin/grep__\"license__\"__-r__/\(prefix)/Library/Taps/caskroom/homebrew-*/Casks").split("\n")
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
        outputLines = output("/bin/sh -c /usr/bin/grep__\"name__'\"__-r__/\(prefix)/Library/Taps/caskroom/homebrew-*/Casks").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.trim(whitespaceCharacterSet).split(".rb:  name '")
            let name = (components[0] as NSString).lastPathComponent
            if let pkg = self[name] {
                pkg.description = String((components.last!).characters.dropLast())
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

        let escapedCmd = cmd.replace(" ", "__")
        var outputLines = output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__list__2>/dev/null").split("\n")
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
        let escapedCmd = cmd.replace(" ", "__")
        if !self.isHidden {
            return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__info__\(item.name)")
        } else {
            return super.info(item)
        }
    }

    override func home(_ item: GItem) -> String {
        let escapedCmd = cmd.replace(" ", "__")
        if self.isHidden {
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
        } else {
            if !self.isHidden && (item as! GPackage).repo == nil {
                return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__info__\(item.name)").split("\n")[1]
            }
        }
        return log(item)
    }

    override func log(_ item: GItem) -> String {
        var path = ""
        if (item as! GPackage).repo == nil {
            path = "caskroom/homebrew-cask/commits/master/Casks"
        } else {
            let tokens = (item as! GPackage).repo!.split("/")
            let user = tokens[0]
            path = "\(user)/homebrew-\(tokens[1])/commits/master/Casks"
        }
        return "http://github.com/\(path)/\(item.name).rb"
    }

    override func contents(_ item: GItem) -> String {
        let escapedCmd = cmd.replace(" ", "__")
        if !self.isHidden {
            return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__list__\(item.name)")
        } else {
            return ""
        }
    }

    override func cat(_ item: GItem) -> String {
        let escapedCmd = cmd.replace(" ", "__")
        if !self.isHidden {
            return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__cat__\(item.name)")
        } else {
            // TODO: repo
            return (try? String(contentsOfFile: "\(prefix)_off/Library/Taps/caskroom/homebrew-cask/Casks/\(item.name).rb", encoding: .utf8)) ?? ""
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

    // TODO: uninstall only, don't zap settings
    override func upgradeCmd(_ pkg: GPackage) -> String {
        return "\(cmd) zap \(pkg.name); \(cmd) install \(pkg.name)"
    }

    override func cleanCmd(_ pkg: GPackage) -> String {
        return "\(cmd) cleanup --force \(pkg.name) &>/dev/null"
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
        return "\(prefix)/bin/brew tap caskroom/cask"
    }

    class var removeCmd: String! {
        return "\(prefix)/bin/brew untap caskroom/cask"
    }
    
    override func verbosifiedCmd(_ command: String) -> String {
        var tokens = command.split()
        tokens.insert("-v", at: 2)
        return tokens.join()
    }
    
}
