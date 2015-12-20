import Foundation

final class HomebrewCasks: GSystem {

    override class var prefix: String { return "/usr/local" }

    init(agent: GAgent) {
        super.init(name: "Homebrew Casks", agent: agent)
        homepage = "http://caskroom.io"
        logpage = "http://github.com/caskroom/homebrew-cask/commits"
        cmd = "\(prefix)/bin/brew cask"
    }

    override func list() -> [GPackage] {

        index.removeAll(keepCapacity: true)
        items.removeAll(keepCapacity: true)

        var outputLines = output("/bin/sh -c /usr/bin/grep__\"version__\"__-r__/\(prefix)/Library/Taps/caskroom/homebrew-cask/Casks").split("\n")
        outputLines.removeLast()
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        for line in outputLines {
            let components = line.stringByTrimmingCharactersInSet(whitespaceCharacterSet).split()
            var name = (components[0] as NSString).lastPathComponent
            name = name.substringToIndex(name.length - 4)
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
            var pkg = GPackage(name: name, version: version, system: self, status: .Available)
            // avoid duplicate entries (i.e. aquamacs, opensesame)
            if self[pkg.name] != nil {
                let prevPackage = self[pkg.name]
                var found: Int?
                for (i, pkg) in items.enumerate() {
                    if pkg.name == name {
                        found = i
                        break
                    }
                }
                if let idx = found {
                    items.removeAtIndex(idx)
                }
                if prevPackage!.version > version {
                    pkg = prevPackage!
                }
            }
            items.append(pkg)
            self[name] = pkg
        }
        outputLines = output("/bin/sh -c /usr/bin/grep__\"license__\"__-r__/\(prefix)/Library/Taps/caskroom/homebrew-cask/Casks").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.stringByTrimmingCharactersInSet(whitespaceCharacterSet).split()
            var name = (components[0] as NSString).lastPathComponent
            name = name.substringToIndex(name.length - 4)
            if let pkg = self[name] {
                var license = components.last!
                if license.hasPrefix(":") {
                    license = license.substring(1, license.length - 1)
                    pkg.license = license
                }
            }
        }
        outputLines = output("/bin/sh -c /usr/bin/grep__\"name__'\"__-r__/\(prefix)/Library/Taps/caskroom/homebrew-cask/Casks").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.stringByTrimmingCharactersInSet(whitespaceCharacterSet).split(".rb:  name '")
            let name = (components[0] as NSString).lastPathComponent
            if let pkg = self[name] {
                pkg.description = String((components.last!).characters.dropLast())
            }
        }
        self.installed() // update status
        return items as! [GPackage]
    }

    // TODO: port from Homebrew

    override func installed() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status != .Available} as! [GPackage]
        }

        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .Online {
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
            if status != .Updated && status != .New {
                pkg.status = .Available
            }
        }
        // self.outdated() // update status
        for line in outputLines {
            let name = line
            if name == "Error:" {
                return pkgs
            }
            var version = output("/bin/ls /opt/homebrew-cask/Caskroom/\(name)").stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            // TODO: manage multiple versions
            version = version.replace("\n", ", ")
            var pkg: GPackage! = self[name]
            let latestVersion: String! = (pkg == nil) ? "" : pkg.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .UpToDate)
                self[name] = pkg
            } else {
                if pkg.status == .Available {
                    pkg.status = .UpToDate
                }
            }
            pkg.installed = version // TODO
            if latestVersion != nil {
                if !version.hasSuffix(latestVersion) {
                    pkg.status = .Outdated
                }
            }
            pkgs.append(pkg)
        }
        return pkgs
    }


    override func outdated() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status == .Outdated} as! [GPackage]
        }

        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .Online {
            return pkgs
        }

        for pkg in installed() {
            if pkg.status == .Outdated {
                pkgs.append(pkg)
            }
        }
        return pkgs

    }


    override func info(item: GItem) -> String {
        let escapedCmd = cmd.replace(" ", "__")
        if !self.isHidden {
            return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__info__\(item.name)")
        } else {
            return super.info(item)
        }
    }

    override func home(item: GItem) -> String {
        let escapedCmd = cmd.replace(" ", "__")
        if self.isHidden {
            var homepage = ""
            for line in cat(item).split("\n") {
                let idx = line.index("homepage")
                if idx != NSNotFound {
                    homepage = line.substringFromIndex(idx + 8).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    if homepage.contains("http") {
                        return homepage.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "'\""))
                    }
                }
            }
        } else {
            if !self.isHidden && (item as! GPackage).repo == nil {
                return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__info__\(item.name)").split("\n")[2]
            }
        }
        return log(item)
    }

    override func log(item: GItem) -> String {
        var path = ""
        if (item as! GPackage).repo == nil {
            path = "caskroom/homebrew-cask/commits/master/Casks"
            //            } else {
            //                let tokens = (item as! GPackage).repo!.split("/")
            //                let user = tokens[0]
            //                path = "\(user)/homebrew-\(tokens[1])/commits/master"
        }
        return "http://github.com/\(path)/\(item.name).rb"
    }

    override func contents(item: GItem) -> String {
        let escapedCmd = cmd.replace(" ", "__")
        if !self.isHidden {
            return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__list__\(item.name)")
        } else {
            return ""
        }
    }

    override func cat(item: GItem) -> String {
        let escapedCmd = cmd.replace(" ", "__")
        if !self.isHidden {
            return output("/bin/sh -c export__PATH=\(prefix)/bin:$PATH__;__\(escapedCmd)__cat__\(item.name)")
        } else {
            return (try? String(contentsOfFile: "\(prefix)_off/Library/Taps/caskroom/homebrew-cask/Casks/\(item.name).rb", encoding: NSUTF8StringEncoding)) ?? ""
        }
    }

    override func deps(item: GItem) -> String {
        return ""
    }

    override func dependents(item: GItem) -> String {
        return ""
    }


    override func installCmd(pkg: GPackage) -> String {
        var options: String! = pkg.markedOptions
        if options == nil {
            options = ""
        } else {
            options = "--" + options.replace(" ", " --")
        }
        return "\(cmd) install \(options) \(pkg.name)"
    }


    override func uninstallCmd(pkg: GPackage) -> String {
        return "\(cmd) zap \(pkg.name)"
    }

    // TODO: uninstall only, don't zap settings
    override func upgradeCmd(pkg: GPackage) -> String {
        return "\(cmd) zap \(pkg.name) ; \(cmd) install \(pkg.name)"
    }

    override func cleanCmd(pkg: GPackage) -> String {
        return "\(cmd) cleanup --force \(pkg.name) &>/dev/null"
    }

    //    override var updateCmd: String! {
    //    get {
    //        return "\(cmd) update"
    //    }
    //    }

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
        return "\(prefix)/bin/brew tap caskroom/cask"
    }

    class var removeCmd: String! {
        return "\(prefix)/bin/brew untap caskroom/cask"
    }

    override func verbosifiedCmd(command: String) -> String {
        var tokens = command.split()
        tokens.insert("-v", atIndex: 2)
        return tokens.join()
    }

}
