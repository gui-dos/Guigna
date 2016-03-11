import Foundation

final class Homebrew: GSystem {

    override class var prefix: String { return "/usr/local"}

    init(agent: GAgent) {
        super.init(name: "Homebrew", agent: agent)
        homepage = "http://brew.sh/"
        logpage = "http://github.com/Homebrew/homebrew/commits"
        cmd = "\(prefix)/bin/brew"
    }

    override func list() -> [GPackage] {

        index.removeAll(keepCapacity: true)
        items.removeAll(keepCapacity: true)

        // /usr/bin/ruby -C /usr/local/Library/Homebrew -I. -e "require 'global'; require 'formula'; Formula.each {|f| puts \"#{f.name} #{f.pkg_version}\"}" not supported anymore
        // see: https://github.com/Homebrew/homebrew/pull/48261

        let workaround = "ENV['HOMEBREW_BREW_FILE']='\(prefix)/bin/brew';ENV['HOMEBREW_PREFIX']='\(prefix)';ENV['HOMEBREW_REPOSITORY']='\(prefix)';ENV['HOMEBREW_LIBRARY']='\(prefix)/Library';ENV['HOMEBREW_CELLAR']='\(prefix)/Cellar';"

        var outputLines = output("/usr/bin/ruby -C \(prefix)/Library/Homebrew -I. -e " + workaround + "require__'global';require__'formula';__Formula.each__{|f|__puts__\"#{f.full_name}|#{f.pkg_version}|#{f.bottle}|#{f.desc}\"}").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.split("|")
            let fullName = components[0]
            var nameComponents = fullName.split("/")
            let name = nameComponents.last!
            nameComponents.removeLast()
            var repo: String! = nil
            if nameComponents.count > 0 {
                repo = nameComponents.join("/")
            }
            let version = components[1]
            let bottle = components[2]
            var desc = components[3]
            let pkg = GPackage(name: name, version: version, system: self, status: .Available)
            if bottle != "" {
                desc = "🍶\(desc)"
            }
            if desc != "" {
                pkg.description = desc
            }
            if repo != nil {
                pkg.categories = (repo as NSString).lastPathComponent
                pkg.repo = repo
            }
            items.append(pkg)
            self[name] = pkg
        }

        if (defaults("HomebrewMainTaps") as? Bool ?? false) == true {
            let brewCaskCommandAvailable = "\(prefix)/Library/Taps/caskroom/homebrew-cask/cmd/brew-cask.rb".exists
            outputLines = output("\(cmd) search \"\"").componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            for line in outputLines {
                if !line.contains("/") {
                    continue
                }
                let tokens = line.split("/")
                let name = tokens.last!
                if tokens[1] == "cask" && brewCaskCommandAvailable {
                    continue
                }
                if self[name] != nil {
                    continue
                }
                let repo = "\(tokens[0])/\(tokens[1])"
                let pkg = GPackage(name: name, version: "", system: self, status: .Available)
                pkg.categories = tokens[1]
                pkg.repo = repo
                pkg.description = repo
                items.append(pkg)
                self[name] = pkg
            }
        }


        self.installed() // update status
        return items as! [GPackage]
    }


    override func installed() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status != .Available} as! [GPackage]
        }

        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .Online {
            return pkgs
        }

        var outputLines = output("\(cmd) list --versions").split("\n")
        outputLines.removeLast()
        let itemsCount = items.count
        let notInactiveItems = items.filter { $0.status != .Inactive}
        if itemsCount != notInactiveItems.count {
            items = notInactiveItems
            self.agent.appDelegate!.removeItems({ $0.status == .Inactive && $0.system === self}) // TODO: ugly
        }
        var status: GStatus
        for pkg in items as! [GPackage] {
            status = pkg.status
            pkg.installed = nil
            if status != .Updated && status != .New {
                pkg.status = .Available
            }
        }
        self.outdated() // update status
        for line in outputLines {
            var components = line.split()
            let name = components[0]
            if name == "Error:" {
                return pkgs
            }
            components.removeAtIndex(0)
            let versionCount = components.count
            let version = components.last!
            var pkg: GPackage! = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if versionCount > 1 {
                for i in 0..<versionCount - 1 {
                    let inactivePkg = GPackage(name: name, version: latestVersion, system: self, status: .Inactive)
                    inactivePkg.installed = components[i]
                    items.append(inactivePkg)
                    self.agent.appDelegate!.addItem(inactivePkg) // TODO: ugly
                    pkgs.append(inactivePkg)
                }
            }
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .UpToDate)
                self[name] = pkg
            } else {
                if pkg.status == .Available {
                    pkg.status = .UpToDate
                }
            }
            pkg.installed = version
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

        var outputLines = output("\(cmd) outdated").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.split()
            var name = components[0]
            if name == "Error:" {
                return pkgs
            }
            if name.contains("/") {
                name = (name as NSString).lastPathComponent
            }
            var pkg = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            // let version = components[1] // TODO: strangely, output contains only name
            let version = (pkg == nil) ? "..." : pkg.installed
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .Outdated)
                self[name] = pkg
            } else {
                pkg.status = .Outdated
            }
            pkg.installed = version
            pkgs.append(pkg)
        }
        return pkgs
    }


    override func inactive() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status == .Inactive} as! [GPackage]
        }
        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .Online {
            return pkgs
        }

        for pkg in installed() {
            if pkg.status == .Inactive {
                pkgs.append(pkg)
            }
        }
        return pkgs
    }

    override func info(item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) info \(item.name)")
        } else {
            return super.info(item)
        }
    }

    override func home(item: GItem) -> String {
        var page = ""
        if self.isHidden {
            for line in cat(item).split("\n") {
                let idx = line.index("homepage")
                if idx != NSNotFound {
                    page = line.substringFromIndex(idx + 8).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                    if page.contains("http") {
                        return page.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "'\""))
                    }
                }
            }
        } else {
            let outputLines = output("\(cmd) info \(item.name)").split("\n")
            page = outputLines[2]
            if !page.hasPrefix("http") { // desc line is missign
                page = outputLines[1]
            }
            return page
        }
        return log(item)
    }

    override func log(item: GItem) -> String {
        var path: String
        if (item as! GPackage).repo == nil {
            path = "Homebrew/homebrew/commits/master/Library/Formula"
        } else {
            let tokens = (item as! GPackage).repo!.split("/")
            let user = tokens[0]
            path = "\(user)/homebrew-\(tokens[1])/commits/master"
            if "\(prefix)/Library/Taps/\(user)/homebrew-\(tokens[1])/Formula".exists {
                path += "/Formula"
            }
        }
        return "http://github.com/\(path)/\(item.name).rb"
    }

    override func contents(item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) list -v \(item.name)")
        } else {
            return ""
        }
    }

    override func cat(item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) cat \(item.name)")
        } else {
            return (try? String(contentsOfFile: "\(prefix)_off/Library/Formula/\(item.name).rb", encoding: NSUTF8StringEncoding)) ?? ""
        }
    }

    override func deps(item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) deps -n \(item.name)")
        } else {
            return "[Cannot compute the dependencies now]"
        }
    }

    override func dependents(item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) uses --installed \(item.name)")
        } else {
            return ""
        }
    }

    override func options(pkg: GPackage) -> String! {
        var options: String! = nil
        let outputLines = output("\(cmd) options \(pkg.name)").split("\n")
        if outputLines.count > 1 {
            let optionLines = outputLines.filter { $0.hasPrefix("--") }
            options = optionLines.join().replace("--", "")
        }
        return options
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
        if pkg.status == .Inactive {
            return self.cleanCmd(pkg)
        } else { // TODO: manage --force flag
            return "\(cmd) remove --force \(pkg.name)"
        }
    }

    override func upgradeCmd(pkg: GPackage) -> String {
        return "\(cmd) upgrade \(pkg.name)"
    }


    override func cleanCmd(pkg: GPackage) -> String {
        return "\(cmd) cleanup --force \(pkg.name) &>/dev/null"
    }


    override var updateCmd: String! {
        get {
            return "\(cmd) update"
        }
    }

    override var hideCmd: String! {
        get {
            return "for dir in bin etc include lib opt share ; do sudo mv \(prefix)/\"$dir\"{,_off} ; done"
        }
    }

    override var unhideCmd: String! {
        get {
            return "for dir in bin etc include lib opt share ; do sudo mv \(prefix)/\"$dir\"{_off,} ; done"
        }
    }

    class var setupCmd: String! {
        return "ruby -e \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)\" ; /usr/local/bin/brew update"
    }

    class var removeCmd: String! {
        return "cd /usr/local ; curl -L https://raw.github.com/gist/1173223 -o uninstall_homebrew.sh; sudo sh uninstall_homebrew.sh ; rm uninstall_homebrew.sh ; sudo rm -rf /Library/Caches/Homebrew; rm -rf /usr/local/.git"
    }
    
    override func verbosifiedCmd(command: String) -> String {
        var tokens = command.split()
        tokens.insert("-v", atIndex: 2)
        return tokens.join()
    }
    
}
